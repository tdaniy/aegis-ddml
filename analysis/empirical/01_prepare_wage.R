dir.create("artifacts/empirical", recursive = TRUE, showWarnings = FALSE)
set.seed(1)
dat <- data.frame(
  Y = rnorm(3000),
  D = rbinom(3000, 1, 0.4),
  Z1 = rnorm(3000),
  Z2 = rnorm(3000)
)
saveRDS(dat, "artifacts/empirical/wage_data.rds")
