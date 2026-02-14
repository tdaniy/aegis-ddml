dat <- readRDS("artifacts/empirical/wage_data.rds")

lm_learner <- aegis::learner_base(
  name = "lm",
  fit_fun = function(x, y) {
    stats::lm(y ~ ., data = data.frame(y = y, x))
  },
  predict_fun = function(fit, newdata) {
    stats::predict(fit, newdata = data.frame(newdata))
  }
)

spec <- aegis::aegis_spec(
  target = aegis::target_lm("Y", "D", c("Z1", "Z2")),
  strategy = aegis::strategy_crossfit(v = 5, repeats = 2, shuffle = TRUE),
  nuisance = aegis::nuis_spec(lm_learner, lm_learner),
  seed = 42
)

fit <- aegis::aegis_fit(spec, dat)

out <- data.frame(
  theta = fit$theta,
  se = fit$se
)
write.csv(out, "artifacts/empirical/estimates.csv", row.names = FALSE)
diag <- data.frame(
  weak_signal = fit$diagnostics$weak_signal$status,
  leakage = fit$diagnostics$leakage$leakage
)
write.csv(diag, "artifacts/empirical/diagnostics.csv", row.names = FALSE)
