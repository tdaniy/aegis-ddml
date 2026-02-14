test_that("crossfit_predict uses strict out-of-fold training", {
  set.seed(123)
  n <- 12
  x <- data.frame(x1 = rnorm(n))
  y <- seq_len(n)

  learner <- learner_base(
    name = "mean-learner",
    fit_fun = function(x, y) {
      mean(y)
    },
    predict_fun = function(fit, newdata) {
      rep(fit, nrow(newdata))
    }
  )

  folds <- make_folds(n = n, v = 3, seed = 42, shuffle = TRUE)
  cf <- crossfit_predict(learner, x = x, y = y, folds = folds)

  for (k in sort(unique(folds))) {
    test_idx <- folds == k
    train_idx <- !test_idx
    expected <- mean(y[train_idx])
    expect_equal(unique(cf$pred[test_idx]), expected, tolerance = 1e-12)
  }
})
