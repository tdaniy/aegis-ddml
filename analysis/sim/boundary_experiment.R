source("analysis/sim/utils_sim.R")
source("analysis/sim/config.R")

run_boundary_experiment <- function(
  n_grid = c(200, 500, 1000),
  beta_grid = c(0.0, 0.25, 0.5, 0.75),
  reps = 100,
  seed_root = 123,
  stress_reps = 20
) {
  grid <- make_grid(n = n_grid, beta = beta_grid, rep = seq_len(reps))
  results <- list()

  lm_learner <- linear_learner()

  for (i in seq_len(nrow(grid))) {
    row <- grid[i, ]
    seed <- seed_from_root(seed_root, paste("boundary", row$n, row$beta, row$rep, sep = "_"))
    sim <- simulate_plr(n = row$n, beta = row$beta, seed = seed)
    dat <- sim$data
    m0 <- sim$m0
    g0 <- sim$g0

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
    ci_wald <- c(theta_hat - 1.96 * se, theta_hat + 1.96 * se)
    leakage_flag <- isTRUE(fit$diagnostics$leakage$leakage)

    stress_thetas <- numeric(stress_reps)
    for (b in seq_len(stress_reps)) {
      spec_b <- aegis::aegis_spec(
        target = spec$target,
        strategy = spec$strategy,
        nuisance = spec$nuisance,
        seed = seed + 1000 + b
      )
      fit_b <- aegis::aegis_fit(spec_b, dat_cf)
      stress_thetas[b] <- fit_b$theta
    }
    b95 <- stats::quantile(abs(stress_thetas - theta_hat), 0.975, names = FALSE)
    ci_stress <- c(theta_hat - 1.96 * se - b95, theta_hat + 1.96 * se + b95)

    d_tilde <- dat$D - fit$oof$primary$rM
    y_tilde <- dat$Y - fit$oof$primary$rY
    ci_cfel <- el_ci(d_tilde, y_tilde, theta_hat, se = se)

    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      estimator = "AEGIS",
      ci_type = "wald",
      theta0 = 1,
      theta_hat = theta_hat,
      se = se,
      stress_reps = stress_reps,
      stress_b95 = b95,
      leakage_flag = leakage_flag,
      ci_lower = ci_wald[1],
      ci_upper = ci_wald[2],
      cover = ci_wald[1] <= 1 && ci_wald[2] >= 1
    )
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      estimator = "AEGIS",
      ci_type = "stress",
      theta0 = 1,
      theta_hat = theta_hat,
      se = se,
      stress_reps = stress_reps,
      stress_b95 = b95,
      leakage_flag = leakage_flag,
      ci_lower = ci_stress[1],
      ci_upper = ci_stress[2],
      cover = ci_stress[1] <= 1 && ci_stress[2] >= 1
    )
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      estimator = "AEGIS",
      ci_type = "cfel",
      theta0 = 1,
      theta_hat = theta_hat,
      se = se,
      stress_reps = stress_reps,
      stress_b95 = b95,
      leakage_flag = leakage_flag,
      ci_lower = ci_cfel[1],
      ci_upper = ci_cfel[2],
      cover = ci_cfel[1] <= 1 && ci_cfel[2] >= 1
    )

    naive <- fit_naive_ols(dat)
    ci_naive <- c(naive$theta - 1.96 * naive$se, naive$theta + 1.96 * naive$se)
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      estimator = "naive",
      ci_type = "wald",
      theta0 = 1,
      theta_hat = naive$theta,
      se = naive$se,
      stress_reps = NA_integer_,
      stress_b95 = NA_real_,
      leakage_flag = NA,
      ci_lower = ci_naive[1],
      ci_upper = ci_naive[2],
      cover = ci_naive[1] <= 1 && ci_naive[2] >= 1
    )

    split <- fit_sample_split(dat, seed = seed)
    ci_split <- c(split$theta - 1.96 * split$se, split$theta + 1.96 * split$se)
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      estimator = "sample_split",
      ci_type = "wald",
      theta0 = 1,
      theta_hat = split$theta,
      se = split$se,
      stress_reps = NA_integer_,
      stress_b95 = NA_real_,
      leakage_flag = NA,
      ci_lower = ci_split[1],
      ci_upper = ci_split[2],
      cover = ci_split[1] <= 1 && ci_split[2] >= 1
    )

    oracle <- fit_oracle(dat, m0, g0)
    ci_oracle <- c(oracle$theta - 1.96 * oracle$se, oracle$theta + 1.96 * oracle$se)
    results[[length(results) + 1]] <- data.frame(
      n = row$n,
      beta = row$beta,
      estimator = "oracle",
      ci_type = "wald",
      theta0 = 1,
      theta_hat = oracle$theta,
      se = oracle$se,
      stress_reps = NA_integer_,
      stress_b95 = NA_real_,
      leakage_flag = NA,
      ci_lower = ci_oracle[1],
      ci_upper = ci_oracle[2],
      cover = ci_oracle[1] <= 1 && ci_oracle[2] >= 1
    )
  }

  do.call(rbind, results)
}

if (sys.nframe() == 0) {
  profile <- get_profile()
  args <- profile$boundary
  out <- do.call(run_boundary_experiment, args)
  dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, "artifacts/sim/boundary_results.rds")
  write.csv(out, "artifacts/sim/boundary_summary.csv", row.names = FALSE)
  write.csv(summary_metrics(out), "artifacts/sim/summary_metrics.csv", row.names = FALSE)
  write_manifest(
    "artifacts/sim/boundary_manifest.json",
    grid = args,
    seed_root = args$seed_root
  )
}
