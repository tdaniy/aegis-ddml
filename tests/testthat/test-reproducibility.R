test_that("aegis_fit is reproducible with fixed seed", {
  set.seed(11)
  n <- 120
  z <- rnorm(n)
  d <- 0.5 * z + rnorm(n)
  y <- 1.5 * d + 0.25 * z + rnorm(n)
  dat <- data.frame(Y = y, D = d, Z = z)

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
    target = target_lm(outcome = "Y", treatment = "D", controls = "Z"),
    strategy = strategy_crossfit(v = 4, repeats = 2, shuffle = TRUE),
    nuisance = nuis_spec(outcome_model = lm_learner, treatment_model = lm_learner),
    seed = 999
  )

  fit1 <- aegis_fit(spec, dat)
  fit2 <- aegis_fit(spec, dat)

  expect_identical(fit1$theta, fit2$theta)
  expect_identical(fit1$se, fit2$se)
  expect_identical(fit1$folds, fit2$folds)
  expect_identical(fit1$oof, fit2$oof)
  expect_length(fit1$artifacts$fold_schedules, 2)
})
