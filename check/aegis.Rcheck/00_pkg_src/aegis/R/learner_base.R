#' Create a Base Learner Specification
#'
#' @param name Learner identifier.
#' @param fit_fun Optional training function.
#' @param predict_fun Optional prediction function.
#' @param params Optional shared parameter list for fit/predict.
#' @param fit_params Optional parameter list used only for fitting.
#' @param predict_params Optional parameter list used only for prediction.
#' @param interface Learner interface: `"xy"` expects `fit_fun(x, y, ...)` and
#'   `"formula"` expects `fit_fun(formula, data, ...)`.
#' @param formula Optional formula used with the `"formula"` interface.
#'
#' @return An object of class `learner_base`.
#' @export
learner_base <- function(
  name,
  fit_fun = NULL,
  predict_fun = NULL,
  params = list(),
  fit_params = NULL,
  predict_params = NULL,
  interface = c("xy", "formula"),
  formula = NULL
) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    stop("`name` must be a non-empty character scalar.", call. = FALSE)
  }

  if (!is.null(fit_fun) && !is.function(fit_fun)) {
    stop("`fit_fun` must be NULL or a function.", call. = FALSE)
  }

  if (!is.null(predict_fun) && !is.function(predict_fun)) {
    stop("`predict_fun` must be NULL or a function.", call. = FALSE)
  }

  if (!is.list(params)) {
    stop("`params` must be a list.", call. = FALSE)
  }
  if (!is.null(fit_params) && !is.list(fit_params)) {
    stop("`fit_params` must be NULL or a list.", call. = FALSE)
  }
  if (!is.null(predict_params) && !is.list(predict_params)) {
    stop("`predict_params` must be NULL or a list.", call. = FALSE)
  }
  interface <- match.arg(interface)
  if (interface == "formula" && is.null(formula)) {
    stop("`formula` must be provided when interface = \"formula\".", call. = FALSE)
  }

  structure(
    list(
      name = name,
      fit_fun = fit_fun,
      predict_fun = predict_fun,
      params = params,
      fit_params = if (is.null(fit_params)) params else fit_params,
      predict_params = if (is.null(predict_params)) params else predict_params,
      interface = interface,
      formula = formula
    ),
    class = "learner_base"
  )
}
