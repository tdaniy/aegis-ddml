test_that("LM orthogonal inference works on toy PLR data", {
  set.seed(123)
  n <- 400
  z1 <- rnorm(n)
  z2 <- rnorm(n)
  m0 <- z1 - 0.5 * z2
  g0 <- 0.25 * z1 + 0.5 * z2
  d <- m0 + rnorm(n)
  theta0 <- 2
  y <- theta0 * d + g0 + rnorm(n)

  dat <- data.frame(Y = y, D = d, Z1 = z1, Z2 = z2)

  lm_learner <- learner_base(
    name = "lm",
    fit_fun = function(x, y) {
      stats::lm(y ~ ., data = data.frame(y = y, x))
    },
    predict_fun = function(fit, newdata) {
      stats::predict(fit, newdata = data.frame(newdata))
    }
  )

  spec <- aegis_spec(
    target = target_lm(outcome = "Y", treatment = "D", controls = c("Z1", "Z2")),
    strategy = strategy_crossfit(v = 5, repeats = 1, shuffle = TRUE),
    nuisance = nuis_spec(outcome_model = lm_learner, treatment_model = lm_learner),
    seed = 777
  )

  fit <- aegis_fit(spec, dat)
  expect_true(is.finite(fit$theta))
  expect_true(is.finite(fit$se))
  expect_lt(abs(fit$theta - theta0), 0.5)
  expect_true(all(is.finite(confint(fit))))
  expect_false(fit$diagnostics$leakage$leakage)
})
