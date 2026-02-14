#' Orthogonal Inference for GLM Targets
#'
#' @param y Outcome vector.
#' @param d Treatment vector.
#' @param g_hat OOF nuisance estimate on the link scale.
#' @param m_hat OOF nuisance estimate for treatment regression.
#' @param family GLM family object (binomial required in Phase C).
#' @param max_iter Maximum number of Newton iterations.
#' @param tol Convergence tolerance for theta updates.
#' @param tol_score Convergence tolerance for score norm.
#' @param max_halving Maximum number of step-halving attempts.
#' @param start_theta Optional starting value for theta.
#'
#' @return A list with `theta`, `se`, `vcov`, `score`, and diagnostics.
#' @export
inference_glm <- function(
  y,
  d,
  g_hat,
  m_hat,
  family,
  max_iter = 50L,
  tol = 1e-6,
  tol_score = 1e-6,
  max_halving = 10L,
  start_theta = NULL
) {
  n <- length(y)
  if (length(d) != n || length(g_hat) != n || length(m_hat) != n) {
    stop("All inputs must have the same length.", call. = FALSE)
  }
  if (!inherits(family, "family") || family$family != "binomial") {
    stop("Phase C inference_glm currently supports binomial family only.", call. = FALSE)
  }

  theta <- 0
  if (!is.null(start_theta) && is.finite(start_theta)) {
    theta <- start_theta
  } else {
    start <- suppressWarnings(
      try(stats::glm(y ~ d, family = stats::binomial()), silent = TRUE)
    )
    if (!inherits(start, "try-error")) {
      coef_start <- stats::coef(start)
      if (length(coef_start) >= 2 && is.finite(coef_start[2])) {
        theta <- coef_start[2]
      }
    }
  }
  converged <- FALSE
  score_norm <- NA_real_

  for (iter in seq_len(max_iter)) {
    eta <- theta * d + g_hat
    p <- stats::plogis(eta)
    score <- (d - m_hat) * (y - p)
    gprime <- p * (1 - p)
    j_hat <- -mean((d - m_hat) * d * gprime)
    if (!is.finite(j_hat) || abs(j_hat) <= .Machine$double.eps) {
      stop("Degenerate Jacobian in GLM inference.", call. = FALSE)
    }
    step <- mean(score) / j_hat
    theta_new <- theta - step

    eta_new <- theta_new * d + g_hat
    score_new <- (d - m_hat) * (y - stats::plogis(eta_new))
    score_norm_new <- abs(mean(score_new))

    if (score_norm_new > abs(mean(score))) {
      for (h in seq_len(max_halving)) {
        step <- step / 2
        theta_new <- theta - step
        eta_new <- theta_new * d + g_hat
        score_new <- (d - m_hat) * (y - stats::plogis(eta_new))
        score_norm_new <- abs(mean(score_new))
        if (score_norm_new <= abs(mean(score))) {
          break
        }
      }
    }

    score_norm <- score_norm_new
    theta_tol <- tol * max(1, abs(theta))
    score_tol <- tol_score * max(1, abs(mean(y)))
    if (abs(theta_new - theta) < theta_tol && score_norm < score_tol) {
      theta <- theta_new
      converged <- TRUE
      break
    }
    theta <- theta_new
  }

  if (!converged) {
    stop("GLM inference did not converge within max_iter.", call. = FALSE)
  }

  eta <- theta * d + g_hat
  p <- stats::plogis(eta)
  score <- (d - m_hat) * (y - p)
  gprime <- p * (1 - p)
  j_hat <- -mean((d - m_hat) * d * gprime)
  omega_hat <- mean(score^2)
  se <- sqrt(omega_hat / (n * j_hat^2))
  vcov <- matrix(se^2, nrow = 1L, ncol = 1L, dimnames = list("theta", "theta"))

  list(
    theta = theta,
    se = se,
    vcov = vcov,
    score = score,
    d_tilde = d - m_hat,
    j_hat = j_hat,
    omega_hat = omega_hat,
    iterations = iter,
    score_norm = score_norm
  )
}
