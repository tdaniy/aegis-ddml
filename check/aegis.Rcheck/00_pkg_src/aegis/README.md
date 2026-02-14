# aegis

`aegis` is a minimal package scaffold for the AEGIS DML-lite inference framework.

## Reproducibility

Run the default targets pipeline:

```bash
AEGIS_PROFILE=default R_LIBS=./.Rlib Rscript analysis/run_targets_parallel.R
```

Run a fast pipeline for development:

```bash
AEGIS_PROFILE=fast R_LIBS=./.Rlib Rscript analysis/run_targets_parallel.R
```
