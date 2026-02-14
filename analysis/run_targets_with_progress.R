library(targets)
source("analysis/sim/config.R")

format_eta <- function(seconds) {
  if (!is.finite(seconds)) {
    return("unknown")
  }
  mins <- floor(seconds / 60)
  secs <- round(seconds %% 60)
  sprintf("%dm %ds", mins, secs)
}

estimate_remaining <- function(remaining, baseline_secs, observed_secs) {
  if (length(remaining) == 0) {
    return(0)
  }
  fallback <- mean(observed_secs, na.rm = TRUE)
  est <- 0
  for (name in remaining) {
    if (!is.na(baseline_secs[[name]])) {
      est <- est + baseline_secs[[name]]
    } else if (is.finite(fallback)) {
      est <- est + fallback
    }
  }
  est
}

profile_name <- Sys.getenv("AEGIS_PROFILE", "default")
if (Sys.getenv("AEGIS_FAST") == "1") {
  profile_name <- "fast"
}
cat(sprintf("Using AEGIS_PROFILE=%s\n", profile_name))

targets_list <- c(
  "boundary_results",
  "calibration_results",
  "adversarial_results",
  "boundary_artifacts",
  "calibration_artifacts",
  "adversarial_artifacts",
  "boundary_summary",
  "calibration_summary",
  "adversarial_summary"
)

baseline_secs <- numeric(0)
baseline <- tryCatch(
  tar_meta(fields = c("name", "seconds")),
  error = function(e) NULL
)
if (!is.null(baseline) && nrow(baseline) > 0) {
  baseline_agg <- aggregate(seconds ~ name, baseline, function(x) mean(x, na.rm = TRUE))
  baseline_secs <- stats::setNames(baseline_agg$seconds, baseline_agg$name)
}

observed_secs <- numeric(0)
progress_log <- data.frame(
  step = character(0),
  seconds = numeric(0),
  eta_seconds = numeric(0),
  stringsAsFactors = FALSE
)

start_time <- Sys.time()

for (idx in seq_along(targets_list)) {
  target_name <- targets_list[[idx]]
  cat(sprintf("Running %s (%d/%d)\n", target_name, idx, length(targets_list)))
  step_start <- Sys.time()
  tar_make(names = target_name, reporter = "balanced")
  step_end <- Sys.time()
  elapsed <- as.numeric(difftime(step_end, step_start, units = "secs"))

  observed_secs <- c(observed_secs, elapsed)
  names(observed_secs)[length(observed_secs)] <- target_name

  remaining <- targets_list[(idx + 1):length(targets_list)]
  eta <- estimate_remaining(remaining, baseline_secs, observed_secs)

  progress_log <- rbind(
    progress_log,
    data.frame(step = target_name, seconds = elapsed, eta_seconds = eta)
  )

  cat(sprintf(
    "Completed %s in %.1fs. ETA: %s\n",
    target_name,
    elapsed,
    format_eta(eta)
  ))
}

total_elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
cat(sprintf("Pipeline completed in %s\n", format_eta(total_elapsed)))

dir.create("artifacts", recursive = TRUE, showWarnings = FALSE)
write.csv(progress_log, "artifacts/targets_progress.csv", row.names = FALSE)
