source("analysis/sim/utils_sim.R")
source("analysis/sim/config.R")

run_calibration_study <- function(
  n_grid = c(200, 500, 1000),
  beta_grid = c(0.0, 0.25, 0.5, 0.75),
  reps = 200,
  seed_root = 321
) {
  grid <- make_grid(n = n_grid, beta = beta_grid, rep = seq_len(reps))
  results <- vector("list", nrow(grid))

  for (i in seq_len(nrow(grid))) {
    row <- grid[i, ]
    seed <- seed_from_root(seed_root, paste("calibration", row$n, row$beta, row$rep, sep = "_"))
    sim <- simulate_plr(n = row$n, beta = row$beta, seed = seed)
    dat <- sim$data

    lm_learner <- linear_learner()

    dat_lin <- transform(dat, Z1 = dat$Z1, Z2 = dat$Z2)
    x_lin <- make_linear_basis(dat_lin)
    dat_cf <- data.frame(Y = dat$Y, D = dat$D, x_lin)
    spec <- aegis::aegis_spec(
      target = aegis::target_lm("Y", "D", colnames(x_lin)),
      strategy = aegis::strategy_crossfit(v = 5, repeats = 2, shuffle = TRUE),
      nuisance = aegis::nuis_spec(lm_learner, lm_learner),
      seed = seed
    )
    fit <- aegis::aegis_fit(spec, dat_cf)

    theta_hat <- fit$theta
    se <- fit$se
    ci <- c(theta_hat - 1.96 * se, theta_hat + 1.96 * se)
    weak_ratios <- vapply(
      fit$diagnostics$weak_signal$per_repeat,
      function(x) x$ratio,
      numeric(1)
    )
    weak_ratio <- mean(weak_ratios, na.rm = TRUE)
    instab <- stats::sd(weak_ratios, na.rm = TRUE)
    infl <- fit$diagnostics$influence$p95_abs_std
    comp_score <- composite_score(weak_ratio, instab, infl)

    results[[i]] <- data.frame(
      n = row$n,
      beta = row$beta,
      rep = row$rep,
      estimator = "AEGIS",
      theta0 = 1,
      theta_hat = theta_hat,
      se = se,
      ci_lower = ci[1],
      ci_upper = ci[2],
      cover = ci[1] <= 1 && ci[2] >= 1,
      weak_signal = fit$diagnostics$weak_signal$status,
      weak_ratio = weak_ratio,
      instab = instab,
      infl = infl,
      comp_score = comp_score
    )
  }

  do.call(rbind, results)
}

auc_mann_whitney <- function(score, label) {
  keep <- is.finite(score) & !is.na(label)
  score <- score[keep]
  label <- label[keep]
  if (length(score) == 0 || length(unique(label)) < 2) {
    return(NA_real_)
  }
  label <- as.logical(label)
  n_pos <- sum(label)
  n_neg <- sum(!label)
  if (n_pos == 0 || n_neg == 0) {
    return(NA_real_)
  }
  ranks <- rank(score, ties.method = "average")
  sum_ranks_pos <- sum(ranks[label])
  (sum_ranks_pos - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

if (sys.nframe() == 0) {
  profile <- get_profile()
  args <- profile$calibration
  out <- do.call(run_calibration_study, args)
  dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, "artifacts/sim/calibration_results.rds")
  out$miss <- !out$cover
  out$calib_split <- out$rep %% 2 == 0
  pi_min <- 0.3
  calib_mask <- out$calib_split
  predictors <- data.frame(
    weak_ratio = out$weak_ratio,
    instab = out$instab,
    infl = out$infl,
    comp_score = out$comp_score,
    se = out$se,
    n = out$n,
    beta = out$beta
  )
  calib_dat <- predictors[calib_mask, , drop = FALSE]
  calib_dat$miss <- out$miss[calib_mask]
  glm_fit <- stats::glm(miss ~ ., data = calib_dat, family = stats::binomial())
  score <- stats::predict(glm_fit, newdata = predictors, type = "response")
  score_calib <- score[calib_mask]
  score_eval <- score[!calib_mask]
  min_fail <- stats::quantile(score_calib, probs = 1 - pi_min, na.rm = TRUE)
  thresholds <- sort(unique(score_calib))
  thresholds <- thresholds[thresholds >= min_fail]
  if (length(thresholds) == 0) {
    thresh <- min_fail
  } else {
    youdens <- vapply(thresholds, function(t) {
      preds <- score_calib >= t
      tp <- sum(preds & out$miss[calib_mask], na.rm = TRUE)
      fp <- sum(preds & !out$miss[calib_mask], na.rm = TRUE)
      fn <- sum(!preds & out$miss[calib_mask], na.rm = TRUE)
      tn <- sum(!preds & !out$miss[calib_mask], na.rm = TRUE)
      tpr <- if ((tp + fn) > 0) tp / (tp + fn) else 0
      fpr <- if ((fp + tn) > 0) fp / (fp + tn) else 0
      tpr - fpr
    }, numeric(1))
    thresh <- thresholds[which.max(youdens)][1]
  }

  weak_cutoff <- stats::quantile(out$weak_ratio[calib_mask], probs = pi_min, na.rm = TRUE)
  out$fail_flag <- score >= thresh & out$weak_ratio <= weak_cutoff
  eval_mask <- !out$calib_split
  p_miss_fail <- mean(out$miss[eval_mask & out$fail_flag], na.rm = TRUE)
  p_miss_pass <- mean(out$miss[eval_mask & !out$fail_flag], na.rm = TRUE)
  fpr <- mean(out$fail_flag[eval_mask] & !out$miss[eval_mask], na.rm = TRUE)
  fnr <- mean(!out$fail_flag[eval_mask] & out$miss[eval_mask], na.rm = TRUE)
  auc <- auc_mann_whitney(score_eval, out$miss[eval_mask])
  fail_prevalence <- mean(out$fail_flag[eval_mask], na.rm = TRUE)
  diag_table <- data.frame(
    p_miss_fail = p_miss_fail,
    p_miss_pass = p_miss_pass,
    fpr = fpr,
    fnr = fnr,
    auc = auc,
    fail_threshold = thresh,
    pi_min = pi_min,
    weak_cutoff = weak_cutoff,
    fail_prevalence = fail_prevalence
  )
  write.csv(diag_table, "artifacts/sim/diagnostics_operating_chars.csv", row.names = FALSE)
  write_manifest(
    "artifacts/sim/calibration_manifest.json",
    grid = args,
    seed_root = args$seed_root
  )
}
