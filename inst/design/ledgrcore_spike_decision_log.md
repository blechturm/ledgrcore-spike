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
