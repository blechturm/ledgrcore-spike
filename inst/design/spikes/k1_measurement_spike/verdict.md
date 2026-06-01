# K1 Measurement Spike Verdict

Authored: 2026-06-01

Status: Stage 6 verdict from `dev/bench/results/k1_measurement_20260601.csv`.

## Verdict

Build is authorized on the K1 measurement rule, but only for the inline-output
compiled-core path. The xlarge inline event-accumulation cells clear the 5x
threshold by a wide margin:

- `strat_static_handler_inline`: Rust is 151.20x faster than R; C++ is 32.73x
  faster than R.
- `strat_R_handler_inline`: Rust is 47.33x faster than R; C++ is 10.14x faster
  than R.

The realistic per-fill R output-handler cells do not justify a compiled fold
core by themselves:

- `strat_R_handler_R`: Rust is 0.97x R; C++ is 1.02x R.
- `strat_static_handler_R`: Rust is 1.00x R; C++ is 1.08x R.

So the actionable conclusion is precise: K1 has real headroom when fill events
stay inside the compiled loop and are materialized once. If ledgrcore must call
an R output handler once per fill, the R boundary dominates and the compiled
port is not load-bearing.

## Horizon Question Answered

The ledgr horizon asks whether the spike changes the build decision:

> "The gap between realistic and inline numbers measures how much K1 actually buys."

This run answers that directly. K1 buys little across the per-fill R callback
boundary and a lot across the inline event-accumulation boundary.

The horizon's package-shape premise still holds if the maintainer accepts this
verdict:

> "compiled fold core ships as a separate `ledgrcore` sister package;"

The release contract also remains binding:

> "byte-identical event-stream parity against the pure-R reference"

Stage 3 and Stage 4 parity demonstrated that contract on the spike's small
fixture before Stage 5 timing.

## Headline Xlarge Numbers

Ratios are R median divided by compiled median. Values above 1.0 mean compiled
is faster. The per-pulse and per-fill ratios are identical within a row because
all implementations in a cell use the same xlarge pulse and fill counts; both
surfaces are shown because the horizon names both as load-bearing.

| Boundary variant | R us/pulse | Rust us/pulse | Rust pulse gap | C++ us/pulse | C++ pulse gap | R us/fill | Rust us/fill | Rust fill gap | C++ us/fill | C++ fill gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `strat_R_handler_R` | 112047.62 | 114968.25 | 0.97x | 110261.90 | 1.02x | 1083.69 | 1111.94 | 0.97x | 1066.42 | 1.02x |
| `strat_R_handler_inline` | 563.49 | 11.90 | 47.33x | 55.56 | 10.14x | 5.45 | 0.12 | 47.33x | 0.54 | 10.14x |
| `strat_static_handler_R` | 113865.08 | 114238.10 | 1.00x | 105071.43 | 1.08x | 1101.27 | 1104.88 | 1.00x | 1016.22 | 1.08x |
| `strat_static_handler_inline` | 571.43 | 3.78 | 151.20x | 17.46 | 32.73x | 5.53 | 0.04 | 151.20x | 0.17 | 32.73x |

The decision-bearing headline gaps are therefore:

- Realistic full-boundary `strat_R_handler_R`: Rust 0.97x, C++ 1.02x on both
  per-pulse and per-fill.
- Compiled-ceiling `strat_static_handler_inline`: Rust 151.20x, C++ 32.73x on
  both per-pulse and per-fill.
- Completeness cells: `strat_R_handler_inline` gives Rust 47.33x and C++ 10.14x;
  `strat_static_handler_R` gives Rust 1.00x and C++ 1.08x.

## Decision Rule

The horizon threshold is met by the inline event-accumulation path:

- All gaps under 1.5x? No. The inline cells are far above 5x.
- Some gaps 2-3x? Not the controlling case. The important cells are either
  around 1x or far above 5x.
- Some gaps 5x+? Yes. Both compiled implementations exceed 5x on the inline
  output path at xlarge, and Rust exceeds 5x by roughly two orders of
  magnitude on the compiled ceiling.

Build authorization is therefore justified if the production design can preserve
the inline event path. A ledgrcore build that simply calls ledgr's current R
output handler once per fill should stay parked.

## Language Verdict

Rust extendr is the faster compiled-core candidate for the cells that matter to
the build case:

- `strat_static_handler_inline` xlarge: Rust 0.00476s vs C++ 0.0220s, so Rust
  is 4.62x faster.
- `strat_R_handler_inline` xlarge: Rust 0.0150s vs C++ 0.0700s, so Rust is
  4.67x faster.

C++ cpp11 is slightly faster only in the R output-handler dominated cells:

- `strat_static_handler_R` xlarge: C++ 132.39s vs Rust 143.94s, so C++ is
  1.09x faster.
- `strat_R_handler_R` xlarge: C++ 138.93s vs Rust 144.86s, so C++ is 1.04x
  faster.

Those C++ wins occur where the verdict says not to build the production shape:
per-fill R callback traffic dominates the fold. The language choice should
therefore favor Rust on measured performance for the viable inline-output design.

Toolchain friction tempers that recommendation. Stage 3 required a custom
`src-rust/` development DLL loading path and explicit release-DLL safeguards.
Stage 4 cpp11 integrated more naturally with `R CMD INSTALL .` and existing R
package registration, though it was slower in the inline-output cells. A
production ledgrcore Rust path needs an explicit package-build story rather than
the spike's development-DLL wrapper. C++ has lower R-package build friction on
this scaffold; Rust has the stronger measured runtime case.

## Confidence

Confidence is high for the minimum loop question the spike was designed to
answer:

- All 36 Stage 5 cells completed with 5 measured reps.
- No cell exceeded the 3x deviation anomaly flag.
- Rust and C++ were compared against the same R reference and deterministic
  fixture.
- The xlarge fixture exercises 1000 instruments, 1260 pulses, and 130277 fills.

Confidence is lower for direct production extrapolation. The spike deliberately
excludes ledgr's full strategy context, feature engine, cost/liquidity/risk
steps, durable I/O, telemetry, and production workload dispatch. It measures
the minimum fold substrate, not the full ledgr runtime.

## Caveats

This verdict is Windows-specific: Windows 10 x64, R 4.5.2, Rtools GCC 14.2.0,
cpp11, extendr, and Rust `stable-gnu` release. A production build decision
should rerun Linux and macOS parity/timing before publishing a cross-platform
claim.

The fixture is synthetic. It intentionally mirrors the LDG-2479 high-density
shape, but it does not include production strategy workloads, realistic feature
lookups, costs, liquidity, risk, or durable database writes.

The R baseline is a post-v0.1.8.10 substrate model, not a benchmark of the
current ledgr production fold at the moment this verdict was authored. That is
intentional: the horizon requires the fair comparison to be post-substrate R vs
compiled. Once v0.1.8.10 ships, ledgr should decide whether to rerun this spike
against the actual production R substrate rather than the spike's substrate
model.

What would change the verdict:

- If production ledgr cannot adopt an inline compiled event accumulator, the
  build case collapses to the R-handler cells, where the measured gaps are near
  1x.
- If post-v0.1.8.10 production R materially beats the spike R reference on the
  inline-output path, the gap narrows and the build should be re-evaluated.
- If production workloads spend most wall time outside the fold slice, the K1
  build can be technically justified but still lower leverage than the dominant
  ledgr-side residual.

## Ledgr Handoff

Recommended ledgr horizon update:

- Mark the K1 measurement spike as complete.
- Record that build authorization is granted only for a design that keeps fill
  event accumulation inside the compiled loop and materializes the event frame
  once.
- Record Rust as the measured runtime winner for the viable inline-output path,
  with C++ retaining lower R-package integration friction.
- Keep the pure-R fold as the byte-parity reference and test default.
- Do not authorize a production ledgrcore shape that calls an R output handler
  per fill.

The repo-split rationale remains valid. The spike showed why the separate repo
was useful: Rust/C++ FFI iteration, release-build safeguards, and long xlarge
measurement cells would have been disruptive inside ledgr's R-side cadence.
