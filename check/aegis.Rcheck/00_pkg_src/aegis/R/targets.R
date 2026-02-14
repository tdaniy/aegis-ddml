#' Define a Linear Target
#'
#' @param outcome Name of the outcome column.
#' @param treatment Name of the target regressor column.
#' @param controls Optional vector of control column names.
#'
#' @return An object of class `aegis_target_lm`.
#' @export
target_lm <- function(outcome, treatment, controls = character()) {
  .validate_name_scalar(outcome, arg = "outcome")
  .validate_name_scalar(treatment, arg = "treatment")
  .validate_name_vector(controls, arg = "controls")

  if (identical(outcome, treatment)) {
    stop("`outcome` and `treatment` must refer to different columns.", call. = FALSE)
  }

  structure(
    list(
      model = "lm",
      outcome = outcome,
      treatment = treatment,
      controls = controls
    ),
    class = c("aegis_target_lm", "aegis_target")
  )
}

#' Define a Generalized Linear Target
#'
#' @param outcome Name of the outcome column.
#' @param treatment Name of the target regressor column.
#' @param controls Optional vector of control column names.
#' @param family A GLM family object such as [stats::binomial()].
#'
#' @return An object of class `aegis_target_glm`.
#' @export
target_glm <- function(outcome, treatment, controls = character(), family = stats::binomial()) {
  .validate_name_scalar(outcome, arg = "outcome")
  .validate_name_scalar(treatment, arg = "treatment")
  .validate_name_vector(controls, arg = "controls")

  if (identical(outcome, treatment)) {
    stop("`outcome` and `treatment` must refer to different columns.", call. = FALSE)
  }

  if (!inherits(family, "family")) {
    stop("`family` must be a valid GLM family object.", call. = FALSE)
  }

  structure(
    list(
      model = "glm",
      family = family,
      outcome = outcome,
      treatment = treatment,
      controls = controls
    ),
    class = c("aegis_target_glm", "aegis_target")
  )
}

.validate_name_scalar <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(sprintf("`%s` must be a non-empty character scalar.", arg), call. = FALSE)
  }
}

.validate_name_vector <- function(x, arg) {
  if (!is.character(x)) {
    stop(sprintf("`%s` must be a character vector.", arg), call. = FALSE)
  }
  if (anyNA(x) || any(!nzchar(x))) {
    stop(sprintf("`%s` cannot contain NA or empty strings.", arg), call. = FALSE)
  }
}
