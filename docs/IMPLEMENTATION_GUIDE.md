# AEGIS DML Implementation Guide

This document is the operational companion to `aegis_blueprint_dml.md`.

Use `aegis_blueprint_dml.md` for scientific rationale and theory.
Use this file to build, validate, and release the R package.

Document role: Operational execution guide (procedural).
Companion scientific spec: `aegis_blueprint_dml.md`.
Version target: `v0.1.0`.

---

## 0. Quickstart (one-page execution path)

If you only need the shortest build path:

1. Complete Phase A (`A.1` through `A.6`) to set up machine and repository.
2. Complete Phase B (`B.1` through `B.7`) to create a compilable package.
3. Complete Phase C (`C.1` through `C.9`) to implement cross-fitting + orthogonal inference.
4. Run Phase D to generate boundary-experiment, diagnostic-calibration, and adversarial-audit artifacts (via `targets::tar_make()`).
5. Pass Phase E release gates, including the minimal publishability evidence bundle.

One-command smoke check after Phases A–C:

```bash
R -q -e "devtools::document(); devtools::test(); devtools::check()"
```

Done when:

- package checks with zero errors,
- leakage tests pass,
- toy LM/GLM fits return finite estimate and SE,
- reruns under fixed seed are identical.

---

## A. Environment and repository bootstrap

### A.1 Install Ubuntu dependencies

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y \
  build-essential gfortran make cmake pkg-config \
  libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
  libfontconfig1-dev libcairo2-dev libfreetype6-dev \
  libpng-dev libtiff5-dev libjpeg-dev \
  git openssh-client
```

Check:

```bash
git --version
gcc --version
```

### A.2 Install R toolchain

```bash
sudo apt install -y r-base r-base-dev
R --version
R -q -e "sessionInfo()"
```

### A.3 Configure Git and SSH

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub
ssh -T git@github.com
```

### A.4 Install required R packages

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages(c(
  "devtools", "usethis", "roxygen2", "testthat",
  "pkgdown", "rmarkdown", "renv", "withr", "targets"
))
```

### A.5 Prepare repository

If cloning fresh:

```bash
cd ~/src/ob1
git clone <repo-url> aegis
cd aegis
git checkout -b feat/aegis-bootstrap
```

If repository already exists:

```bash
cd ~/src/ob1/<repo-dir>
git checkout -b feat/aegis-bootstrap
```

Solo developer exception:

If you are the only contributor and intentionally work directly on `main`,
you may skip creating `feat/aegis-bootstrap`. Record this as:
`A.5 waived (solo developer on main)`.

### A.6 Create standard folders

```bash
mkdir -p R tests/testthat analysis/sim analysis/figures analysis/tables analysis/empirical \
  paper paper/figures artifacts artifacts/sim artifacts/empirical data-raw inst/simulations
```

Phase A done criteria:

- toolchain works,
- repository branch created, or `A.5 waived (solo developer on main)`,
- required directories exist.

---

## B. Minimal compilable package scaffold

### B.1 Initialize package metadata

Run in R (package root):

```r
usethis::use_mit_license("AEGIS Authors")
usethis::use_readme_rmd()
usethis::use_testthat(3)
usethis::use_roxygen_md()
usethis::use_news_md()
usethis::use_git_ignore(c(".Rhistory", ".RData", "artifacts/"))
```

Ensure `DESCRIPTION` contains:

- `Imports: stats`
- `Suggests: testthat (>= 3.0.0), withr`
- UTF-8 encoding
- roxygen metadata fields

### B.2 Create initial R files

```r
usethis::use_r("aegis_spec")
usethis::use_r("strategy_crossfit")
usethis::use_r("learner_base")
usethis::use_r("nuis_spec")
usethis::use_r("targets")
usethis::use_r("aegis_fit")
usethis::use_r("methods")
```

### B.3 Implement constructors

Implement minimal exported constructors:

- `aegis_spec()`
- `strategy_crossfit()`
- `learner_base()`
- `nuis_spec()`
- `target_lm()`
- `target_glm()`

Each constructor must:

- validate core arguments,
- return a typed S3 object,
- avoid hidden side effects.

### B.4 Implement placeholder fit object

`aegis_fit()` in this phase should return:

- `theta`, `se`, `vcov` placeholders,
- `diagnostics = list()`,
- `artifacts = list()`,
- class `aegis_fit`.

### B.5 Implement minimal methods

Implement:

- `print.aegis_fit()`
- `summary.aegis_fit()`
- `print.summary.aegis_fit()`
- `confint.aegis_fit()`

### B.6 Add initial API tests

Create `tests/testthat/test-api.R` with checks for:

- constructor classes,
- `aegis_fit()` output class/fields.

### B.7 Validate scaffold

```r
devtools::document()
devtools::test()
devtools::check()
```

Phase B done criteria:

- package compiles and checks cleanly,
- exported functions documented,
- initial tests pass on clean machine.

---

## C. Implement cross-fitting and orthogonal inference

### C.1 Implement fold generation and OOF prediction

Create `R/crossfit.R` with:

- `make_folds(n, v, seed)` deterministic assignment,
- `crossfit_predict(...)` strict out-of-fold predictions.

Rules:

- no in-fold scoring allowed,
- fold vector stored in fit artifacts.

### C.2 Implement nuisance estimation layer

Create `R/nuisance.R` with fold-wise nuisance fitting:

- `fit_nuisance_rY()` for $\mathbb{E}[Y \mid Z]$,
- `fit_nuisance_rM()` for $\mathbb{E}[D \mid Z]$ or nuisance signal.

Both functions must return OOF predictions aligned to original row order.

### C.3 Implement LM orthogonal inference

Create `R/inference_lm.R`:

1. residualize outcome and nuisance signal on controls,
2. solve orthogonal score root for `theta`,
3. compute robust sandwich variance.

Output:

- `theta`,
- `se`,
- `vcov`,
- score vector used for diagnostics.

### C.4 Implement GLM orthogonal inference

Create `R/inference_glm.R`:

1. define orthogonal score and Jacobian,
2. Newton or root-solver updates with tolerance and max-iteration cap,
3. robust variance from score/Jacobian moments.

Guardrails:

- explicit non-convergence error,
- record `iterations` and final score norm.

### C.5 Add diagnostics

Create `R/diagnostics.R`:

- leakage diagnostic,
- weak-signal diagnostic,
- influence diagnostic (score-based contribution summary).

### C.6 Integrate pipeline in `aegis_fit()`

`aegis_fit()` integration order:

1. parse and validate inputs/spec,
2. set seed and make folds,
3. compute OOF nuisance predictions,
4. dispatch LM/GLM inference,
5. run diagnostics,
6. return structured `aegis_fit`.

Required returned fields:

- `theta`, `se`, `vcov`,
- `folds`,
- `oof`,
- `diagnostics`,
- `artifacts` (`seed`, `session_info`, learner metadata).

### C.7 Add targeted test files

Create:

- `tests/testthat/test-crossfit-integrity.R`
- `tests/testthat/test-lm-orthogonal.R`
- `tests/testthat/test-glm-orthogonal.R`
- `tests/testthat/test-reproducibility.R`

Minimum assertions:

- zero leakage failures,
- finite estimates and SEs,
- deterministic reruns with fixed seed.

### C.8 Add toy regression tests

Add small synthetic DGP tests:

- partially linear Gaussian toy case,
- logistic toy case.

Check expected directionality and finite confidence intervals.

### C.9 Validate Phase C

```r
devtools::document()
devtools::test()
devtools::check()
```

Phase C done criteria:

- all targeted tests pass,
- no leakage detected,
- LM/GLM toy examples return stable inferential outputs.

---

## D. Reproducible evaluation pipeline

### D.1 Implement simulation programs (required)

Required scripts:

- `analysis/sim/boundary_experiment.R` (beta vs a grid, weak-signal boundary)
- `analysis/sim/adversarial_benchmark.R` (DoubleML, grf, tmle3, naive ML)
- `analysis/sim/calibration_study.R` (diagnostic ROC/AUC and risk-gap)
- `analysis/sim/schema.md` (parameter grid and artifact schema)

Boundary experiment must include Wald, stress-envelope, and cross-fitted empirical likelihood CIs in weak-signal cells.

Outputs:

- `artifacts/sim/boundary_results.rds`
- `artifacts/sim/boundary_summary.csv`
- `artifacts/sim/boundary_manifest.json`
- `artifacts/sim/adversarial_results.rds`
- `artifacts/sim/adversarial_audit_summary.csv`
- `artifacts/sim/adversarial_manifest.json`
- `artifacts/sim/calibration_results.rds`
- `artifacts/sim/diagnostics_operating_chars.csv`
- `artifacts/sim/calibration_manifest.json`
- `artifacts/sim/summary_metrics.csv`

### D.2 Implement figure, table, and empirical scripts

Figure scripts (read artifacts only, no simulation):

- `analysis/figures/figA_weak_signal.R`
- `analysis/figures/figB_boundary.R`
- `analysis/figures/figC_roc.R`
- `analysis/figures/figD_instability.R`
- `analysis/figures/figE_pareto.R`

Table scripts (read artifacts only):

- `analysis/tables/table1_coverage.R`
- `analysis/tables/table2_diagnostics.R`
- `analysis/tables/table3_reproducibility.R`

Empirical scripts:

- `analysis/empirical/01_prepare_wage.R`
- `analysis/empirical/02_fit_models.R`
- `analysis/empirical/03_report_tables_figures.R`

Outputs:

- `artifacts/empirical/estimates.csv`
- `artifacts/empirical/diagnostics.csv`
- `artifacts/empirical/table_main.tex` or `.md`

### D.3 Implement targets pipeline (mandatory)

Create `_targets.R` to orchestrate all simulation, figure, table, and empirical steps.

Run:

```bash
Rscript -e "targets::tar_make()"
```

Optional dev shortcut:

```bash
Rscript analysis/run_all.R
```

### D.4 Reproducibility controls

Mandatory:

- master seed + deterministic sub-seeds,
- persisted fold assignments,
- `renv::snapshot()` lockfile,
- `sessionInfo()` artifact,
- per-run `manifest.json` with commit hash, parameter grid, seed root, and timestamp.

### D.5 Adversarial audit protocol (mandatory)

Protocol rules:

- Estimand alignment and identical learner sets across AEGIS and comparators.
- Resampling parity (same folds, same seed schedule).
- No oracle leakage or tuning on evaluation folds.
- Report coverage, CI length, fold-seed instability, and diagnostic AUC.
- If an estimand cannot be aligned across software, exclude it and document the exclusion.

Phase D done criteria:

- clean checkout can rerun all artifacts via `targets::tar_make()`,
- boundary, calibration, and adversarial audit artifacts are generated,
- produced tables/figures are identical across reruns with fixed seed.

---

## E. Release and manuscript readiness

### E.1 PR checklist

Before merge:

- code linked to explicit phase step,
- tests added/updated,
- docs regenerated,
- local check passes,
- reproducibility impact noted.

### E.2 Quantitative release gates

| Category | Metric | Threshold |
| --- | --- | --- |
| Coverage validity | Empirical 95% CI coverage for AEGIS at $n \ge 500$ | between 93% and 97% |
| Bias control | AEGIS absolute bias vs naive | better/equal in >= 80% grid cells |
| Efficiency | AEGIS CI length vs sample-split | >= 10% shorter in >= 70% grid cells |
| Stress-CI bound check | Stress-CI miss rate vs estimated bound | bound holds in >= 90% of primary grid cells |
| Boundary sharpness | Coverage separation across $\psi = 2a - \tfrac{1}{2} - \beta$ | median coverage for $\psi > 0.10$ >= 0.93 and for $\psi < -0.10$ <= 0.90 |
| Diagnostic calibration | ROC/AUC and risk stratification | AUC >= 0.7 and $P(\text{miss}\mid \text{FAIL})$ >= 0.7 in stress regimes |
| Adversarial audit | Coverage improvement vs DoubleML in weak-signal regimes | AEGIS coverage >= DoubleML in >= 70% of pre-registered weak-signal cells on the primary grid, with CI length ratio <= 1.5 (extreme-stress cells reported separately) |
| Convergence | GLM successful convergence rate | >= 99% |
| Leakage | In-fold scoring violations | exactly 0 |
| Reproducibility | Two reruns under fixed seed | exact match on scalar metrics and tables |
| Tests | Local suite reliability | 100% pass across 3 consecutive runs |

### E.3 Minimal publishability evidence bundle

Required figures (exact set of five):

- Figure A: Weak-signal coverage failure of vanilla DML.
- Figure B: Boundary heatmap (beta vs a) with $\beta = 2a - 1/2$ overlay.
- Figure C: Diagnostic ROC for CI failure prediction.
- Figure D: Fold-seed instability distribution.
- Figure E: Coverage vs CI length trade-off (AEGIS vs DoubleML).

Required tables (exact set of three):

- Table 1: Coverage summary across the DGP grid (DoubleML Wald, AEGIS Wald, AEGIS stress-CI).
- Table 2: Diagnostic operating characteristics (FPR, FNR, AUC, $P(\text{miss}\mid \text{FAIL})$).
- Table 3: Reproducibility and instability metrics (fold-seed variance, disagreement rate, $\hat{\kappa}$ summaries).

Falsification rule:

If Figures A–E do not show the expected qualitative behavior, downgrade to a software-focused paper rather than a methodological claim.

### E.4 Pre-release command matrix

Run in order:

```r
devtools::document()
devtools::test()
devtools::check()
renv::status()
```

Then:

```bash
Rscript -e "targets::tar_make()"
```

Optional dev shortcut:

```bash
Rscript analysis/run_all.R
```

### E.5 CI automation requirement

Configure CI (e.g., GitHub Actions) to run on every PR:

1. package checks (`devtools::check()`),
2. unit tests (`devtools::test()`),
3. deterministic smoke simulation subset (small grid),
4. artifact integrity checks (required output files present).

### E.6 Release candidate decision rule

Ship `v0.1.0` only if:

- all thresholds in `E.2` pass,
- no unresolved critical defects,
- manuscript claims trace directly to generated artifacts.

### E.7 Collaborator handoff bundle

Provide:

- tagged source revision,
- `renv.lock`,
- generated artifacts,
- rerun instructions in README.

Phase E done criteria:

- collaborator can clone and reproduce main results without manual fixes.

---

## F. Troubleshooting quick reference

- `00LOCK` package install errors:
  remove lock folders in R library directory and reinstall.
- Missing system dependencies:
  reinstall packages listed in Phase A.
- Flaky tests:
  enforce fixed seeds with `withr::with_seed()`.
- GLM non-convergence:
  reduce step size, improve initialization, inspect score diagnostics.

---

*End of implementation guide.*
