seed_from_root <- function(seed_root, key) {
  digest_val <- sum(as.integer(charToRaw(paste0(seed_root, "_", key))))
  abs(digest_val) %% .Machine$integer.max
}

write_manifest <- function(path, grid, seed_root, extra = list()) {
  git_hash <- tryCatch(
    system("git rev-parse HEAD", intern = TRUE),
    error = function(e) NA_character_
  )
  manifest <- c(
    list(
      timestamp = as.character(Sys.time()),
      seed_root = seed_root,
      grid = grid,
      git_hash = git_hash
    ),
    extra
  )
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE)
}

make_grid <- function(...) {
  grid <- expand.grid(..., KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid
}

simulate_plr <- function(n, beta, theta = 1, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  z1 <- rnorm(n)
  z2 <- rnorm(n)
  m0 <- sin(z1) + 0.5 * z2^2
  g0 <- cos(z1) + z1 * z2
  kappa <- n^(-beta)
  v <- sqrt(kappa) * rnorm(n)
  d <- m0 + v
  y <- theta * d + g0 + rnorm(n)
  list(
    data = data.frame(Y = y, D = d, Z1 = z1, Z2 = z2),
    m0 = m0,
    g0 = g0
  )
}

simulate_plr_logistic <- function(n, beta, theta = 1, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  z1 <- rnorm(n)
  z2 <- rnorm(n)
  m0 <- sin(z1) + 0.5 * z2^2
  g0 <- cos(z1) + z1 * z2
  kappa <- n^(-beta)
  v <- sqrt(kappa) * rnorm(n)
  d <- m0 + v
  p <- plogis(theta * d + g0)
  y <- rbinom(n, 1, p)
  list(
    data = data.frame(Y = y, D = d, Z1 = z1, Z2 = z2),
    m0 = m0,
    g0 = g0
  )
}

summary_metrics <- function(results) {
  results$group <- paste(results$estimator, results$ci_type, sep = ":")
  data.frame(
    estimator = tapply(results$estimator, results$group, unique),
    ci_type = tapply(results$ci_type, results$group, unique),
    coverage = tapply(results$cover, results$group, mean),
    bias = tapply(results$theta_hat - results$theta0, results$group, mean),
    rmse = sqrt(tapply((results$theta_hat - results$theta0)^2, results$group, mean)),
    ci_len = tapply(results$ci_upper - results$ci_lower, results$group, mean)
  )
}

make_poly_basis <- function(dat) {
  data.frame(
    Z1 = dat$Z1,
    Z2 = dat$Z2,
    Z1_sq = dat$Z1^2,
    Z2_sq = dat$Z2^2,
    Z1_Z2 = dat$Z1 * dat$Z2,
    sin_Z1 = sin(dat$Z1),
    cos_Z1 = cos(dat$Z1),
    sin_Z2 = sin(dat$Z2),
    cos_Z2 = cos(dat$Z2)
  )
}

make_linear_basis <- function(dat) {
  data.frame(
    Z1 = dat$Z1,
    Z2 = dat$Z2
  )
}

poly_learner <- function(name = "poly-lm") {
  aegis::learner_base(
    name = name,
    fit_fun = function(x, y) {
      stats::lm(y ~ ., data = data.frame(y = y, x))
    },
    predict_fun = function(fit, newdata) {
      stats::predict(fit, newdata = data.frame(newdata))
    }
  )
}

linear_learner <- function(name = "lm") {
  aegis::learner_base(
    name = name,
    fit_fun = function(x, y) {
      stats::lm(y ~ ., data = data.frame(y = y, x))
    },
    predict_fun = function(fit, newdata) {
      stats::predict(fit, newdata = data.frame(newdata))
    }
  )
}

ridge_learner <- function(lambda = 1, name = NULL) {
  if (is.null(name)) {
    name <- sprintf("ridge-lm-lambda-%g", lambda)
  }
  aegis::learner_base(
    name = name,
    fit_fun = function(x, y) {
      x_mat <- as.matrix(cbind(Intercept = 1, x))
      coef <- solve(crossprod(x_mat) + diag(lambda, ncol(x_mat)), crossprod(x_mat, y))
      list(coef = coef)
    },
    predict_fun = function(fit, newdata) {
      x_mat <- as.matrix(cbind(Intercept = 1, newdata))
      as.numeric(x_mat %*% fit$coef)
    }
  )
}

composite_score <- function(weak_ratio, instab, infl) {
  if (!is.finite(weak_ratio) || !is.finite(instab) || !is.finite(infl)) {
    return(NA_real_)
  }
  weak_z <- (weak_ratio - 0.02) / 0.02
  instab_z <- (instab - 0.01) / 0.01
  infl_z <- (infl - 2.0) / 1.0
  0.5 * weak_z + 0.3 * instab_z + 0.2 * infl_z
}

fit_naive_ols <- function(dat) {
  fit <- stats::lm(Y ~ D + Z1 + Z2, data = dat)
  est <- stats::coef(summary(fit))["D", ]
  theta <- est["Estimate"]
  se <- est["Std. Error"]
  list(theta = theta, se = se)
}

fit_sample_split <- function(dat, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  n <- nrow(dat)
  idx <- sample.int(n, size = floor(n / 2))
  train <- dat[idx, ]
  test <- dat[-idx, ]

  g_fit <- stats::lm(Y ~ Z1 + Z2, data = train)
  m_fit <- stats::lm(D ~ Z1 + Z2, data = train)
  g_hat <- stats::predict(g_fit, newdata = test)
  m_hat <- stats::predict(m_fit, newdata = test)

  inf <- aegis::inference_lm(
    y = test$Y,
    d = test$D,
    g_hat = g_hat,
    m_hat = m_hat
  )
  list(theta = inf$theta, se = inf$se)
}

fit_oracle <- function(dat, m0, g0) {
  inf <- aegis::inference_lm(
    y = dat$Y,
    d = dat$D,
    g_hat = g0,
    m_hat = m0
  )
  list(theta = inf$theta, se = inf$se)
}

el_ci <- function(d_tilde, y_tilde, theta_hat, alpha = 0.05, se = NULL) {
  psi_at <- function(theta) d_tilde * (y_tilde - d_tilde * theta)
  el_lambda <- function(psi) {
    pos <- psi[psi > 0]
    neg <- psi[psi < 0]
    if (length(pos) == 0 || length(neg) == 0) {
      return(NA_real_)
    }
    lower <- -1 / max(pos)
    upper <- -1 / min(neg)
    f <- function(lam) sum(psi / (1 + lam * psi))
    uniroot(f, lower = lower + 1e-8, upper = upper - 1e-8)$root
  }
  elr <- function(theta) {
    psi <- psi_at(theta)
    lam <- el_lambda(psi)
    if (!is.finite(lam)) return(NA_real_)
    2 * sum(log(1 + lam * psi))
  }
  crit <- stats::qchisq(1 - alpha, df = 1)
  if (is.null(se) || !is.finite(se)) {
    se <- stats::sd(y_tilde) / sqrt(length(y_tilde))
  }
  lower_bound <- theta_hat - 5 * se
  upper_bound <- theta_hat + 5 * se
  f_lower <- function(theta) elr(theta) - crit
  left <- tryCatch(uniroot(f_lower, lower = lower_bound, upper = theta_hat)$root,
                   error = function(e) NA_real_)
  right <- tryCatch(uniroot(f_lower, lower = theta_hat, upper = upper_bound)$root,
                    error = function(e) NA_real_)
  c(lower = left, upper = right)
}
