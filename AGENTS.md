# ledgrcore-spike Agent Notes

This repository measures compiled fold cores against post-v0.1.8.10 production
R per ledgr's K1 charter. It is a scaffolded research spike, not a production
package and not a fork of ledgr.

## Authority

ledgr's `inst/design/horizon.md` K1 entries are authoritative, especially
`2026-05-30 [architecture] Compiled fold core as `ledgrcore` sister package`
and the 2026-06-01 measurement-spike, repo-split, and R-side substrate updates.
This repository's `inst/design/horizon.md` is a context-local parking lot.

## Cross-Repo Context

The ledgr repository is at `c:/Users/maxth/Documents/GitHub/ledgr`. Read it for
context as needed and document every ledgr file read in
`inst/design/ledgr_context_index.md`.

## Discipline Rules

Use the same RFC cycle as ledgr: seed, response, synthesis, final review, with
maintainer authority over product choices. This repo is pre-CRAN and
pre-production; break scaffold internals freely when the measurement spec later
requires it, but keep the audit trail clear.

## Spike Cadence

The K1 measurement work lives outside ledgr because Rust/C++ FFI iteration is
slower than the 1-3 day R-side spike cadence. If a future measurement spec uses
a seven-spike cadence or another shape, follow the spec and document the choice
in the decision log.

## Out Of Scope

Do not turn this into a production R package during the scaffold phase. Do not
start reimplementing ledgr. Do not add a runtime dependency on ledgr. Do not
write the measurement spec or compiled fold loop until the maintainer authors the
spec.
