source("analysis/sim/utils_sim.R")
source("analysis/sim/config.R")
source("analysis/sim/boundary_experiment.R")
source("analysis/sim/calibration_study.R")
source("analysis/sim/adversarial_benchmark.R")

compare_frames <- function(current, rerun, order_cols) {
  if (!all(order_cols %in% names(current)) || !all(order_cols %in% names(rerun))) {
    return(list(exact_match = FALSE, max_abs_diff = NA_real_))
  }
  current <- current[order(do.call(order, current[order_cols])), , drop = FALSE]
  rerun <- rerun[order(do.call(order, rerun[order_cols])), , drop = FALSE]
  exact_match <- isTRUE(all.equal(current, rerun, tolerance = 0, check.attributes = FALSE))
  num_cols <- names(current)[vapply(current, is.numeric, logical(1))]
  max_abs_diff <- NA_real_
  if (length(num_cols) > 0 && nrow(current) == nrow(rerun)) {
    max_abs_diff <- max(abs(as.matrix(current[num_cols]) - as.matrix(rerun[num_cols])), na.rm = TRUE)
  }
  list(exact_match = exact_match, max_abs_diff = max_abs_diff)
}

calc_boundary_summary <- function(results) {
  summary_metrics(results)
}

calc_calibration_table <- function(results) {
  results$miss <- !results$cover
  results$fail_flag <- results$weak_signal == "FAIL"
  score <- -results$weak_ratio
  p_miss_fail <- mean(results$miss[results$fail_flag], na.rm = TRUE)
  p_miss_pass <- mean(results$miss[!results$fail_flag], na.rm = TRUE)
  fpr <- mean(results$fail_flag & !results$miss, na.rm = TRUE)
  fnr <- mean(!results$fail_flag & results$miss, na.rm = TRUE)
  auc <- auc_mann_whitney(score, results$miss)
  data.frame(
    p_miss_fail = p_miss_fail,
    p_miss_pass = p_miss_pass,
    fpr = fpr,
    fnr = fnr,
    auc = auc
  )
}

calc_adversarial_summary <- function(results) {
  results$ci_len <- results$ci_upper - results$ci_lower
  aggregate(
    cbind(cover, ci_len) ~ n + beta + model + estimator,
    results,
    mean
  )
}

profile <- get_profile()

boundary_rerun <- do.call(run_boundary_experiment, profile$boundary)
boundary_current <- readRDS("artifacts/sim/boundary_results.rds")
boundary_check <- compare_frames(
  calc_boundary_summary(boundary_current),
  calc_boundary_summary(boundary_rerun),
  order_cols = c("estimator", "ci_type")
)

calibration_rerun <- do.call(run_calibration_study, profile$calibration)
calibration_current <- readRDS("artifacts/sim/calibration_results.rds")
calibration_check <- compare_frames(
  calc_calibration_table(calibration_current),
  calc_calibration_table(calibration_rerun),
  order_cols = names(calc_calibration_table(calibration_current))
)

adversarial_rerun <- do.call(run_adversarial_benchmark, profile$adversarial)
adversarial_current <- readRDS("artifacts/sim/adversarial_results.rds")
adversarial_check <- compare_frames(
  calc_adversarial_summary(adversarial_current),
  calc_adversarial_summary(adversarial_rerun),
  order_cols = c("n", "beta", "model", "estimator")
)

checks <- data.frame(
  artifact = c("boundary_summary", "calibration_summary", "adversarial_summary"),
  exact_match = c(boundary_check$exact_match, calibration_check$exact_match, adversarial_check$exact_match),
  max_abs_diff = c(boundary_check$max_abs_diff, calibration_check$max_abs_diff, adversarial_check$max_abs_diff),
  stringsAsFactors = FALSE
)

dir.create("artifacts", recursive = TRUE, showWarnings = FALSE)
write.csv(checks, "artifacts/reproducibility_check.csv", row.names = FALSE)

cat("Reproducibility check summary:\n")
print(checks)
