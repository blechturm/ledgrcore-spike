# K1 Measurement Methodology

Run date: 2026-06-01

Results file: `dev/bench/results/k1_measurement_20260601.csv`

## Platform

- OS: Windows 10 x64
- R: R version 4.5.2 (2025-10-31 ucrt)
- C++ toolchain: Rtools GCC 14.2.0, cpp11 path via `R CMD INSTALL .`
- Rust toolchain: `rustc 1.96.0 (ac68faa20 2026-05-25)`, built with `cargo +stable-gnu build --release`

Rust measurements used the `src-rust/target/release/` DLL. The runner checks the loaded Rust DLL path and aborts if it resolves to a debug build.

## Build Discipline

Before measurement:

```text
R CMD INSTALL .
cargo +stable-gnu build --release
```

C++ was measured through the installed package DLL produced by `R CMD INSTALL .`. Rust was measured through the release DLL loaded by `R/k1_rust_wrappers.R`.

## Grid

The run covered all 36 cells:

- 4 boundary variants
- 3 implementations: R, Rust, C++
- 3 scales: small, large, xlarge

Each cell used the same synthetic fixture shape and fill counts defined by the K1 measurement spec:

- small: 50 instruments, 1260 pulses, 7042 fills
- large: 100 instruments, 1260 pulses, 13581 fills
- xlarge: 1000 instruments, 1260 pulses, 130277 fills

Bars matrices were generated once per scale and reused across all cells for that scale.

## Timing Discipline

- Seed: `20260601`
- Cell invocation order was randomized once using that seed.
- Each cell discarded one warm-cache calibration run before recording timing reps.
- Target reps: 5 measured reps per cell.
- Slow-cell rule: reduce to 3 reps only if any per-fold rep exceeds 300 seconds. No cell exceeded that threshold, so every cell used 5 measured reps.
- `gc(FALSE)` ran before each warm/calibration batch and before each measured batch.
- Reported `wall_median`, `wall_min`, and `wall_max` are per-fold seconds.
- `us_per_pulse = wall_median * 1e6 / 1260`.
- `us_per_fill = wall_median * 1e6 / n_fills`.

Windows elapsed timing rounded very fast compiled cells to zero when measured as single folds. The runner therefore uses adaptive inner batching for cells whose discarded warm run is below 0.10 seconds, then records per-fold elapsed time by dividing the batch time by `inner_iterations`. The outer measurement discipline remains 5 measured reps per cell; `inner_iterations` is recorded in the CSV.

## Anomaly Review

No cell exceeded the 3x deviation flag.

No cell used reduced reps.

The slow cells were the xlarge variants with the R output handler boundary. Their medians were all around 132-145 seconds per fold, confirming that per-fill R callback cost dominates those measurements:

- C++ `strat_static_handler_R` xlarge: 132.39s
- C++ `strat_R_handler_R` xlarge: 138.93s
- R `strat_R_handler_R` xlarge: 141.18s
- R `strat_static_handler_R` xlarge: 143.47s
- Rust `strat_static_handler_R` xlarge: 143.94s
- Rust `strat_R_handler_R` xlarge: 144.86s

## Speed Summary

Representative median wall-clock results:

| Boundary | Scale | R | C++ | Rust |
| --- | ---: | ---: | ---: | ---: |
| `strat_static_handler_inline` | large | 0.0800s | 0.00250s | 0.000760s |
| `strat_static_handler_inline` | xlarge | 0.720s | 0.0220s | 0.00476s |
| `strat_R_handler_inline` | xlarge | 0.710s | 0.0700s | 0.0150s |
| `strat_R_handler_R` | xlarge | 141.18s | 138.93s | 144.86s |
| `strat_static_handler_R` | xlarge | 143.47s | 132.39s | 143.94s |

The compiled-core signal is strongest when the output handler remains inline. With per-fill R output callbacks, R boundary traffic dominates and the implementation language has little practical effect.

## Out Of Scope

This run did not measure ledgr production sweep dispatch, per-strategy peer workloads, cost/liquidity/risk steps, memory profiling, GC profiling, or allocation counts.
