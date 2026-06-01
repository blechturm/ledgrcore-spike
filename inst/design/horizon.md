# ledgrcore-spike Horizon

**Status:** Active parking lot.
**Authority:** Non-binding design memory.

This file holds design observations that are not ready for the roadmap, an ADR,
or a versioned spec packet. It is not a backlog and does not imply commitment.

Use lightweight entries only:

```text
### YYYY-MM-DD [area] Short title

Freeform note.
```

Area tags:

```text
execution, ux, data, risk, cost, research, infrastructure, adapters
```

Do not add owners, due dates, priorities, acceptance criteria, or ticket
statuses. If an item becomes planned work, promote it into the roadmap, an RFC,
an architecture note, or a spec packet.

## Open

### 2026-06-01 [architecture] ledgrcore-spike charter

`ledgrcore-spike` is the external measurement repository for ledgr's K1 compiled
fold-core question. The authoritative source is ledgr's horizon entry
`2026-05-30 [architecture] Compiled fold core as `ledgrcore` sister package`,
including the 2026-06-01 measurement-spike gate and repo-split updates.

The spike measures four load-bearing numbers named by ledgr's K1 horizon entry:
per-pulse cost with an R strategy callback, per-pulse cost with an inline static
strategy, per-fill cost with an R output-handler callback, and per-fill cost
with inline event accumulation.

The decision rules are inherited unchanged: gaps below 1.5x on both per-pulse
and per-fill keep `ledgrcore` parked; 2-3x gaps justify explicit scope and
cost/benefit math; 5x or larger gaps authorize the build, with C++ via cpp11 vs
Rust via extendr decided by measured boundary-cost differential.

### 2026-06-01 [architecture] Substrate baseline

The measurement baseline is post-v0.1.8.10 production R, per ledgr's
`2026-06-01 [architecture] R-side data structures as shared substrate for
compiled-core path` entry and the repo-split update inside the K1 entry. Running
against pre-substrate R would overstate the compiled-core win.

### 2026-06-01 [execution] Scope boundary

This repository is the measurement spike, not a partial fold-core
reimplementation. It may contain only the package, toolchain, governance, and
hello-world compiled stubs until the maintainer authors the measurement spec.
The eventual spike remains minimum viable: bars matrix in, equity vector out,
with no runtime dependency on ledgr.

## Resolved

Entries move here when their idea has shipped or been answered.
