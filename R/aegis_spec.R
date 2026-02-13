#' Create an AEGIS Model Specification
#'
#' @param target A target object created by [target_lm()] or [target_glm()].
#' @param strategy A cross-fitting strategy created by [strategy_crossfit()].
#' @param nuisance A nuisance specification created by [nuis_spec()].
#' @param seed Optional integer seed for deterministic execution.
#'
#' @return An object of class `aegis_spec`.
#' @export
aegis_spec <- function(target, strategy, nuisance, seed = NULL) {
  if (!inherits(target, "aegis_target")) {
    stop("`target` must inherit from class 'aegis_target'.", call. = FALSE)
  }

  if (!inherits(strategy, "strategy_crossfit")) {
    stop("`strategy` must inherit from class 'strategy_crossfit'.", call. = FALSE)
  }

  if (!inherits(nuisance, "nuis_spec")) {
    stop("`nuisance` must inherit from class 'nuis_spec'.", call. = FALSE)
  }

  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed != as.integer(seed)) {
      stop("`seed` must be NULL or a single integer value.", call. = FALSE)
    }
    seed <- as.integer(seed)
  }

  structure(
    list(
      target = target,
      strategy = strategy,
      nuisance = nuisance,
      seed = seed
    ),
    class = "aegis_spec"
  )
}
