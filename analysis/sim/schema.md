# Phase D Simulation Schema

This file defines the simulation grid and artifact schema for Phase D.

## Global settings

- Seeds: a master seed `seed_root` plus deterministic sub-seeds by task name.
- Repeats: each cell runs `R` Monte Carlo replications.
- Core estimators: AEGIS (orthogonal DML), naive ML plug-in, sample-splitting only, oracle.

## Boundary experiment grid

- Sample sizes: `n` in {200, 500, 1000}
- Signal strength: `beta` in {0.0, 0.25, 0.5, 0.75}
- Nuisance rates: `a` in {0.25, 0.35, 0.5}
- Learners: linear baseline (Phase D v0.1)
- DGP: partially linear regression (PLR) with weak-signal boundary

## Calibration study grid

- Sample sizes: `n` in {200, 500, 1000}
- Signal strength: `beta` in {0.0, 0.25, 0.5, 0.75}
- Repetitions: `R` set to 200

## Adversarial audit grid

- Estimands: PLR (LM) and logistic PLR (GLM)
- Learner parity: identical learner types across AEGIS and comparators
- Resampling parity: identical fold schedule per cell

## Artifacts

All artifacts include a `manifest.json` containing:

- git commit hash
- parameter grid
- seed_root
- timestamps

Expected files:

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
