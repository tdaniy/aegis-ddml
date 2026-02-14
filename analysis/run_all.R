dir.create("artifacts/sim", recursive = TRUE, showWarnings = FALSE)
dir.create("artifacts/empirical", recursive = TRUE, showWarnings = FALSE)
source("analysis/sim/boundary_experiment.R")
source("analysis/sim/calibration_study.R")
source("analysis/sim/adversarial_benchmark.R")
source("analysis/sim/config.R")

profile <- get_profile()
boundary_args <- profile$boundary
calibration_args <- profile$calibration
adversarial_args <- profile$adversarial

out_boundary <- do.call(run_boundary_experiment, boundary_args)
saveRDS(out_boundary, "artifacts/sim/boundary_results.rds")
write.csv(out_boundary, "artifacts/sim/boundary_summary.csv", row.names = FALSE)
write.csv(summary_metrics(out_boundary), "artifacts/sim/summary_metrics.csv", row.names = FALSE)
write_manifest("artifacts/sim/boundary_manifest.json", grid = boundary_args, seed_root = boundary_args$seed_root)

out_cal <- do.call(run_calibration_study, calibration_args)
saveRDS(out_cal, "artifacts/sim/calibration_results.rds")
out_cal$miss <- !out_cal$cover
out_cal$fail_flag <- out_cal$weak_signal == "FAIL"
p_miss_fail <- mean(out_cal$miss[out_cal$fail_flag], na.rm = TRUE)
p_miss_pass <- mean(out_cal$miss[!out_cal$fail_flag], na.rm = TRUE)
fpr <- mean(out_cal$fail_flag & !out_cal$miss, na.rm = TRUE)
fnr <- mean(!out_cal$fail_flag & out_cal$miss, na.rm = TRUE)
diag_table <- data.frame(p_miss_fail = p_miss_fail, p_miss_pass = p_miss_pass, fpr = fpr, fnr = fnr)
write.csv(diag_table, "artifacts/sim/diagnostics_operating_chars.csv", row.names = FALSE)
write_manifest("artifacts/sim/calibration_manifest.json", grid = calibration_args, seed_root = calibration_args$seed_root)

out_adv <- do.call(run_adversarial_benchmark, adversarial_args)
saveRDS(out_adv, "artifacts/sim/adversarial_results.rds")
write.csv(out_adv, "artifacts/sim/adversarial_audit_summary.csv", row.names = FALSE)
write_manifest("artifacts/sim/adversarial_manifest.json", grid = adversarial_args, seed_root = adversarial_args$seed_root)
source("analysis/figures/figA_weak_signal.R")
source("analysis/figures/figB_boundary.R")
source("analysis/figures/figC_roc.R")
source("analysis/figures/figD_instability.R")
source("analysis/figures/figE_pareto.R")
source("analysis/tables/table1_coverage.R")
source("analysis/tables/table2_diagnostics.R")
source("analysis/tables/table3_reproducibility.R")
source("analysis/empirical/01_prepare_wage.R")
source("analysis/empirical/02_fit_models.R")
source("analysis/empirical/03_report_tables_figures.R")
