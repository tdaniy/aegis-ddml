#' Create a Cross-Fitting Strategy
#'
#' @param v Number of folds. Must be an integer >= 2.
#' @param repeats Number of repeated fold schedules. Must be an integer >= 1.
#' @param shuffle Whether to shuffle rows before assigning folds.
#'
#' @return An object of class `strategy_crossfit`.
#' @export
strategy_crossfit <- function(v = 5L, repeats = 1L, shuffle = TRUE) {
  if (!is.numeric(v) || length(v) != 1L || is.na(v) || v != as.integer(v) || v < 2L) {
    stop("`v` must be a single integer >= 2.", call. = FALSE)
  }

  if (!is.numeric(repeats) || length(repeats) != 1L || is.na(repeats) ||
      repeats != as.integer(repeats) || repeats < 1L) {
    stop("`repeats` must be a single integer >= 1.", call. = FALSE)
  }

  if (!is.logical(shuffle) || length(shuffle) != 1L || is.na(shuffle)) {
    stop("`shuffle` must be TRUE or FALSE.", call. = FALSE)
  }

  structure(
    list(
      v = as.integer(v),
      repeats = as.integer(repeats),
      shuffle = shuffle
    ),
    class = "strategy_crossfit"
  )
}
