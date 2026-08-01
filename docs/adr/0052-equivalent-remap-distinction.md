# Curated equivalent-remap table for Y = y$ (#63, #103)

## Context

Vim's real built-in `Y` is a synonym for `yy` (linewise, the whole line) — **not** `y$`.
But `commands.lua`'s own `Y` suggestion body documents the *y$* meaning ("same as y$"),
because that's only true once the user has personally remapped `Y` that way
(`nnoremap Y y$`), which is one of the most common personal remaps (added for
consistency with `D = d$` / `C = c$`).

This creates an ambiguity `integrations.lua` has to resolve: once phase 1 detects that
`Y` has been remapped at all, is that remap something to warn about (the general case —
"this key doesn't do what tobira's suggestion text says anymore") or something to
_still_ teach, just with different wording (this specific, common remap teaches exactly
what the suggestion body already describes)? Treating every override identically would
either wrongly show the `y$`-flavored `Y` suggestion to a user who never remapped it, or
wrongly hide/flag it as broken for the very users whose remap makes the suggestion
correct — this was the #103 bug.

## Decision

Add a curated `EQUIVALENT_REMAPS` table: `cmd -> { accepted rhs literal(s) }`. A remap is
"equivalent" only if its rhs exactly matches one of the curated literals for that cmd —
`Y` is the only (seed) entry, accepting only `rhs == 'y$'`. Any other remap of `Y` (even
something superficially Y-shaped like plain `yy`), and any remap of a key with no entry
in the table at all, falls through to "not equivalent" — i.e. a genuinely different
remap (like a `<Plug>` mapping to an unrelated plugin command).

`is_equivalent_override(cmd)` exposes this distinction so `ui/guide.lua`'s Pinned-section
renderer can still show the row (with substituted wording) instead of hiding it outright
the way a genuinely different remap is hidden.

## Consequences

- Adding a new equivalent-remap entry means asserting the *exact* rhs literal(s) that
  count, not a fuzzy or partial match — matching too loosely silently misclassifies a
  different remap as safe to still teach.
- `graph_spec.lua` / `ui_guide_spec.lua` cover how the equivalent/different distinction
  is actually consumed; a change here should keep those green, not just this module's
  own tests.
- This table is deliberately small and curated by hand — it is not meant to grow into a
  general remap-similarity heuristic. A new entry should be added only when a remap is
  common enough and unambiguous enough (like `Y = y$`) to be worth hardcoding.
