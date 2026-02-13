#' Create a Nuisance Specification
#'
#' @param outcome_model A learner specification for outcome nuisance estimation.
#' @param treatment_model A learner specification for treatment nuisance estimation.
#'
#' @return An object of class `nuis_spec`.
#' @export
nuis_spec <- function(outcome_model, treatment_model) {
  if (!inherits(outcome_model, "learner_base")) {
    stop("`outcome_model` must inherit from class 'learner_base'.", call. = FALSE)
  }

  if (!inherits(treatment_model, "learner_base")) {
    stop("`treatment_model` must inherit from class 'learner_base'.", call. = FALSE)
  }

  structure(
    list(
      outcome_model = outcome_model,
      treatment_model = treatment_model
    ),
    class = "nuis_spec"
  )
}
