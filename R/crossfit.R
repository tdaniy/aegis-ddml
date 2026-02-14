#' Generate Cross-Fitting Folds
#'
#' @param n Number of observations.
#' @param v Number of folds.
#' @param seed Optional seed for deterministic folds.
#' @param shuffle Whether to shuffle observations before assigning folds.
#'
#' @return Integer vector of fold assignments in `1:v`.
#' @export
make_folds <- function(n, v, seed = NULL, shuffle = TRUE) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n != as.integer(n) || n < 2L) {
    stop("`n` must be a single integer >= 2.", call. = FALSE)
  }
  if (!is.numeric(v) || length(v) != 1L || is.na(v) || v != as.integer(v) || v < 2L) {
    stop("`v` must be a single integer >= 2.", call. = FALSE)
  }
  if (v > n) {
    stop("`v` must be less than or equal to `n`.", call. = FALSE)
  }
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed != as.integer(seed)) {
      stop("`seed` must be NULL or a single integer.", call. = FALSE)
    }
    set.seed(as.integer(seed))
  }
  if (!is.logical(shuffle) || length(shuffle) != 1L || is.na(shuffle)) {
    stop("`shuffle` must be TRUE or FALSE.", call. = FALSE)
  }

  n <- as.integer(n)
  v <- as.integer(v)

  perm <- if (shuffle) sample.int(n) else seq_len(n)
  fold_assign <- rep_len(seq_len(v), n)
  folds <- integer(n)
  folds[perm] <- fold_assign
  folds
}

#' Cross-Fitted Out-of-Fold Predictions
#'
#' @param learner A `learner_base` object with `fit_fun` and `predict_fun`.
#' @param x Feature data as a data.frame or matrix (for `interface = "xy"`).
#' @param y Outcome vector aligned to `x` (for `interface = "xy"`).
#' @param data Training data (for `interface = "formula"`).
#' @param folds Integer fold vector produced by [make_folds()].
#'
#' @return A list with `pred` and `fits`.
#' @export
crossfit_predict <- function(learner, x = NULL, y = NULL, folds, data = NULL) {
  if (!inherits(learner, "learner_base")) {
    stop("`learner` must inherit from class 'learner_base'.", call. = FALSE)
  }
  if (learner$interface == "xy") {
    if (!is.data.frame(x) && !is.matrix(x)) {
      stop("`x` must be a data.frame or matrix.", call. = FALSE)
    }
    x <- as.data.frame(x)
    n <- nrow(x)
    if (length(y) != n) {
      stop("`y` length must match nrow(x).", call. = FALSE)
    }
  } else {
    if (!is.data.frame(data)) {
      stop("`data` must be a data.frame for formula interface.", call. = FALSE)
    }
    n <- nrow(data)
  }
  if (length(folds) != n) {
    stop("`folds` length must match nrow(x).", call. = FALSE)
  }
  if (anyNA(folds) || any(folds < 1L)) {
    stop("`folds` must contain positive integers.", call. = FALSE)
  }
  v <- max(folds)
  if (!all(seq_len(v) %in% folds)) {
    stop("`folds` must cover 1:v without gaps.", call. = FALSE)
  }
  if (is.null(learner$fit_fun) || !is.function(learner$fit_fun)) {
    stop("`learner$fit_fun` must be a function.", call. = FALSE)
  }
  if (is.null(learner$predict_fun) || !is.function(learner$predict_fun)) {
    stop("`learner$predict_fun` must be a function.", call. = FALSE)
  }

  preds <- rep(NA_real_, n)
  fits <- vector("list", v)

  for (k in seq_len(v)) {
    test_idx <- folds == k
    train_idx <- !test_idx
    if (!any(test_idx)) {
      next
    }
    if (learner$interface == "xy") {
      fit <- .fit_learner_xy(learner, x[train_idx, , drop = FALSE], y[train_idx])
      pred <- .predict_learner_xy(learner, fit, x[test_idx, , drop = FALSE])
    } else {
      fit <- .fit_learner_formula(learner, data[train_idx, , drop = FALSE])
      pred <- .predict_learner_formula(learner, fit, data[test_idx, , drop = FALSE])
    }
    preds[test_idx] <- as.numeric(pred)
    fits[[k]] <- fit
  }

  list(pred = preds, fits = fits)
}

.fit_learner_xy <- function(learner, x, y) {
  args <- c(list(x = x, y = y), learner$fit_params)
  do.call(learner$fit_fun, args)
}

.predict_learner_xy <- function(learner, fit, newdata) {
  args <- c(list(fit = fit, newdata = newdata), learner$predict_params)
  do.call(learner$predict_fun, args)
}

.fit_learner_formula <- function(learner, data) {
  args <- c(list(formula = learner$formula, data = data), learner$fit_params)
  do.call(learner$fit_fun, args)
}

.predict_learner_formula <- function(learner, fit, newdata) {
  args <- c(list(fit = fit, newdata = newdata), learner$predict_params)
  do.call(learner$predict_fun, args)
}
