test_that("GLM orthogonal inference works on toy logistic data", {
  set.seed(321)
  n <- 500
  z1 <- rnorm(n)
  z2 <- rnorm(n)
  m0 <- 0.3 * z1 - 0.2 * z2
  d <- m0 + rnorm(n)
  theta0 <- 1
  g0 <- -0.2 + 0.4 * z1 - 0.1 * z2
  p <- stats::plogis(theta0 * d + g0)
  y <- stats::rbinom(n, size = 1, prob = p)

  dat <- data.frame(Y = y, D = d, Z1 = z1, Z2 = z2)

  glm_learner <- learner_base(
    name = "glm-binomial",
    fit_fun = function(x, y) {
      stats::glm(y ~ ., data = data.frame(y = y, x), family = stats::binomial())
    },
    predict_fun = function(fit, newdata) {
      stats::predict(fit, newdata = data.frame(newdata), type = "response")
    }
  )

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
    target = target_glm(outcome = "Y", treatment = "D", controls = c("Z1", "Z2")),
    strategy = strategy_crossfit(v = 5, repeats = 1, shuffle = TRUE),
    nuisance = nuis_spec(outcome_model = glm_learner, treatment_model = lm_learner),
    seed = 202
  )

  fit <- aegis_fit(spec, dat)
  expect_true(is.finite(fit$theta))
  expect_true(is.finite(fit$se))
  expect_gt(fit$theta, 0)
  expect_true(all(is.finite(confint(fit))))
  expect_false(fit$diagnostics$leakage$leakage)
})
