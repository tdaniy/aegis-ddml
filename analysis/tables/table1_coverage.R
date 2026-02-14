dat <- readRDS("artifacts/sim/boundary_results.rds")
tab <- aggregate(cover ~ n + beta + estimator + ci_type, dat, mean)
write.csv(tab, "artifacts/sim/table1_coverage.csv", row.names = FALSE)
