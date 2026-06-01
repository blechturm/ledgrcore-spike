# ledgrcore-spike Decision Log

## 2026-06-01 - Installed R package name

Question: Should `DESCRIPTION` use `Package: ledgrcore-spike` as written in one
prompt block, or `Package: ledgrcorespike` as implied by the namespace,
installed-package note, and requested build artifact?

Alternatives considered: keep the hyphenated package name and fail R package
validation; use `ledgrcorespike` as the installed package name while keeping the
repository name `ledgrcore-spike`.

Choice: use `Package: ledgrcorespike`.

Rationale: R package names cannot contain hyphens, and the prompt explicitly
states that the installed package name is `ledgrcorespike`.

## 2026-06-01 - Export cpp11 hello-world stub

Question: Should the cpp11 hello-world function be exported now, even though the
prompt's starter NAMESPACE only showed `useDynLib()`?

Alternatives considered: leave it unexported and only callable through `:::` or
export it so the definition-of-done command works.

Choice: export `ledgrcore_spike_cpp_hello`.

Rationale: The definition of done requires `library(ledgrcorespike); ledgrcore_spike_cpp_hello()` to work.

## 2026-06-01 - K1 fixture fill-count targeting

Question: How should the static rebalance strategy produce fill counts close to
the prompt's requested `large` (~13.5k) and `xlarge` (~130k) cells while staying
deterministic and simple enough for three implementations?

Alternatives considered: rebalance all instruments every 5 pulses, which
overshoots the requested fill counts; rebalance a proportional active subset
with alternating windows; tune per-scale active counts directly.

Choice: use per-scale active counts of 14, 27, and 259 instruments for small,
large, and xlarge, alternating between two disjoint active windows every 5
pulses.

Rationale: The chosen counts produce approximately 7.0k, 13.6k, and 130.3k
fills with a deterministic close/open stream and no fixture randomness.

## 2026-06-01 - K1 parity tolerance

Question: What numeric tolerance should the spike use when equity or numeric
event fields cannot be byte-identical because accumulation order differs?

Alternatives considered: require byte-identical doubles everywhere; use an
unspecified all.equal-style tolerance; inherit ledgr v0.1.8.9 L4's named
Kahan-vs-cumsum tolerance.

Choice: use `1e-8` only for Kahan-vs-cumsum-equivalent numeric parity
relaxations, while requiring exact event count, row order, integer fields, and
side codes.

Rationale: ledgr v0.1.8.9 L4 explicitly names `1e-8` as the valid tolerance
when the mechanism is Kahan compensated summation versus naive cumsum.

## 2026-06-01 - K1 fixture randomness

Question: Should the Stage 1 spec require pseudo-random bars to make the
synthetic fixture realistic?

Alternatives considered: use R RNG with a fixed seed; require a custom
cross-language PRNG now; use a closed-form deterministic price surface and
reserve pseudo-random noise for a later reviewed change.

Choice: specify a closed-form deterministic positive price matrix and retain
seed `20260601` for run ordering and any future fixture randomness.

Rationale: Closed-form prices avoid cross-language RNG drift while still
exercising the fold, accounting, and boundary costs the spike measures.
