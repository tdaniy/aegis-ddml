# Phase E+ Research Plan

This document defines a focused research cycle to validate (or refute) the scientific reliability claims. It is separate from Phase E implementation and assumes the current software-first pipeline is stable.

## Objectives

- Validate diagnostic risk stratification under theory-aligned regimes.
- Identify minimal configuration that passes core scientific gates.
- Produce clear evidence for acceptance or retraction of the theoretical claims.

## Hypotheses (narrow, testable)

H1. Diagnostic risk stratification achieves $P(\text{miss}\mid \text{FAIL}) \ge 0.70$ and AUC $\ge 0.70$ in weak-signal regimes when diagnostics use theory-aligned features.

H2. Stress-CI bound holds in at least 90% of primary grid cells under the recommended stress-quantile setting.

H3. Coverage and bias gates pass under a minimal, theory-aligned DGP subset.

## Experimental Design

### E+1 Diagnostics from first principles (mandatory)

**Purpose:** Build diagnostic features linked to theoretical remainder terms.

**Implementation tasks:**
- Add feature extraction:
  - Fold-seed variance of $\hat{\theta}$ across repeats.
  - Estimated signal strength proxy $\hat{\kappa}$ (variance of residualized treatment).
  - Influence tail summaries (p95/p99 of standardized score).
  - Jacobian conditioning (if available).
- Train logistic classifier on calibration split using these features.
- Calibrate FAIL threshold using Youden’s J with a minimum FAIL prevalence $\pi_{\min}$.

**Code changes:**
- `analysis/sim/calibration_study.R`: compute and store new features; classifier trained on feature set.
- `_targets.R`: mirror feature-based classifier when writing artifacts.
- `R/diagnostics.R`: add helper for signal strength proxy and influence tails if missing.

**Expected artifacts:**
- `artifacts/sim/diagnostics_operating_chars.csv` with AUC, threshold, pi_min, and feature list.
- `artifacts/sim/calibration_results.rds` with new feature columns.

**Completion criteria (verifiable):**
- `artifacts/sim/calibration_results.rds` contains columns: `weak_ratio`, `instab`, `infl`, `se`, `n`, `beta`.
- `artifacts/sim/diagnostics_operating_chars.csv` contains columns: `auc`, `fail_threshold`, `pi_min`.
- AUC is computed (not `NA`) on the calibration evaluation split.
- Thresholds: AUC $\ge 0.70$ and $P(\text{miss}\mid \text{FAIL}) \ge 0.70$ on the evaluation split, with FAIL prevalence $\in [0.20, 0.50]$.

### E+2 Theory-aligned DGP subset (mandatory)

**Purpose:** Test diagnostics where the theory’s assumptions are most plausible.

**Implementation tasks:**
- Add a restricted DGP grid: moderate signal, controlled nuisance rates, homoskedastic noise.
- Recompute coverage, bias, efficiency, stress-bound only on this subset.

**Code changes:**
- `analysis/sim/config.R`: add a new profile `theory` or a flag to subset grid.
- `analysis/sim/boundary_experiment.R`: honor the new subset grid.
- `analysis/phase_e_release_gates.R`: add “theory-subset” rows or a separate gate table.

**Expected artifacts:**
- `artifacts/sim/theory_subset_results.rds`
- `artifacts/release_gates_theory.csv`

**Completion criteria (verifiable):**
- `artifacts/sim/theory_subset_results.rds` exists and has non-zero rows.
- `artifacts/release_gates_theory.csv` exists with PASS/FAIL/NA statuses.
- Theory-subset gates are computed separately from the full profile.
- Thresholds: Coverage in `[0.93, 0.97]`, bias control share `>= 0.80`, efficiency share `>= 0.70` on the theory subset.

### E+3 Stress-CI bound calibration (mandatory)

**Purpose:** Establish a robust stress-bound setting that holds empirically.

**Implementation tasks:**
- Evaluate multiple stress quantiles (0.95, 0.975, 0.99) or a multiplicative inflation factor.
- Select the smallest setting that meets the 90% bound-hold rate.

**Code changes:**
- `analysis/sim/boundary_experiment.R`: parameterize stress quantile.
- `analysis/sim/config.R`: allow `stress_quantile` per profile.
- `analysis/phase_e_release_gates.R`: report bound-hold by quantile.

**Expected artifacts:**
- `artifacts/sim/stress_bound_sweep.csv`

**Completion criteria (verifiable):**
- `artifacts/sim/stress_bound_sweep.csv` includes columns: `stress_quantile`, `bound_hold_rate`.
- The chosen stress setting is recorded in the config used for the next run.
- Thresholds: choose the smallest stress quantile with `bound_hold_rate >= 0.90` on the theory subset.

### E+4 Minimal passing configuration (mandatory)

**Purpose:** Identify the smallest set of changes that yields PASS on H1–H3.

**Implementation tasks:**
- Run the theory-subset profile with baseline learner + calibrated diagnostics.
- Only if it passes, expand to the full grid.

**Expected artifacts:**
- `artifacts/release_gates_minimal.csv`

**Completion criteria (verifiable):**
- `artifacts/release_gates_minimal.csv` exists and lists H1–H3 outcomes.
- If H1–H3 pass on the theory subset, a full-grid run is executed and archived.
- Thresholds: H1–H3 must be PASS on the theory subset; full-grid run may still be reported as FAIL but must include diagnostics AUC and bound-hold metrics.

## Proposed Run Order

1. Implement diagnostics feature extraction (E+1).
2. Add theory-subset grid (E+2).
3. Stress-bound sweep (E+3).
4. Minimal passing configuration runs (E+4).

## Verification Commands

Use these to verify each step:

1. E+1 diagnostics:
   - `Rscript analysis/sim/calibration_study.R`
   - `Rscript -e "x<-readRDS('artifacts/sim/calibration_results.rds'); print(setdiff(c('weak_ratio','instab','infl','se','n','beta'), colnames(x)))"`
   - `Rscript -e "print(read.csv('artifacts/sim/diagnostics_operating_chars.csv'))"`
2. E+2 theory subset:
   - `AEGIS_PROFILE=theory R_LIBS=./.Rlib Rscript analysis/run_targets_parallel.R`
   - `Rscript analysis/phase_e_release_gates.R` (expect `artifacts/release_gates_theory.csv`)
3. E+3 stress-bound sweep:
   - `Rscript analysis/sim/boundary_experiment.R` with varying `stress_quantile`
   - `ls artifacts/sim/stress_bound_sweep.csv`
4. E+4 minimal config:
   - `Rscript analysis/phase_e_release_gates.R` (expect `artifacts/release_gates_minimal.csv`)

## Success Criteria

- H1 and H2 pass on the theory-subset.
- H3 passes on the theory-subset or yields a narrow, honest scope statement.
- If H1–H3 fail after E+1–E+4, formally retract the scientific claim and publish as software + negative results.

## Definition of Done (checklist)

- [ ] E+1 diagnostics features added, classifier trained, AUC and $P(\text{miss}\mid \text{FAIL})$ computed with FAIL prevalence in [0.20, 0.50].
- [ ] E+2 theory-subset grid implemented and gates evaluated; coverage/bias/efficiency thresholds recorded.
- [ ] E+3 stress-bound sweep completed and a stress quantile selected with bound-hold rate >= 0.90.
- [ ] E+4 minimal configuration run completed; `artifacts/release_gates_minimal.csv` recorded.
- [ ] Decision documented: scientific claim validated (PASS) or retracted (FAIL) with a software-first positioning note.

## Notes

This plan is intentionally conservative. It avoids large learner changes or heavy hyperparameter search until the diagnostic signal is validated under assumptions aligned with the theory.
