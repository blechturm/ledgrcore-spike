# ledgr Context Index

This file records ledgr files read while scaffolding `ledgrcore-spike`.

| ledgr file path | Why read | What was used |
| --- | --- | --- |
| `inst/design/horizon.md` | Authoritative K1 charter and substrate framing. | Used the 2026-05-30 compiled-core entry, 2026-06-01 measurement-spike and repo-split updates, and 2026-06-01 R-side substrate entry to seed horizon, contracts, README, and agent guidance. |
| `inst/design/rfc_cycle.md` | Portable RFC cadence doctrine. | Copied/adapted into `inst/design/rfc_cycle.md` with repository-name adjustments only. |
| `inst/design/ledgr_roadmap.md` | Milestone shape reference. | Used the roadmap table style and authority wording for the single M1 roadmap. |
| `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/` | Example spike-round directory layout. | Used as reference for keeping spike artifacts under `inst/design/spikes/`; no files copied. |
| `inst/design/contracts.md` | Contract doctrine. | Used the contract-index shape and parity/determinism framing; no ledgr contract text copied wholesale. |
| `inst/design/architecture/` | Architecture notes layout. | Used as reference for an empty architecture-note directory. |
| `inst/design/adr/` | ADR format/location. | Directory expected by governance; left empty pending authored ADRs. |
| `DESCRIPTION` | R package metadata patterns. | Used author/package metadata style and Roxygen/testthat conventions. |
| `R/fold-engine.R` | R fold-loop shape the eventual measurement will mirror. | Read for reference only: pulse loop, strategy callback boundary, output-handler fill event boundary, and matrix close valuation informed scope language. Implementation not copied. |
| `R/fold-reconstruction.R` | Reconstruction and fill/equity materialization shape. | Read for reference only: event-to-equity/fills reconstruction and lot replay boundaries informed contracts language. Implementation not copied. |
| `R/lot-accounting.R` | FIFO machinery the eventual spike measures compiled-vs-R against. | Read for reference only: FIFO lot state and event application shape noted as future measurement context. Implementation not copied. |
| `AGENTS.md` | In-repo agent guidance conventions. | Used mission/contract/deferred-scope style for `CLAUDE.md` and `AGENTS.md`. |
| `CLAUDE.md` | Requested agent guidance reference. | File was not present in ledgr at scaffold time; root `AGENTS.md` was used instead. |
| `.gitignore` | Build-artifact ignore patterns. | Used R artifact and local-output conventions, then added Rust/C++ patterns from the scaffold prompt. |
| `.Rbuildignore` | Package-build ignore patterns. | Used design/dev/agent-file exclusion conventions, then added Rust-source exclusion from the scaffold prompt. |
| `LICENSE` | MIT license file format. | Matched ledgr's R-package MIT stub format while retaining the 2026 scaffold copyright year. |
