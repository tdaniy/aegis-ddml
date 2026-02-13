#' @export
print.aegis_fit <- function(x, ...) {
  cat("<aegis_fit>\n")
  cat("  n     :", x$n, "\n")
  cat("  theta :", x$theta, "\n")
  cat("  se    :", x$se, "\n")
  invisible(x)
}

#' Summarize an AEGIS Fit
#'
#' @param object An object of class `aegis_fit`.
#' @param level Confidence level in `(0, 1)`.
#' @param ... Additional arguments passed to [confint()].
#'
#' @return An object of class `summary.aegis_fit`.
#' @export
summary.aegis_fit <- function(object, level = 0.95, ...) {
  if (!is.numeric(level) || length(level) != 1L || is.na(level) || level <= 0 || level >= 1) {
    stop("`level` must be a single number in (0, 1).", call. = FALSE)
  }

  out <- list(
    n = object$n,
    theta = object$theta,
    se = object$se,
    confint = stats::confint(object, level = level, ...)
  )
  class(out) <- "summary.aegis_fit"
  out
}

#' @export
print.summary.aegis_fit <- function(x, ...) {
  cat("AEGIS fit summary\n")
  cat("  n     :", x$n, "\n")
  cat("  theta :", x$theta, "\n")
  cat("  se    :", x$se, "\n")
  cat("\nConfidence interval:\n")
  print(x$confint)
  invisible(x)
}

#' Confidence Interval for an AEGIS Fit
#'
#' @param object An object of class `aegis_fit`.
#' @param parm Parameter name to label the interval row.
#' @param level Confidence level in `(0, 1)`.
#' @param ... Unused.
#'
#' @return A matrix with `lower` and `upper` columns.
#' @export
confint.aegis_fit <- function(object, parm = "theta", level = 0.95, ...) {
  if (!is.character(parm) || length(parm) != 1L || is.na(parm) || !nzchar(parm)) {
    stop("`parm` must be a non-empty character scalar.", call. = FALSE)
  }

  if (!is.numeric(level) || length(level) != 1L || is.na(level) || level <= 0 || level >= 1) {
    stop("`level` must be a single number in (0, 1).", call. = FALSE)
  }

  if (is.finite(object$theta) && is.finite(object$se) && object$se >= 0) {
    z <- stats::qnorm(1 - (1 - level) / 2)
    lower <- object$theta - z * object$se
    upper <- object$theta + z * object$se
  } else {
    lower <- NA_real_
    upper <- NA_real_
  }

  matrix(
    c(lower, upper),
    nrow = 1L,
    dimnames = list(parm, c("lower", "upper"))
  )
}
