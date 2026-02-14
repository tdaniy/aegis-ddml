#' Fit Outcome Nuisance with Cross-Fitting
#'
#' @param data A data.frame containing model inputs.
#' @param target A target object created by [target_lm()] or [target_glm()].
#' @param nuisance A nuisance specification created by [nuis_spec()].
#' @param folds Fold assignments from [make_folds()].
#'
#' @return A list with OOF predictions and model fits.
#' @export
fit_nuisance_rY <- function(data, target, nuisance, folds) {
  if (!inherits(target, "aegis_target")) {
    stop("`target` must inherit from class 'aegis_target'.", call. = FALSE)
  }
  if (!inherits(nuisance, "nuis_spec")) {
    stop("`nuisance` must inherit from class 'nuis_spec'.", call. = FALSE)
  }
  .validate_data_columns(data, c(target$outcome, target$controls))

  if (nuisance$outcome_model$interface == "formula") {
    model_data <- .build_model_data(data, target$outcome, target$controls)
    fit <- crossfit_predict(nuisance$outcome_model, data = model_data, folds = folds)
  } else {
    x <- .build_design_matrix(data, target$controls)
    y <- data[[target$outcome]]
    fit <- crossfit_predict(nuisance$outcome_model, x = x, y = y, folds = folds)
  }

  if (inherits(target, "aegis_target_glm")) {
    fit$pred <- .prob_to_logit(fit$pred)
  }

  fit
}

#' Fit Treatment Nuisance with Cross-Fitting
#'
#' @inheritParams fit_nuisance_rY
#'
#' @return A list with OOF predictions and model fits.
#' @export
fit_nuisance_rM <- function(data, target, nuisance, folds) {
  if (!inherits(target, "aegis_target")) {
    stop("`target` must inherit from class 'aegis_target'.", call. = FALSE)
  }
  if (!inherits(nuisance, "nuis_spec")) {
    stop("`nuisance` must inherit from class 'nuis_spec'.", call. = FALSE)
  }
  .validate_data_columns(data, c(target$treatment, target$controls))

  if (nuisance$treatment_model$interface == "formula") {
    model_data <- .build_model_data(data, target$treatment, target$controls)
    crossfit_predict(nuisance$treatment_model, data = model_data, folds = folds)
  } else {
    x <- .build_design_matrix(data, target$controls)
    y <- data[[target$treatment]]
    crossfit_predict(nuisance$treatment_model, x = x, y = y, folds = folds)
  }
}

.build_design_matrix <- function(data, controls) {
  if (length(controls) == 0L) {
    data.frame(.intercept = rep(1, nrow(data)))
  } else {
    data[, controls, drop = FALSE]
  }
}

.build_model_data <- function(data, response, controls) {
  cols <- unique(c(response, controls))
  data[, cols, drop = FALSE]
}

.validate_data_columns <- function(data, cols) {
  missing_cols <- setdiff(cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(sprintf("Missing columns in `data`: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }
}

.prob_to_logit <- function(p, eps = 1e-6) {
  p <- pmin(pmax(p, eps), 1 - eps)
  stats::qlogis(p)
}
