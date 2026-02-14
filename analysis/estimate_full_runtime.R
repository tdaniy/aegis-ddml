library(targets)
source("analysis/sim/config.R")

profile_current <- get_profile()
profile_full <- profiles$full

scale_boundary <- with(profile_full$boundary,
  (length(n_grid) * length(beta_grid) * reps * stress_reps)
) / with(profile_current$boundary,
  (length(n_grid) * length(beta_grid) * reps * stress_reps)
)

scale_calibration <- with(profile_full$calibration,
  (length(n_grid) * length(beta_grid) * reps)
) / with(profile_current$calibration,
  (length(n_grid) * length(beta_grid) * reps)
)

scale_adversarial <- with(profile_full$adversarial,
  (length(n_grid) * length(beta_grid) * length(model_grid) * reps)
) / with(profile_current$adversarial,
  (length(n_grid) * length(beta_grid) * length(model_grid) * reps)
)

scale <- c(
  boundary_results = scale_boundary,
  calibration_results = scale_calibration,
  adversarial_results = scale_adversarial,
  boundary_artifacts = 1,
  calibration_artifacts = 1,
  adversarial_artifacts = 1,
  boundary_summary = 1,
  calibration_summary = 1,
  adversarial_summary = 1
)

meta <- tar_meta(fields = c("name", "seconds"))
seconds <- stats::setNames(meta$seconds, meta$name)

estimate <- sum(seconds[names(scale)] * scale, na.rm = TRUE)
minutes <- estimate / 60

cat(sprintf("Estimated full runtime (no fast mode): %.1f minutes\n", minutes))

dir.create("artifacts", recursive = TRUE, showWarnings = FALSE)
write.csv(
  data.frame(
    profile = Sys.getenv("AEGIS_PROFILE", "default"),
    estimate_seconds = estimate,
    estimate_minutes = minutes
  ),
  "artifacts/targets_runtime_estimate.csv",
  row.names = FALSE
)
