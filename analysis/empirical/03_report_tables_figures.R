est <- read.csv("artifacts/empirical/estimates.csv")
diag <- read.csv("artifacts/empirical/diagnostics.csv")

tab <- cbind(est, diag)
write.csv(tab, "artifacts/empirical/table_main.csv", row.names = FALSE)
