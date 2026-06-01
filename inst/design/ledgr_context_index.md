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
| `inst/design/horizon.md` | Stage 1 K1 measurement authority. | Re-read the 2026-05-30 K1 entry, 2026-06-01 measurement-spike gate, repo-split update, and R-side substrate entry to bind `inst/design/spikes/k1_measurement_spike/spec.md`. |
| `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md` | Authoritative Round-3 substrate decision for the post-v0.1.8.10 R baseline. | Used L7 Ticket 2 and L9 to require fold-owned FIFO accounting in the minimum measurement loop and to document substrate-expansion as the reason. |
| `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md` | Kahan-vs-cumsum tolerance doctrine. | Used L4 to set the parity relaxation mechanism and tolerance at `1e-8`, with mechanism named explicitly. |
| `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/README.md` | LDG-2479 workload-grid context search. | Reviewed matched scale references for context; Stage 1 scale values came from the execution prompt. |
| `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/spike_tickets.md` | LDG-2479 workload-grid context search. | Reviewed matched scale references for context; not otherwise used. |
| `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/tickets.yml` | LDG-2479 workload-grid context search. | Reviewed matched scale references for context; not otherwise used. |
| `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/codex_substrate_decision_review.md` | Substrate-decision context search. | Reviewed matched fold-owned-accounting context; authoritative wording came from `architecture_synthesis.md`. |
| `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis_codex_review.md` | Workload-grid and substrate-decision context search. | Reviewed matched context; not used as binding authority for the Stage 1 spec. |
| `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/README.md` | Kahan tolerance and LDG-2479 context search. | Reviewed matched tolerance and scale references; L4 architecture synthesis supplied the binding tolerance wording. |
| `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/spike_tickets.md` | Kahan tolerance and LDG-2479 context search. | Reviewed matched tolerance and scale references; not otherwise used. |
| `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/tickets.yml` | Kahan tolerance and parity context search. | Reviewed matched parity references; not otherwise used. |
