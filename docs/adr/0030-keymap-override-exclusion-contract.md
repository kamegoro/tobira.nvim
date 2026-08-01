# Keymap-override exclusion is plain-data, applies regardless of equivalence, and graph.lua stays integrations-agnostic

## Context

`integrations.lua` detects the user's own `:nmap`/`:nnoremap` overrides (#63)
via `nvim_get_keymap`. Two proactive suggestion surfaces need to honor that
data: `find_best()` (the idle picker and `:Tobira` manual pick) and, later,
`efficiency_gaps()` (`:TobiraStats`'s "Try these next" panel, #164), which
does not route through `find_best()`'s gates at all and so needed its own
copy of the same filter rather than inheriting one for free.

`core/graph.lua` is required to stay pure Lua with no `vim.*` calls and no
`require('tobira.core.integrations')` (see `lua/tobira/CLAUDE.md`'s module
dependency rules) — that's what keeps it unit-testable without a running
Neovim instance and keeps the dependency graph acyclic (`integrations.lua`
itself requires `commands` + `config`, and must never be required back by the
module beneath it).

The other design question was what counts as "remapped": `nnoremap Y y$`
produces a remap that is functionally identical to what tobira would
otherwise teach for `Y` (`commands.lua` already documents `Y` as "same as
`y$`"). Proactively suggesting "learn `Y`" to a user who already deliberately
bound `Y` to run `y$` teaches nothing new even though the two are equivalent
— the user has already established the association themselves, just via a
different key.

## Decision

- Both `find_best()` and `efficiency_gaps()` accept an `overrides` parameter
  shaped as `cmd -> { rhs, equivalent }`, built by `integrations.lua` and
  passed in as plain data. `graph.lua` never requires `integrations.lua` —
  it only ever reads this table's shape, so it stays pure and
  integrations-agnostic either way.
- Any candidate whose own key appears as an `overrides` key is excluded from
  the pool entirely, **regardless of the `equivalent` field** — a remap being
  functionally equivalent to tobira's own suggestion does not change the
  exclusion.
- The `equivalent` field is deliberately not read by either function. The one
  place it does matter is `ui/guide.lua`'s persistent cheat-sheet, which
  bypasses `find_best()` entirely and needs to render "you've already bound
  this, differently" vs. "you've already bound this, to the same effect" as
  distinct rows.

## Consequences

- A new proactive suggestion surface added later must apply this same
  `overrides` filter itself — it is not inherited for free just by reading
  from `graph.suggestions` or `commands.registry`.
- If a future feature needs the `equivalent` distinction outside
  `ui/guide.lua`, that's a sign the distinction is becoming find_best-level
  concern and this ADR's "proactive surfaces don't care" assumption should be
  revisited, not silently special-cased.
