#' Leakage Diagnostic
#'
#' @param folds Fold assignments from [make_folds()].
#' @param oof_pred Optional OOF predictions (vector or list) for coverage checks.
#'
#' @return A list summarizing leakage status.
#' @export
diagnostics_leakage <- function(folds, oof_pred = NULL) {
  if (length(folds) == 0L) {
    stop("`folds` must be non-empty.", call. = FALSE)
  }
  if (anyNA(folds) || any(folds < 1L)) {
    stop("`folds` must contain positive integers.", call. = FALSE)
  }

  failures <- integer(0)
  for (k in sort(unique(folds))) {
    test_idx <- which(folds == k)
    train_idx <- which(folds != k)
    if (length(intersect(test_idx, train_idx)) > 0L) {
      failures <- c(failures, k)
    }
  }

  oof_coverage <- NULL
  if (!is.null(oof_pred)) {
    if (is.list(oof_pred)) {
      coverage_vals <- vapply(oof_pred, function(x) mean(is.finite(x)), numeric(1))
      oof_coverage <- list(
        per_component = coverage_vals,
        min_coverage = min(coverage_vals)
      )
    } else {
      oof_coverage <- list(
        min_coverage = mean(is.finite(oof_pred))
      )
    }
  }

  list(
    leakage = length(failures) > 0L,
    failure_folds = failures,
    fold_counts = tabulate(folds),
    oof_coverage = oof_coverage
  )
}

#' Weak-Signal Diagnostic
#'
#' @param d_tilde Residualized treatment vector.
#' @param d_raw Raw treatment vector.
#' @param threshold_fail Failure threshold for variance ratio. When `NULL`,
#'   defaults to `max(0.005, 1 / n)`.
#' @param threshold_warn Warning threshold for variance ratio. When `NULL`,
#'   defaults to `max(0.02, 2 / n)`.
#'
#' @return A list with variance and status.
#' @export
diagnostics_weak_signal <- function(d_tilde, d_raw, threshold_fail = NULL, threshold_warn = NULL) {
  n <- length(d_tilde)
  if (is.null(threshold_fail)) {
    threshold_fail <- max(0.005, 1 / n)
  }
  if (is.null(threshold_warn)) {
    threshold_warn <- max(0.02, 2 / n)
  }
  if (!is.numeric(threshold_fail) || length(threshold_fail) != 1L || is.na(threshold_fail) ||
      threshold_fail <= 0) {
    stop("`threshold_fail` must be a positive number.", call. = FALSE)
  }
  if (!is.numeric(threshold_warn) || length(threshold_warn) != 1L || is.na(threshold_warn) ||
      threshold_warn <= threshold_fail) {
    stop("`threshold_warn` must be greater than `threshold_fail`.", call. = FALSE)
  }

  var_dt <- stats::var(d_tilde)
  var_d <- stats::var(d_raw)
  ratio <- if (is.na(var_dt) || is.na(var_d) || var_d <= .Machine$double.eps) {
    NA_real_
  } else {
    var_dt / var_d
  }

  status <- if (is.na(ratio) || ratio <= threshold_fail) {
    "FAIL"
  } else if (ratio <= threshold_warn) {
    "WARN"
  } else {
    "PASS"
  }

  list(
    variance_residual = var_dt,
    variance_raw = var_d,
    ratio = ratio,
    n = n,
    threshold_fail = threshold_fail,
    threshold_warn = threshold_warn,
    status = status
  )
}

#' Influence Diagnostic
#'
#' @param score Score vector from orthogonal inference.
#'
#' @return A list with influence summaries.
#' @export
diagnostics_influence <- function(score) {
  abs_score <- abs(score)
  sd_score <- stats::sd(score)
  std_score <- if (is.finite(sd_score) && sd_score > 0) score / sd_score else rep(NA_real_, length(score))
  abs_std <- abs(std_score)
  list(
    max_abs = max(abs_score),
    mean_abs = mean(abs_score),
    p95_abs = stats::quantile(abs_score, 0.95, names = FALSE),
    p99_abs = stats::quantile(abs_score, 0.99, names = FALSE),
    max_abs_std = max(abs_std, na.rm = TRUE),
    mean_abs_std = mean(abs_std, na.rm = TRUE),
    p95_abs_std = stats::quantile(abs_std, 0.95, names = FALSE, na.rm = TRUE),
    p99_abs_std = stats::quantile(abs_std, 0.99, names = FALSE, na.rm = TRUE)
  )
}
