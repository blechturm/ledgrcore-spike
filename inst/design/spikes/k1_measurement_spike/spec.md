# K1 Measurement Spike Specification

Status: Stage 1 draft for maintainer review.
Date: 2026-06-01.
Repository: `ledgrcore-spike`.

## Authority

This spec operationalizes ledgr's K1 horizon entries. The authoritative source
remains ledgr's `inst/design/horizon.md`, especially:

- "2026-05-30 [architecture] Compiled fold core as ledgrcore sister package"
- the 2026-06-01 measurement-spike gate and repo-split updates inside that
  entry
- `2026-06-01 [architecture] R-side data structures as shared substrate for
  compiled-core path`

The v0.1.8.10 Round-3 synthesis also binds this spike's R baseline:
`inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`
L7 Ticket 2 and L9 require fold-owned FIFO accounting as part of the
post-v0.1.8.10 substrate surface.

This is a measurement harness, not a production fold-engine reimplementation.
It does not define the future `ledgrcore` API.

## Load-Bearing Numbers

The four load-bearing numbers are quoted verbatim from the K1 charter:

1. per-pulse cost with R strategy callback (realistic boundary case);
2. per-pulse cost with an inline static strategy (compiled-only ceiling);
3. per-fill cost with R output-handler callback (realistic boundary case);
4. per-fill cost with inline event accumulation (compiled-only ceiling).

The decision-rule thresholds are inherited unchanged:

- gaps < 1.5x on both per-pulse and per-fill: park `ledgrcore`;
- gaps 2-3x: `ledgrcore` is worth scoping with explicit cost/benefit math;
- gaps 5x+: compiled story is empirically load-bearing; build is authorized;
  language choice is driven by the spike's measured boundary-cost differential.

## Minimum Fold Loop

Each implementation receives a numeric bars matrix and returns an equity vector
plus a fill event stream. The minimum shape is:

- `bars`: numeric matrix, instruments in rows and pulses in columns, containing
  close prices. The wire format is R-native column-major matrix storage:
  compiled implementations index the flat double buffer as
  `bars[i + t * n_inst]`, with `i` and `t` zero-based internally. For timing,
  the bars matrix is generated once per `(scale, run_date)` tuple and reused
  across all reps and all `(boundary_variant, implementation)` cells at that
  scale. Fixture generation is not included in wall timing.
- `initial_cash`: scalar double, default `1e6`.
- `equity`: numeric vector of length `n_pulses`.
- `events`: typed fill stream with one row per fill.

The loop owns the following state:

- `cash`: scalar double.
- `positions`: bare numeric vector of length `n_inst`, indexed by instrument
  integer.
- `lots`: per-instrument FIFO queues. Each lot stores `quantity` and
  `cost_basis`.
- event buffers: integer pulse index, integer instrument index, double
  quantity, double price, double cash delta, double position delta, double
  realized PnL, double cost basis after event, integer side code.

The loop processes pulses in increasing column order. For each pulse:

1. Read the current price column from `bars`.
2. Resolve target positions through the selected strategy boundary.
3. For each instrument with non-zero target delta, emit a zero-cost fill at the
   current close price. Fill quantities are fractional doubles with no integer
   share rounding. The rebalance target quantity is
   `target_notional / current_price`, and the fill quantity is
   `target_quantity - current_position`.
4. Update cash, positions, FIFO lots, realized PnL, and cost basis in a fixed
   instrument-index order.
5. Write equity with naive left-to-right accumulation in instrument-index
   order:

```text
equity[t] = cash
for i in 0..(n_inst - 1):
  equity[t] = equity[t] + positions[i] * price[i, t]
```

All implementations must use the same arithmetic order for state updates and
equity valuation. No cost resolver, feature engine, runtime projection,
telemetry, durable I/O, risk step, or ledgr runtime dependency is in scope.

## Strategy

The static strategy is deterministic and intentionally non-trivial: it
rebalances to equal weight across an alternating active instrument subset every
5 pulses. Non-rebalance pulses retain current positions.

The active subset count is fixed per scale to match the requested LDG-2479
event-density shape:

| Scale | Active instruments per rebalance side |
| --- | ---: |
| small | 14 |
| large | 27 |
| xlarge | 259 |

At rebalance `k`, the active subset alternates between two disjoint windows of
that size. This forces closes and opens while staying deterministic. The first
rebalance opens one side; later rebalances close the previous side and open the
other. With 1260 pulses and a rebalance interval of 5, this gives approximate
fill counts of 7.0k, 13.6k, and 130.3k for small, large, and xlarge.

The R-callback strategy is a thin wrapper around the same static strategy. It
exists only to measure the strategy callback boundary and must not do extra
work beyond forwarding the minimal context and returning the target vector.

The minimal strategy context contains:

- `pulse_idx`: one-based pulse index for the R reference surface.
- `prices`: current price vector.
- `cash`: pulse-start cash.
- `positions`: pulse-start positions vector.
- `rebalance_due`: logical scalar.
- `scale`: scale label.

This context is deliberately smaller than ledgr's production `ctx` surface.

## Boundary Variants

Every implementation exposes these four variants:

| Variant | Strategy boundary | Output boundary |
| --- | --- | --- |
| `strat_R_handler_R` | R callback | R callback per fill |
| `strat_R_handler_inline` | R callback | inline typed event accumulation |
| `strat_static_handler_R` | inline static strategy | R callback per fill |
| `strat_static_handler_inline` | inline static strategy | inline typed event accumulation |

The R output handler is a thin function called once per fill event. It appends
the event to an R-owned accumulator. The inline event accumulator writes to
preallocated typed vectors and materializes the R object only after the loop.

For compiled implementations, R-callback variants must cross the R interpreter
boundary honestly. The callback path must not be replaced with compiled static
logic.

## Synthetic Fixture Grid

Pulse count is fixed at 1260 for every scale.

| Scale | Instruments | Pulses | Approx fills | Purpose |
| --- | ---: | ---: | ---: | --- |
| small | 50 | 1260 | 7042 | fast parity iteration |
| large | 100 | 1260 | 13581 | LDG-2479 large-shape measurement |
| xlarge | 1000 | 1260 | 130277 | LDG-2479 xlarge-shape measurement |

The fixture generator uses fixed seed `20260601`. Bars must be generated with a
cross-platform deterministic algorithm, not implementation-defined RNG state.
The fixture format is a numeric matrix with deterministic positive prices. A
simple specified generator is acceptable, for example:

```text
price[i, t] = 100 + 0.01 * i + 0.001 * t + deterministic_wave(i, t)
```

where `deterministic_wave()` is a closed-form arithmetic function of integer
indices:

```text
deterministic_wave(i, t) = ((i * 7919 + t * 6311) mod 10000) / 100000.0
```

The formula uses one-based `i` and `t` values, 64-bit integer intermediates,
modular arithmetic, and a single final floating-point division. It must not use
transcendental functions. If pseudo-random fixture noise is added later, the
exact generator and seed must be documented before timing runs.

## Parity Gates

Parity is checked at `small` before any timing run.

Required parity:

- R self-consistency: all four R variants produce equivalent equity and event
  streams.
- Rust vs R: each Rust variant matches its corresponding R variant.
- C++ vs R: each C++ variant matches its corresponding R variant.
- Rust vs C++: corresponding compiled variants match each other.

Equity parity is byte-identical where possible. If accumulation order makes
byte identity inappropriate, the permitted relaxation is Kahan-vs-cumsum
tolerance `1e-8`, named explicitly per ledgr v0.1.8.9 L4. Numerical event
fields use the same tolerance only for realized PnL, cost basis, cash delta,
position delta, quantity, and price. Integer fields and side codes must be
byte-identical.

Event rows must be ordered by `(pulse_idx, instrument_idx)` in the fixed loop
order. Event count must match exactly.

## Measurement Protocol

Each timing cell is one combination of:

- boundary variant: 4 variants
- implementation: R reference, Rust extendr, C++ cpp11
- scale: small, large, xlarge

This yields 36 timing cells.

For each cell:

1. Run one warm-cache rep and discard it.
2. Run `N = 5` measured reps.
3. Call `gc(FALSE)` between reps.
4. Record wall time with a monotonic timer.
5. Report median, min, and max wall seconds.
6. Derive `us_per_pulse = wall_median * 1e6 / n_pulses`.
7. Derive `us_per_fill = wall_median * 1e6 / n_fills`.

If a measured rep takes more than 5 minutes, that cell may reduce to `N = 3`.
The methodology note must name every reduced-rep cell.

Invocation order is randomized within each scale and rep block so one
implementation does not always receive the same cache or thermal position. The
randomization seed is `20260601`.

If any measured rep is more than 3x away from its cell median, flag the cell in
the methodology note and investigate before trusting it.

Results are written to:

```text
dev/bench/results/k1_measurement_<YYYYMMDD>.csv
```

Required columns:

- `run_date`
- `seed`
- `boundary_variant`
- `implementation`
- `scale`
- `n_reps`
- `n_pulses`
- `n_instruments`
- `n_fills`
- `wall_median`
- `wall_min`
- `wall_max`
- `us_per_pulse`
- `us_per_fill`
- `anomaly_flag`
- `notes`

The methodology note is written to:

```text
dev/bench/notes/k1_measurement_methodology.md
```

It must name the platform: Windows, R 4.5.2, Rtools, cpp11, Rust, extendr, and
the exact Rust toolchain used.

## Verdict

The verdict is written after timing to:

```text
inst/design/spikes/k1_measurement_spike/verdict.md
```

It must include:

- headline xlarge gaps for Rust vs R and C++ vs R across per-pulse and per-fill
  costs, including all four boundary variants;
- the threshold-mapped verdict: park, scope further, or build authorized;
- the language verdict if build is authorized, driven by measured Rust extendr
  vs C++ cpp11 boundary-cost differential;
- confidence and caveats, including synthetic-fixture limits, Windows-only
  execution, and the fact that the R reference models the post-v0.1.8.10
  substrate shape before ledgr v0.1.8.10 has shipped;
- cross-links back to ledgr horizon language answered by the result.

## Determinism Contract

Every run uses fixed seed `20260601` and deterministic fixture generation. No
wall-clock-dependent inputs are allowed.

The spike is Windows-only for this measurement pass. A production `ledgrcore`
release contract would be stricter: byte-identical event-stream parity with
ledgr's pure-R reference across Linux, macOS, and Windows.

## Out of Scope

The spike excludes:

- cost-resolver semantics;
- feature engine and runtime projection;
- full ledgr strategy callback context;
- durable or DuckDB I/O;
- telemetry exposure and subphase decomposition;
- production workload-grid extrapolation;
- CRAN hardening;
- any runtime dependency on ledgr.

## Stage Handoffs

Stage 1 ends with this spec and the directory README. Implementation does not
start until the maintainer accepts or revises the spec.
