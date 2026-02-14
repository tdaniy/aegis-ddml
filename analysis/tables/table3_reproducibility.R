dat <- readRDS("artifacts/sim/boundary_results.rds")
dat <- subset(dat, estimator == "AEGIS" & ci_type == "wald")
tab <- aggregate(theta_hat ~ n + beta, dat, stats::sd)
names(tab)[3] <- "theta_hat_sd"
write.csv(tab, "artifacts/sim/table3_reproducibility.csv", row.names = FALSE)
