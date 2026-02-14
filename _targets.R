library(targets)

source("analysis/sim/boundary_experiment.R")
source("analysis/sim/calibration_study.R")
source("analysis/sim/adversarial_benchmark.R")
source("analysis/sim/config.R")

tar_option_set(packages = c("aegis"))

profile <- get_profile()
boundary_args <- profile$boundary
calibration_args <- profile$calibration
adversarial_args <- profile$adversarial

list(
  tar_target(boundary_results, do.call(run_boundary_experiment, boundary_args)),
  tar_target(calibration_results, do.call(run_calibration_study, calibration_args)),
  tar_target(adversarial_results, do.call(run_adversarial_benchmark, adversarial_args)),
  tar_target(boundary_artifacts, {
    dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
    saveRDS(boundary_results, "artifacts/sim/boundary_results.rds")
    write.csv(boundary_results, "artifacts/sim/boundary_summary.csv", row.names = FALSE)
    write.csv(summary_metrics(boundary_results), "artifacts/sim/summary_metrics.csv", row.names = FALSE)
    write_manifest(
      "artifacts/sim/boundary_manifest.json",
      grid = boundary_args,
      seed_root = boundary_args$seed_root
    )
    boundary_results
  }),
  tar_target(calibration_artifacts, {
    dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
    res <- calibration_results
    saveRDS(res, "artifacts/sim/calibration_results.rds")
    res$miss <- !res$cover
    res$calib_split <- res$rep %% 2 == 0
    pi_min <- 0.3
    calib_mask <- res$calib_split
    predictors <- data.frame(
      weak_ratio = res$weak_ratio,
      instab = res$instab,
      infl = res$infl,
      comp_score = res$comp_score,
      se = res$se,
      n = res$n,
      beta = res$beta
    )
    calib_dat <- predictors[calib_mask, , drop = FALSE]
    calib_dat$miss <- res$miss[calib_mask]
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
        tp <- sum(preds & res$miss[calib_mask], na.rm = TRUE)
        fp <- sum(preds & !res$miss[calib_mask], na.rm = TRUE)
        fn <- sum(!preds & res$miss[calib_mask], na.rm = TRUE)
        tn <- sum(!preds & !res$miss[calib_mask], na.rm = TRUE)
        tpr <- if ((tp + fn) > 0) tp / (tp + fn) else 0
        fpr <- if ((fp + tn) > 0) fp / (fp + tn) else 0
        tpr - fpr
      }, numeric(1))
      thresh <- thresholds[which.max(youdens)][1]
    }

    weak_cutoff <- stats::quantile(res$weak_ratio[calib_mask], probs = pi_min, na.rm = TRUE)
    res$fail_flag <- score >= thresh & res$weak_ratio <= weak_cutoff
    p_miss_fail <- mean(res$miss[res$fail_flag], na.rm = TRUE)
    p_miss_pass <- mean(res$miss[!res$fail_flag], na.rm = TRUE)
    fpr <- mean(res$fail_flag & !res$miss, na.rm = TRUE)
    fnr <- mean(!res$fail_flag & res$miss, na.rm = TRUE)
    auc <- auc_mann_whitney(score_eval, res$miss[!calib_mask])
    fail_prevalence <- mean(res$fail_flag[!calib_mask], na.rm = TRUE)
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
      grid = calibration_args,
      seed_root = calibration_args$seed_root
    )
    res
  }),
  tar_target(adversarial_artifacts, {
    dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
    saveRDS(adversarial_results, "artifacts/sim/adversarial_results.rds")
    write.csv(adversarial_results, "artifacts/sim/adversarial_audit_summary.csv", row.names = FALSE)
    write_manifest(
      "artifacts/sim/adversarial_manifest.json",
      grid = adversarial_args,
      seed_root = adversarial_args$seed_root
    )
    adversarial_results
  }),
  tar_target(boundary_summary, {
    write.csv(boundary_results, "artifacts/sim/boundary_summary.csv", row.names = FALSE)
    boundary_results
  }),
  tar_target(calibration_summary, {
    write.csv(calibration_results, "artifacts/sim/calibration_summary.csv", row.names = FALSE)
    calibration_results
  }),
  tar_target(adversarial_summary, {
    write.csv(adversarial_results, "artifacts/sim/adversarial_audit_summary.csv", row.names = FALSE)
    adversarial_results
  })
)
