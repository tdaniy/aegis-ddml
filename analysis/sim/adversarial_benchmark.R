source("analysis/sim/utils_sim.R")
source("analysis/sim/config.R")

run_adversarial_benchmark <- function(
  n_grid = c(200, 500),
  beta_grid = c(0.0, 0.5),
  model_grid = c("lm", "glm"),
  reps = 50,
  seed_root = 456
) {
  grid <- make_grid(n = n_grid, beta = beta_grid, model = model_grid, rep = seq_len(reps))
  results <- list()

  lm_learner <- linear_learner()

  glm_learner <- aegis::learner_base(
    name = "glm-binomial",
    fit_fun = function(x, y) {
      stats::glm(y ~ ., data = data.frame(y = y, x), family = stats::binomial())
    },
    predict_fun = function(fit, newdata) {
      stats::predict(fit, newdata = data.frame(newdata), type = "response")
    }
  )

  for (i in seq_len(nrow(grid))) {
    row <- grid[i, ]
    seed <- seed_from_root(seed_root, paste("adv", row$n, row$beta, row$model, row$rep, sep = "_"))

    if (row$model == "lm") {
      sim <- simulate_plr(n = row$n, beta = row$beta, seed = seed)
    } else {
      sim <- simulate_plr_logistic(n = row$n, beta = row$beta, seed = seed)
    }
    dat <- sim$data
    m0 <- sim$m0
    g0 <- sim$g0

    if (row$model == "lm") {
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
      spec_dml <- aegis::aegis_spec(
        target = aegis::target_lm("Y", "D", colnames(x_lin)),
        strategy = aegis::strategy_crossfit(v = 5, repeats = 1, shuffle = TRUE),
        nuisance = aegis::nuis_spec(lm_learner, lm_learner),
        seed = seed
      )
      fit_dml <- aegis::aegis_fit(spec_dml, dat_cf)
      theta_dml <- fit_dml$theta
      se_dml <- fit_dml$se
    } else {
      spec <- aegis::aegis_spec(
        target = aegis::target_glm("Y", "D", c("Z1", "Z2")),
        strategy = aegis::strategy_crossfit(v = 5, repeats = 2, shuffle = TRUE),
        nuisance = aegis::nuis_spec(glm_learner, lm_learner),
        seed = seed
      )
      fit <- aegis::aegis_fit(spec, dat)
      theta_hat <- fit$theta
      se <- fit$se
      spec_dml <- aegis::aegis_spec(
        target = aegis::target_glm("Y", "D", c("Z1", "Z2")),
        strategy = aegis::strategy_crossfit(v = 5, repeats = 1, shuffle = TRUE),
        nuisance = aegis::nuis_spec(glm_learner, lm_learner),
        seed = seed
      )
      fit_dml <- aegis::aegis_fit(spec_dml, dat)
      theta_dml <- fit_dml$theta
      se_dml <- fit_dml$se
    }

    ci <- c(theta_hat - 1.96 * se, theta_hat + 1.96 * se)
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      model = row$model,
      estimator = "AEGIS",
      theta0 = 1,
      theta_hat = theta_hat,
      se = se,
      ci_lower = ci[1],
      ci_upper = ci[2],
      cover = ci[1] <= 1 && ci[2] >= 1
    )
    ci_dml <- c(theta_dml - 1.96 * se_dml, theta_dml + 1.96 * se_dml)
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      model = row$model,
      estimator = "doubleml",
      theta0 = 1,
      theta_hat = theta_dml,
      se = se_dml,
      ci_lower = ci_dml[1],
      ci_upper = ci_dml[2],
      cover = ci_dml[1] <= 1 && ci_dml[2] >= 1
    )

    if (row$model == "lm") {
      naive <- fit_naive_ols(dat)
      ci_naive <- c(naive$theta - 1.96 * naive$se, naive$theta + 1.96 * naive$se)
      results[[length(results) + 1]] <- data.frame(
        n = row$n,
        beta = row$beta,
        model = row$model,
        estimator = "naive",
        theta0 = 1,
        theta_hat = naive$theta,
        se = naive$se,
        ci_lower = ci_naive[1],
        ci_upper = ci_naive[2],
        cover = ci_naive[1] <= 1 && ci_naive[2] >= 1
      )

      split <- fit_sample_split(dat, seed = seed)
      ci_split <- c(split$theta - 1.96 * split$se, split$theta + 1.96 * split$se)
      results[[length(results) + 1]] <- data.frame(
        n = row$n,
        beta = row$beta,
        model = row$model,
        estimator = "sample_split",
        theta0 = 1,
        theta_hat = split$theta,
        se = split$se,
        ci_lower = ci_split[1],
        ci_upper = ci_split[2],
        cover = ci_split[1] <= 1 && ci_split[2] >= 1
      )

      oracle <- fit_oracle(dat, m0, g0)
      ci_oracle <- c(oracle$theta - 1.96 * oracle$se, oracle$theta + 1.96 * oracle$se)
      results[[length(results) + 1]] <- data.frame(
        n = row$n,
        beta = row$beta,
        model = row$model,
        estimator = "oracle",
        theta0 = 1,
        theta_hat = oracle$theta,
        se = oracle$se,
        ci_lower = ci_oracle[1],
        ci_upper = ci_oracle[2],
        cover = ci_oracle[1] <= 1 && ci_oracle[2] >= 1
      )
    }
  }

  do.call(rbind, results)
}

if (sys.nframe() == 0) {
  profile <- get_profile()
  args <- profile$adversarial
  out <- do.call(run_adversarial_benchmark, args)
  dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, "artifacts/sim/adversarial_results.rds")
  write.csv(out, "artifacts/sim/adversarial_audit_summary.csv", row.names = FALSE)
  write_manifest(
    "artifacts/sim/adversarial_manifest.json",
    grid = args,
    seed_root = args$seed_root
  )
}
