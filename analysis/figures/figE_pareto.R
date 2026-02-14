dat <- readRDS("artifacts/sim/boundary_results.rds")
dat <- subset(dat, estimator == "AEGIS" & ci_type == "wald")
png("artifacts/figE_pareto.png", width = 800, height = 600)
plot(dat$ci_upper - dat$ci_lower, abs(dat$theta_hat - dat$theta0),
     pch = 16, xlab = "CI length", ylab = "Absolute error", main = "Coverage vs CI length")
dev.off()
