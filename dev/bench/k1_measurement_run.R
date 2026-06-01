#!/usr/bin/env Rscript

run_date <- format(Sys.Date(), "%Y%m%d")
seed <- 20260601L
target_reps <- 5L
slow_reps <- 3L
n_pulses <- 1260L
min_batch_elapsed <- 0.10
max_inner_iterations <- 10000L

library(ledgrcorespike)

rust_dll <- ledgrcorespike:::.k1_rust_dll_path()
if (!grepl("/target/release/", normalizePath(rust_dll, winslash = "/"), fixed = TRUE)) {
  stop("Stage 5 requires the Rust release DLL; run cargo +stable-gnu build --release")
}

scales <- data.frame(
  scale = c("small", "large", "xlarge"),
  n_instruments = c(50L, 100L, 1000L),
  n_fills = c(7042L, 13581L, 130277L),
  stringsAsFactors = FALSE
)

variants <- c(
  "strat_R_handler_R",
  "strat_R_handler_inline",
  "strat_static_handler_R",
  "strat_static_handler_inline"
)

implementations <- c("R", "Rust", "C++")

fn_lookup <- list(
  R = list(
    strat_R_handler_R = k1_r_fold_strat_R_handler_R,
    strat_R_handler_inline = k1_r_fold_strat_R_handler_inline,
    strat_static_handler_R = k1_r_fold_strat_static_handler_R,
    strat_static_handler_inline = k1_r_fold_strat_static_handler_inline
  ),
  Rust = list(
    strat_R_handler_R = k1_rust_fold_strat_R_handler_R,
    strat_R_handler_inline = k1_rust_fold_strat_R_handler_inline,
    strat_static_handler_R = k1_rust_fold_strat_static_handler_R,
    strat_static_handler_inline = k1_rust_fold_strat_static_handler_inline
  ),
  `C++` = list(
    strat_R_handler_R = k1_cpp_fold_strat_R_handler_R,
    strat_R_handler_inline = k1_cpp_fold_strat_R_handler_inline,
    strat_static_handler_R = k1_cpp_fold_strat_static_handler_R,
    strat_static_handler_inline = k1_cpp_fold_strat_static_handler_inline
  )
)

message("Generating fixtures once per scale...")
fixtures <- setNames(vector("list", nrow(scales)), scales$scale)
for (scale in scales$scale) {
  fixtures[[scale]] <- ledgrcorespike:::k1_make_fixture_bars(scale)
}

cells <- expand.grid(
  boundary_variant = variants,
  implementation = implementations,
  scale = scales$scale,
  stringsAsFactors = FALSE
)

set.seed(seed)
cells <- cells[sample.int(nrow(cells)), , drop = FALSE]

time_batch <- function(fn, bars, iterations) {
  gc(FALSE)
  start <- proc.time()[["elapsed"]]
  for (iteration in seq_len(iterations)) {
    invisible(fn(bars))
  }
  proc.time()[["elapsed"]] - start
}

calibrate_iterations <- function(fn, bars) {
  iterations <- 1L
  elapsed <- time_batch(fn, bars, iterations)

  while (elapsed < min_batch_elapsed && iterations < max_inner_iterations) {
    if (elapsed <= 0) {
      next_iterations <- iterations * 10L
    } else {
      next_iterations <- ceiling(iterations * min_batch_elapsed / elapsed)
      next_iterations <- max(next_iterations, iterations * 2L)
    }
    iterations <- min(as.integer(next_iterations), max_inner_iterations)
    elapsed <- time_batch(fn, bars, iterations)
  }

  list(
    iterations = iterations,
    elapsed = elapsed,
    per_call = elapsed / iterations
  )
}

out_path <- file.path("dev", "bench", "results", paste0("k1_measurement_", run_date, ".csv"))
completed <- NULL

if (file.exists(out_path)) {
  completed <- read.csv(out_path, stringsAsFactors = FALSE)
  if (nrow(completed)) {
    done_key <- paste(completed$boundary_variant, completed$implementation, completed$scale, sep = "\r")
    cell_key <- paste(cells$boundary_variant, cells$implementation, cells$scale, sep = "\r")
    cells <- cells[!(cell_key %in% done_key), , drop = FALSE]
    message(sprintf("Resuming from %s; %d cells already complete.", out_path, nrow(completed)))
  }
}

append_result <- function(row, path) {
  write.table(
    row,
    file = path,
    sep = ",",
    row.names = FALSE,
    col.names = !file.exists(path),
    append = file.exists(path),
    qmethod = "double"
  )
}

rows <- vector("list", nrow(cells))

for (row_idx in seq_len(nrow(cells))) {
  cell <- cells[row_idx, ]
  scale_info <- scales[match(cell$scale, scales$scale), ]
  bars <- fixtures[[cell$scale]]
  fn <- fn_lookup[[cell$implementation]][[cell$boundary_variant]]

  label <- paste(cell$implementation, cell$boundary_variant, cell$scale, sep = " / ")
  message(sprintf("[%02d/%02d] %s", row_idx, nrow(cells), label))

  warm <- calibrate_iterations(fn, bars)
  message(sprintf(
    "  warm discard/calibration: %.3fs total; %.6fs per call; inner_iterations=%d",
    warm$elapsed,
    warm$per_call,
    warm$iterations
  ))
  reps <- if (warm$per_call > 300) slow_reps else target_reps
  timings <- numeric(reps)

  for (rep_idx in seq_len(reps)) {
    elapsed <- time_batch(fn, bars, warm$iterations)
    timings[[rep_idx]] <- elapsed / warm$iterations
    message(sprintf(
      "  rep %d/%d: %.3fs total; %.6fs per call",
      rep_idx,
      reps,
      elapsed,
      timings[[rep_idx]]
    ))
    if (rep_idx == slow_reps && any(timings[seq_len(rep_idx)] > 300)) {
      timings <- timings[seq_len(rep_idx)]
      reps <- rep_idx
      break
    }
  }

  wall_median <- median(timings)
  wall_min <- min(timings)
  wall_max <- max(timings)
  high_ratio <- if (wall_median == 0) Inf else wall_max / wall_median
  low_ratio <- if (wall_min == 0) Inf else wall_median / wall_min
  anomaly <- isTRUE(high_ratio > 3 || low_ratio > 3)
  notes <- character()
  if (warm$per_call > 300 || length(timings) < target_reps) {
    notes <- c(notes, sprintf("reduced_reps_from_%d_to_%d", target_reps, length(timings)))
  }
  if (warm$iterations > 1L) {
    notes <- c(notes, sprintf("batched_inner_iterations_%d_due_timer_resolution", warm$iterations))
  }
  if (anomaly) {
    notes <- c(notes, sprintf("rep_deviation_gt_3x; timings=%s", paste(signif(timings, 6), collapse = "|")))
  }

  rows[[row_idx]] <- data.frame(
    run_date = run_date,
    seed = seed,
    boundary_variant = cell$boundary_variant,
    implementation = cell$implementation,
    scale = cell$scale,
    n_reps = length(timings),
    inner_iterations = warm$iterations,
    n_pulses = n_pulses,
    n_instruments = scale_info$n_instruments,
    n_fills = scale_info$n_fills,
    wall_median = wall_median,
    wall_min = wall_min,
    wall_max = wall_max,
    us_per_pulse = wall_median * 1e6 / n_pulses,
    us_per_fill = wall_median * 1e6 / scale_info$n_fills,
    anomaly_flag = anomaly,
    notes = paste(notes, collapse = "; "),
    stringsAsFactors = FALSE
  )
  append_result(rows[[row_idx]], out_path)
  message(sprintf("  wrote cell to %s", out_path))
}

rows <- Filter(Negate(is.null), rows)
new_result <- if (length(rows)) do.call(rbind, rows) else NULL
result <- if (!is.null(completed) && nrow(completed)) {
  rbind(completed, new_result)
} else {
  new_result
}
result <- result[order(result$scale, result$boundary_variant, result$implementation), ]
write.csv(result, out_path, row.names = FALSE)
message("Wrote ", out_path)

if (any(result$anomaly_flag)) {
  message("Anomalous cells:")
  print(result[result$anomaly_flag, c("implementation", "boundary_variant", "scale", "notes")])
} else {
  message("No cells exceeded the 3x deviation flag.")
}
