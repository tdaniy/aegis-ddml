profiles <- list(
  fast = list(
    boundary = list(n_grid = c(200), beta_grid = c(0.0, 0.5), reps = 5, stress_reps = 5, seed_root = 123),
    calibration = list(n_grid = c(200), beta_grid = c(0.0, 0.5), reps = 20, seed_root = 321),
    adversarial = list(n_grid = c(200), beta_grid = c(0.0, 0.5), model_grid = c("lm"), reps = 10, seed_root = 456)
  ),
  default = list(
    boundary = list(n_grid = c(200, 500), beta_grid = c(0.0, 0.25, 0.5), reps = 50, stress_reps = 10, seed_root = 123),
    calibration = list(n_grid = c(200, 500), beta_grid = c(0.0, 0.25, 0.5), reps = 100, seed_root = 321),
    adversarial = list(n_grid = c(200, 500), beta_grid = c(0.0, 0.5), model_grid = c("lm", "glm"), reps = 25, seed_root = 456)
  ),
  full = list(
    boundary = list(n_grid = c(200, 500, 1000), beta_grid = c(0.0, 0.25, 0.5, 0.75), reps = 100, stress_reps = 20, seed_root = 123),
    calibration = list(n_grid = c(200, 500, 1000), beta_grid = c(0.0, 0.25, 0.5, 0.75), reps = 200, seed_root = 321),
    adversarial = list(n_grid = c(200, 500), beta_grid = c(0.0, 0.5, 0.75, 1.0), model_grid = c("lm", "glm"), reps = 50, seed_root = 456)
  )
)

get_profile <- function(profile = Sys.getenv("AEGIS_PROFILE", "default")) {
  if (Sys.getenv("AEGIS_FAST") == "1") {
    profile <- "fast"
  }
  if (!profile %in% names(profiles)) {
    stop(sprintf("Unknown AEGIS_PROFILE: %s", profile), call. = FALSE)
  }
  profiles[[profile]]
}
