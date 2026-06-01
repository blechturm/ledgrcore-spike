# ledgrcore-spike

`ledgrcore-spike` is a sister research repository for ledgr's compiled fold-core
question. It exists to measure whether a future `ledgrcore` package is worth
building at all.

Status: scaffolding complete; measurement spec pending.

## Charter Source

The authoritative charter lives in ledgr's horizon:

- [`2026-05-30 [architecture] Compiled fold core as `ledgrcore` sister package`](https://github.com/blechturm/ledgr/blob/main/inst/design/horizon.md)
- the 2026-06-01 measurement-spike gate and repo-split updates inside that entry
- [`2026-06-01 [architecture] R-side data structures as shared substrate for compiled-core path`](https://github.com/blechturm/ledgr/blob/main/inst/design/horizon.md)

The four measurement numbers, decision-rule thresholds, and C++ vs Rust language
comparison framing are inherited from those entries.

## Package Name

The repository is named `ledgrcore-spike` to make the research status explicit.
R package names cannot contain hyphens, so the installed package name is
`ledgrcorespike`.

## Scope

This repository currently contains only the R package scaffold, cpp11 and
extendr toolchain stubs, and governance files. It has no runtime dependency on
ledgr. The measurement spec and compiled fold-loop implementation are deferred
to maintainer-authored follow-up work.

## License

MIT. See `LICENSE`.
