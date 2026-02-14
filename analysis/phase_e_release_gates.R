read_boundary <- function(path = "artifacts/sim/boundary_results.rds") {
  if (!file.exists(path)) stop("Missing boundary_results.rds", call. = FALSE)
  readRDS(path)
}

read_calibration <- function(path = "artifacts/sim/diagnostics_operating_chars.csv") {
  if (!file.exists(path)) stop("Missing diagnostics_operating_chars.csv", call. = FALSE)
  read.csv(path)
}

read_adversarial <- function(path = "artifacts/sim/adversarial_results.rds") {
  if (!file.exists(path)) stop("Missing adversarial_results.rds", call. = FALSE)
  readRDS(path)
}

gate_row <- function(category, metric, threshold, value, status, notes = "") {
  data.frame(
    category = category,
    metric = metric,
    threshold = threshold,
    value = value,
    status = status,
    notes = notes,
    stringsAsFactors = FALSE
  )
}

boundary <- read_boundary()
calibration <- read_calibration()
adversarial <- read_adversarial()

rows <- list()

# Coverage validity at n >= 500 for AEGIS Wald.
cov_dat <- subset(boundary, estimator == "AEGIS" & ci_type == "wald" & n >= 500)
cov_val <- if (nrow(cov_dat) > 0) mean(cov_dat$cover) else NA_real_
cov_status <- if (is.na(cov_val)) "NA" else if (cov_val >= 0.93 && cov_val <= 0.97) "PASS" else "FAIL"
rows[[length(rows) + 1]] <- gate_row(
  "Coverage validity",
  "AEGIS 95% coverage at n >= 500",
  "0.93–0.97",
  cov_val,
  cov_status
)

# Bias control vs naive.
agg_bias <- aggregate(theta_hat ~ n + beta + estimator + ci_type, boundary, mean)
agg_bias$bias <- agg_bias$theta_hat - 1
ae <- subset(agg_bias, estimator == "AEGIS" & ci_type == "wald")
nv <- subset(agg_bias, estimator == "naive" & ci_type == "wald")
bias_join <- merge(ae, nv, by = c("n", "beta"), suffixes = c("_ae", "_naive"))
if (nrow(bias_join) > 0) {
  bias_share <- mean(abs(bias_join$bias_ae) <= abs(bias_join$bias_naive))
  bias_status <- if (bias_share >= 0.8) "PASS" else "FAIL"
} else {
  bias_share <- NA_real_
  bias_status <- "NA"
}
rows[[length(rows) + 1]] <- gate_row(
  "Bias control",
  "AEGIS abs bias <= naive",
  ">= 0.80 share of cells",
  bias_share,
  bias_status
)

# Efficiency vs sample-split (CI length).
agg_len <- aggregate(ci_upper - ci_lower ~ n + beta + estimator + ci_type, boundary, mean)
names(agg_len)[names(agg_len) == "ci_upper - ci_lower"] <- "ci_len"
ae_len <- subset(agg_len, estimator == "AEGIS" & ci_type == "wald")
ss_len <- subset(agg_len, estimator == "sample_split" & ci_type == "wald")
len_join <- merge(ae_len, ss_len, by = c("n", "beta"), suffixes = c("_ae", "_ss"))
if (nrow(len_join) > 0) {
  eff_share <- mean(len_join$ci_len_ae <= 0.9 * len_join$ci_len_ss)
  eff_status <- if (eff_share >= 0.7) "PASS" else "FAIL"
} else {
  eff_share <- NA_real_
  eff_status <- "NA"
}
rows[[length(rows) + 1]] <- gate_row(
  "Efficiency",
  "AEGIS CI length <= 0.9 * sample-split",
  ">= 0.70 share of cells",
  eff_share,
  eff_status
)

# Stress-CI bound check: compare miss rate to estimated bound.
stress <- subset(boundary, estimator == "AEGIS" & ci_type == "stress")
if (nrow(stress) > 0) {
  stress_cell <- aggregate(cover ~ n + beta, stress, mean)
  miss_rate <- 1 - stress_cell$cover
  stress_reps_vals <- unique(na.omit(stress$stress_reps))
  stress_reps_val <- if (length(stress_reps_vals) >= 1) stress_reps_vals[1] else NA_real_
  if (is.finite(stress_reps_val) && stress_reps_val > 0) {
    bound <- 0.05 + 1.96 * sqrt(0.95 * 0.05 / stress_reps_val)
    bound_hold <- mean(miss_rate <= bound, na.rm = TRUE)
    bound_status <- if (bound_hold >= 0.9) "PASS" else "FAIL"
    bound_notes <- sprintf("bound=%.3f (B=%d)", bound, stress_reps_val)
  } else {
    bound_hold <- NA_real_
    bound_status <- "NA"
    bound_notes <- "Stress reps unavailable"
  }
} else {
  bound_hold <- NA_real_
  bound_status <- "NA"
  bound_notes <- "Stress CI results unavailable"
}
rows[[length(rows) + 1]] <- gate_row(
  "Stress-CI bound check",
  "Stress-CI miss rate vs bound",
  ">= 0.90 bound hold",
  bound_hold,
  bound_status,
  bound_notes
)

# Boundary sharpness (psi = 0.5 - beta for parametric nuisances).
wald <- subset(boundary, estimator == "AEGIS" & ci_type == "wald")
if (nrow(wald) > 0) {
  wald_cell <- aggregate(cover ~ n + beta, wald, mean)
  wald_cell$psi <- 0.5 - wald_cell$beta
  hi_cov <- stats::median(wald_cell$cover[wald_cell$psi > 0.10], na.rm = TRUE)
  lo_cov <- stats::median(wald_cell$cover[wald_cell$psi < -0.10], na.rm = TRUE)
  if (is.finite(hi_cov) && is.finite(lo_cov)) {
    bound_status <- if (hi_cov >= 0.93 && lo_cov <= 0.90) "PASS" else "FAIL"
    bound_notes <- sprintf("median_low=%.3f; psi=0.5-beta", lo_cov)
  } else {
    bound_status <- "NA"
    bound_notes <- "Insufficient psi coverage"
  }
} else {
  hi_cov <- NA_real_
  lo_cov <- NA_real_
  bound_status <- "NA"
  bound_notes <- "Wald results unavailable"
}
rows[[length(rows) + 1]] <- gate_row(
  "Boundary sharpness",
  "Coverage separation across psi",
  ">= 0.93 / <= 0.90",
  hi_cov,
  bound_status,
  bound_notes
)

# Diagnostic calibration (P(miss|FAIL) and AUC).
pmf <- if ("p_miss_fail" %in% names(calibration)) calibration$p_miss_fail[1] else NA_real_
auc <- if ("auc" %in% names(calibration)) calibration$auc[1] else NA_real_
if (is.na(pmf) || is.na(auc)) {
  diag_status <- "NA"
} else if (pmf >= 0.7 && auc >= 0.7) {
  diag_status <- "PASS"
} else {
  diag_status <- "FAIL"
}
rows[[length(rows) + 1]] <- gate_row(
  "Diagnostic calibration",
  "P(miss|FAIL)",
  ">= 0.70",
  pmf,
  diag_status,
  if (is.na(auc)) "AUC unavailable" else sprintf("AUC=%.3f", auc)
)

# Adversarial audit vs DoubleML.
adv_agg <- adversarial
adv_agg$ci_len <- adv_agg$ci_upper - adv_agg$ci_lower
adv_cell <- aggregate(
  cbind(cover, ci_len) ~ n + beta + model + estimator,
  adv_agg,
  mean
)
ae_adv <- subset(adv_cell, estimator == "AEGIS")
dm_adv <- subset(adv_cell, estimator == "doubleml")
adv_join <- merge(ae_adv, dm_adv, by = c("n", "beta", "model"), suffixes = c("_ae", "_dm"))
if (nrow(adv_join) > 0) {
  weak_mask <- adv_join$beta >= 0.5
  if (any(weak_mask)) {
    cov_ok <- adv_join$cover_ae >= adv_join$cover_dm
    len_ratio <- adv_join$ci_len_ae / adv_join$ci_len_dm
    len_ok <- len_ratio <= 1.5
    share_ok <- mean(cov_ok & len_ok & weak_mask)
    adv_status <- if (share_ok >= 0.7) "PASS" else "FAIL"
    adv_notes <- sprintf("weak_cells=%d", sum(weak_mask))
  } else {
    share_ok <- NA_real_
    adv_status <- "NA"
    adv_notes <- "No weak-signal cells"
  }
} else {
  share_ok <- NA_real_
  adv_status <- "NA"
  adv_notes <- "DoubleML results unavailable"
}
rows[[length(rows) + 1]] <- gate_row(
  "Adversarial audit",
  "AEGIS vs DoubleML",
  ">= 70% weak-signal cells",
  share_ok,
  adv_status,
  adv_notes
)

# Convergence (GLM): proxy by finite se if GLM rows exist.
glm_rows <- subset(adversarial, model == "glm")
if (nrow(glm_rows) > 0) {
  conv_rate <- mean(is.finite(glm_rows$se))
  conv_status <- if (conv_rate >= 0.99) "PASS" else "FAIL"
} else {
  conv_rate <- NA_real_
  conv_status <- "NA"
}
rows[[length(rows) + 1]] <- gate_row(
  "Convergence",
  "GLM finite SE rate",
  ">= 0.99",
  conv_rate,
  conv_status
)

# Leakage: read from boundary outputs.
leakage_val <- NA_real_
leakage_status <- "NA"
leakage_notes <- "Leakage flag not available"
if ("leakage_flag" %in% names(boundary)) {
  leakage_val <- mean(boundary$leakage_flag[boundary$estimator == "AEGIS"], na.rm = TRUE)
  if (is.finite(leakage_val)) {
    leakage_status <- if (leakage_val == 0) "PASS" else "FAIL"
    leakage_notes <- ""
  }
}
rows[[length(rows) + 1]] <- gate_row(
  "Leakage",
  "In-fold scoring violations",
  "0",
  leakage_val,
  leakage_status,
  leakage_notes
)

# Reproducibility: compare reruns.
repro_path <- "artifacts/reproducibility_check.csv"
if (file.exists(repro_path)) {
  repro <- read.csv(repro_path)
  exact_match <- all(repro$exact_match)
  repro_status <- if (exact_match) "PASS" else "FAIL"
  repro_val <- as.numeric(exact_match)
  repro_notes <- if (exact_match) "" else paste(repro$artifact[!repro$exact_match], collapse = ", ")
} else {
  repro_val <- NA_real_
  repro_status <- "NA"
  repro_notes <- "Rerun comparison not executed"
}
rows[[length(rows) + 1]] <- gate_row(
  "Reproducibility",
  "Exact match on rerun",
  "Exact",
  repro_val,
  repro_status,
  repro_notes
)

# Tests: 3 consecutive runs.
test_path <- "artifacts/test_repeat.csv"
if (file.exists(test_path)) {
  test_runs <- read.csv(test_path)
  pass_rate <- mean(test_runs$pass, na.rm = TRUE)
  test_status <- if (nrow(test_runs) >= 3 && pass_rate == 1) "PASS" else "FAIL"
  test_notes <- if (nrow(test_runs) >= 3) "" else "Fewer than 3 runs"
} else {
  pass_rate <- NA_real_
  test_status <- "NA"
  test_notes <- "Test repeats not executed"
}
rows[[length(rows) + 1]] <- gate_row(
  "Tests",
  "3 consecutive passes",
  "100%",
  pass_rate,
  test_status,
  test_notes
)

gate_table <- do.call(rbind, rows)

dir.create("artifacts", recursive = TRUE, showWarnings = FALSE)
write.csv(gate_table, "artifacts/release_gates.csv", row.names = FALSE)

cat("Release gate summary:\n")
print(gate_table)
