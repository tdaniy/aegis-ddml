#' Create a Base Learner Specification
#'
#' @param name Learner identifier.
#' @param fit_fun Optional training function.
#' @param predict_fun Optional prediction function.
#' @param params Optional named or unnamed list of learner parameters.
#'
#' @return An object of class `learner_base`.
#' @export
learner_base <- function(name, fit_fun = NULL, predict_fun = NULL, params = list()) {
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

  structure(
    list(
      name = name,
      fit_fun = fit_fun,
      predict_fun = predict_fun,
      params = params
    ),
    class = "learner_base"
  )
}
