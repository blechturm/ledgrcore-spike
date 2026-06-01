# ledgrcore-spike Contract Index

This file records the small set of contracts relevant to the scaffolded spike
repository. ledgr's `inst/design/horizon.md` K1 entries remain authoritative for
the measurement spec.

## Compiled Fold Release Contract

Any code that ships later as a production compiled fold core must satisfy
byte-identical event-stream parity against ledgr's pure-R reference. ledgr's
2026-05-30 horizon entry states that byte-identical event-stream parity against
the pure-R reference is the release contract for any `ledgrcore` version.

This production contract does not apply to the scaffold itself. The measurement
spike measures cost and boundary economics; it does not need to ship
byte-identical events.

## Determinism Gate

If future R-side glue uses value-bearing collapse operations, it inherits
ledgr's deterministic-wrapper discipline: value-bearing acceleration must be
covered by parity fixtures and must not alter durable identity bytes unless a
later spec explicitly authorizes the change.

## Dependency Boundary

`ledgrcore-spike` has no runtime dependency on ledgr. ledgr is design-time
context only until the maintainer-authored measurement spec says otherwise.
