run_once <- function() {
  ok <- TRUE
  tryCatch(
    {
      devtools::load_all(quiet = TRUE)
      testthat::test_dir(
        "tests/testthat",
        reporter = "summary",
        stop_on_failure = TRUE,
        stop_on_warning = TRUE
      )
    },
    error = function(e) {
      ok <<- FALSE
    }
  )
  ok
}

results <- vapply(seq_len(3), function(i) run_once(), logical(1))
out <- data.frame(run = seq_len(3), pass = results)
dir.create("artifacts", recursive = TRUE, showWarnings = FALSE)
write.csv(out, "artifacts/test_repeat.csv", row.names = FALSE)

cat("Test repeat summary:\n")
print(out)
