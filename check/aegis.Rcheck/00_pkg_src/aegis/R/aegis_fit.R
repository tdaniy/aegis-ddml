#' Fit an AEGIS Model
#'
#' @param spec A specification object created by [aegis_spec()].
#' @param data A `data.frame` containing model inputs.
#'
#' @return An object of class `aegis_fit`.
#' @export
aegis_fit <- function(spec, data) {
  if (!inherits(spec, "aegis_spec")) {
    stop("`spec` must inherit from class 'aegis_spec'.", call. = FALSE)
  }

  if (!is.data.frame(data)) {
    stop("`data` must be a data.frame.", call. = FALSE)
  }

  target <- spec$target
  strategy <- spec$strategy
  nuisance <- spec$nuisance

  n <- nrow(data)
  if (!is.null(spec$seed)) {
    set.seed(spec$seed)
  }

  fold_schedules <- vector("list", strategy$repeats)
  repeat_results <- vector("list", strategy$repeats)
  oof_by_repeat <- vector("list", strategy$repeats)

  y <- data[[target$outcome]]
  d <- data[[target$treatment]]

  for (r in seq_len(strategy$repeats)) {
    seed_r <- if (is.null(spec$seed)) NULL else spec$seed + r - 1L
    folds_r <- make_folds(
      n = n,
      v = strategy$v,
      seed = seed_r,
      shuffle = strategy$shuffle
    )
    fold_schedules[[r]] <- folds_r

    oof_rY <- fit_nuisance_rY(data = data, target = target, nuisance = nuisance, folds = folds_r)
    oof_rM <- fit_nuisance_rM(data = data, target = target, nuisance = nuisance, folds = folds_r)
    oof_by_repeat[[r]] <- list(rY = oof_rY$pred, rM = oof_rM$pred)

    if (inherits(target, "aegis_target_lm")) {
      inf <- inference_lm(y = y, d = d, g_hat = oof_rY$pred, m_hat = oof_rM$pred)
    } else if (inherits(target, "aegis_target_glm")) {
      start_theta <- .glm_start_theta(data, target)
      inf <- inference_glm(
        y = y,
        d = d,
        g_hat = oof_rY$pred,
        m_hat = oof_rM$pred,
        family = target$family,
        start_theta = start_theta
      )
    } else {
      stop("Unsupported target type.", call. = FALSE)
    }

    repeat_results[[r]] <- list(
      inf = inf,
      diagnostics = list(
        leakage = diagnostics_leakage(
          folds_r,
          oof_pred = list(rY = oof_rY$pred, rM = oof_rM$pred)
        ),
        weak_signal = diagnostics_weak_signal(inf$d_tilde, d),
        influence = diagnostics_influence(inf$score)
      )
    )
  }

  folds <- fold_schedules[[1]]
  primary_oof <- oof_by_repeat[[1]]

  thetas <- vapply(repeat_results, function(x) x$inf$theta, numeric(1))
  vcovs <- vapply(repeat_results, function(x) x$inf$vcov[1, 1], numeric(1))
  theta_hat <- mean(thetas)
  between_var <- if (length(thetas) > 1L) stats::var(thetas) else 0
  if (length(thetas) > 1L) {
    vcov_hat <- mean(vcovs) + (1 + 1 / (length(thetas) - 1)) * between_var
  } else {
    vcov_hat <- mean(vcovs)
  }
  se_hat <- sqrt(vcov_hat)

  leakage_any <- any(vapply(repeat_results, function(x) x$diagnostics$leakage$leakage, logical(1)))
  weak_statuses <- vapply(repeat_results, function(x) x$diagnostics$weak_signal$status, character(1))
  weak_status <- if ("FAIL" %in% weak_statuses) {
    "FAIL"
  } else if ("WARN" %in% weak_statuses) {
    "WARN"
  } else {
    "PASS"
  }

  influence_summary <- .aggregate_influence(repeat_results)

  diagnostics <- list(
    leakage = list(
      leakage = leakage_any,
      per_repeat = lapply(repeat_results, function(x) x$diagnostics$leakage)
    ),
    weak_signal = list(
      status = weak_status,
      per_repeat = lapply(repeat_results, function(x) x$diagnostics$weak_signal)
    ),
    influence = influence_summary
  )

  artifacts <- list(
    seed = spec$seed,
    session_info = suppressWarnings(utils::sessionInfo()),
    learners = list(
      outcome = nuisance$outcome_model$name,
      treatment = nuisance$treatment_model$name
    ),
    fold_schedules = fold_schedules
  )

  structure(
    list(
      theta = theta_hat,
      se = se_hat,
      vcov = matrix(vcov_hat, nrow = 1L, ncol = 1L, dimnames = list("theta", "theta")),
      folds = folds,
      oof = list(primary = primary_oof, by_repeat = oof_by_repeat),
      diagnostics = diagnostics,
      artifacts = artifacts,
      n = n,
      call = match.call()
    ),
    class = "aegis_fit"
  )
}

.aggregate_influence <- function(repeat_results) {
  metrics <- lapply(repeat_results, function(x) x$diagnostics$influence)
  metric_names <- names(metrics[[1]])
  out <- list()
  for (name in metric_names) {
    vals <- vapply(metrics, function(m) m[[name]], numeric(1))
    out[[name]] <- mean(vals, na.rm = TRUE)
  }
  out$per_repeat <- metrics
  out
}

.glm_start_theta <- function(data, target) {
  if (!inherits(target, "aegis_target_glm")) {
    return(NULL)
  }
  rhs <- c(target$treatment, target$controls)
  rhs <- rhs[rhs %in% names(data)]
  if (length(rhs) == 0L) {
    return(NULL)
  }
  formula <- stats::as.formula(
    paste(target$outcome, "~", paste(rhs, collapse = " + "))
  )
  start <- suppressWarnings(
    try(stats::glm(formula, data = data, family = target$family), silent = TRUE)
  )
  if (inherits(start, "try-error")) {
    return(NULL)
  }
  coef_start <- stats::coef(start)
  if (!target$treatment %in% names(coef_start)) {
    return(NULL)
  }
  coef_start[[target$treatment]]
}
