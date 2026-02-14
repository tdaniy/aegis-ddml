library(targets)
library(future)

workers <- as.integer(Sys.getenv("AEGIS_WORKERS", "4"))
if (is.na(workers) || workers < 1) {
  workers <- 4
}

cat(sprintf("Using AEGIS_WORKERS=%d\n", workers))
future::plan(multisession, workers = workers)

targets::tar_make_future()
