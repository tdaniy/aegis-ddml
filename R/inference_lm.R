#' Orthogonal Inference for Linear Targets
#'
#' @param y Outcome vector.
#' @param d Treatment vector.
#' @param g_hat OOF nuisance estimate for outcome regression.
#' @param m_hat OOF nuisance estimate for treatment regression.
#'
#' @return A list with `theta`, `se`, `vcov`, `score`, and intermediates.
#' @export
inference_lm <- function(y, d, g_hat, m_hat) {
  n <- length(y)
  if (length(d) != n || length(g_hat) != n || length(m_hat) != n) {
    stop("All inputs must have the same length.", call. = FALSE)
  }

  d_tilde <- d - m_hat
  y_tilde <- y - g_hat
  denom <- sum(d_tilde^2)
  if (!is.finite(denom) || denom <= .Machine$double.eps) {
    stop("Degenerate residualized treatment variance; inference undefined.", call. = FALSE)
  }

  theta <- sum(d_tilde * y_tilde) / denom
  score <- d_tilde * (y_tilde - d_tilde * theta)
  j_hat <- -mean(d_tilde^2)
  omega_hat <- mean(score^2)
  se <- sqrt(omega_hat / (n * j_hat^2))
  vcov <- matrix(se^2, nrow = 1L, ncol = 1L, dimnames = list("theta", "theta"))

  list(
    theta = theta,
    se = se,
    vcov = vcov,
    score = score,
    d_tilde = d_tilde,
    y_tilde = y_tilde,
    j_hat = j_hat,
    omega_hat = omega_hat
  )
}
