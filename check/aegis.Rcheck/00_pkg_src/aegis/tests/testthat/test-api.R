test_that("constructors return expected classes", {
  learner_y <- learner_base(name = "lm")
  learner_d <- learner_base(name = "glm")
  nuisance <- nuis_spec(outcome_model = learner_y, treatment_model = learner_d)
  target <- target_lm(outcome = "Y", treatment = "D", controls = c("X1", "X2"))
  strategy <- strategy_crossfit(v = 5L, repeats = 1L, shuffle = TRUE)
  spec <- aegis_spec(
    target = target,
    strategy = strategy,
    nuisance = nuisance,
    seed = 123
  )

  expect_s3_class(learner_y, "learner_base")
  expect_s3_class(nuisance, "nuis_spec")
  expect_s3_class(target, "aegis_target")
  expect_s3_class(strategy, "strategy_crossfit")
  expect_s3_class(spec, "aegis_spec")
})

test_that("aegis_fit returns placeholder object with required fields", {
  learner_y <- learner_base(
    name = "lm",
    fit_fun = function(x, y) {
      stats::lm(y ~ ., data = data.frame(y = y, x))
    },
    predict_fun = function(fit, newdata) {
      stats::predict(fit, newdata = data.frame(newdata))
    }
  )
  learner_d <- learner_y
  nuisance <- nuis_spec(outcome_model = learner_y, treatment_model = learner_d)
  target <- target_lm(outcome = "Y", treatment = "D", controls = c("X1"))
  strategy <- strategy_crossfit(v = 3L, repeats = 1L, shuffle = TRUE)
  spec <- aegis_spec(target = target, strategy = strategy, nuisance = nuisance)

  dat <- data.frame(
    Y = rnorm(12),
    D = rnorm(12),
    X1 = rnorm(12)
  )

  fit <- aegis_fit(spec = spec, data = dat)

  expect_s3_class(fit, "aegis_fit")
  expect_named(
    fit,
    c("theta", "se", "vcov", "folds", "oof", "diagnostics", "artifacts", "n", "call")
  )
  expect_true(is.matrix(fit$vcov))
  expect_identical(dim(fit$vcov), c(1L, 1L))
  expect_true(is.list(fit$diagnostics))
  expect_true(is.list(fit$artifacts))
  expect_true(is.numeric(fit$folds))
  expect_true(is.list(fit$oof))
  expect_true(is.list(fit$oof$primary))
  expect_true(is.list(fit$oof$by_repeat))

  ci <- confint(fit)
  expect_true(is.matrix(ci))
  expect_identical(dim(ci), c(1L, 2L))

  smry <- summary(fit)
  expect_s3_class(smry, "summary.aegis_fit")
})
