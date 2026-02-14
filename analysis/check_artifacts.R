required_files <- c(
  "artifacts/sim/boundary_results.rds",
  "artifacts/sim/boundary_summary.csv",
  "artifacts/sim/boundary_manifest.json",
  "artifacts/sim/calibration_results.rds",
  "artifacts/sim/calibration_manifest.json",
  "artifacts/sim/adversarial_results.rds",
  "artifacts/sim/adversarial_manifest.json",
  "artifacts/sim/diagnostics_operating_chars.csv",
  "artifacts/sim/summary_metrics.csv",
  "artifacts/figA_weak_signal.png",
  "artifacts/figB_boundary.png",
  "artifacts/figC_roc.png",
  "artifacts/figD_instability.png",
  "artifacts/figE_pareto.png",
  "artifacts/empirical/estimates.csv",
  "artifacts/empirical/diagnostics.csv",
  "artifacts/empirical/table_main.csv"
)

missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop(
    sprintf("Missing required artifacts:\n%s", paste(missing, collapse = "\n")),
    call. = FALSE
  )
}

cat("All required artifacts present.\n")
