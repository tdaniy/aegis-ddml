library(targets)

source("analysis/sim/boundary_experiment.R")
source("analysis/sim/calibration_study.R")
source("analysis/sim/adversarial_benchmark.R")
source("analysis/sim/config.R")

tar_option_set(packages = c("aegis"))

profile <- get_profile()
boundary_args <- profile$boundary
calibration_args <- profile$calibration
adversarial_args <- profile$adversarial

list(
  tar_target(boundary_results, do.call(run_boundary_experiment, boundary_args)),
  tar_target(calibration_results, do.call(run_calibration_study, calibration_args)),
  tar_target(adversarial_results, do.call(run_adversarial_benchmark, adversarial_args)),
  tar_target(boundary_artifacts, {
    dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
    saveRDS(boundary_results, "artifacts/sim/boundary_results.rds")
    write.csv(boundary_results, "artifacts/sim/boundary_summary.csv", row.names = FALSE)
    write.csv(summary_metrics(boundary_results), "artifacts/sim/summary_metrics.csv", row.names = FALSE)
    write_manifest(
      "artifacts/sim/boundary_manifest.json",
      grid = boundary_args,
      seed_root = boundary_args$seed_root
    )
    boundary_results
  }),
  tar_target(calibration_artifacts, {
    dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
    res <- calibration_results
    saveRDS(res, "artifacts/sim/calibration_results.rds")
    res$miss <- !res$cover
    res$fail_flag <- res$weak_signal == "FAIL"
    p_miss_fail <- mean(res$miss[res$fail_flag], na.rm = TRUE)
    p_miss_pass <- mean(res$miss[!res$fail_flag], na.rm = TRUE)
    fpr <- mean(res$fail_flag & !res$miss, na.rm = TRUE)
    fnr <- mean(!res$fail_flag & res$miss, na.rm = TRUE)
    diag_table <- data.frame(
      p_miss_fail = p_miss_fail,
      p_miss_pass = p_miss_pass,
      fpr = fpr,
      fnr = fnr
    )
    write.csv(diag_table, "artifacts/sim/diagnostics_operating_chars.csv", row.names = FALSE)
    write_manifest(
      "artifacts/sim/calibration_manifest.json",
      grid = calibration_args,
      seed_root = calibration_args$seed_root
    )
    res
  }),
  tar_target(adversarial_artifacts, {
    dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
    saveRDS(adversarial_results, "artifacts/sim/adversarial_results.rds")
    write.csv(adversarial_results, "artifacts/sim/adversarial_audit_summary.csv", row.names = FALSE)
    write_manifest(
      "artifacts/sim/adversarial_manifest.json",
      grid = adversarial_args,
      seed_root = adversarial_args$seed_root
    )
    adversarial_results
  }),
  tar_target(boundary_summary, {
    write.csv(boundary_results, "artifacts/sim/boundary_summary.csv", row.names = FALSE)
    boundary_results
  }),
  tar_target(calibration_summary, {
    write.csv(calibration_results, "artifacts/sim/calibration_summary.csv", row.names = FALSE)
    calibration_results
  }),
  tar_target(adversarial_summary, {
    write.csv(adversarial_results, "artifacts/sim/adversarial_audit_summary.csv", row.names = FALSE)
    adversarial_results
  })
)
