# Ambient exclusion for reactive-only, structurally-untrackable commands

## Context

`graph.find_best()` is the single candidate pool behind both the idle picker and
`:Tobira` manual — every registry entry with a `requires` field is fair game unless
opted out. `<C-\><C-n>` (exit terminal mode, #110) is detected reactively by
`patterns_terminal.lua` only while `mode() == 't'`, with no real "you opened
`:terminal`" prerequisite to require. Its `requires = 'i'` is a nominal anchor that
exists only to satisfy `commands_spec.lua`'s schema guard (every non-compound entry
must have some `requires`).

Left in the ambient pool as-is, this entry would be actively broken two ways at once:

- Its suggestion body presupposes the user is stuck in a terminal buffer right now.
  Surfacing it from the idle picker off of bare `i` usage, with no `:terminal` ever
  opened, would be a suggestion that makes no sense in context.
- Its own usage count can never be incremented by anything — nothing in
  `logger.lua` ever marks this command as "used". `find_best()` scores candidates by
  `trigger_count - own_count`; a count permanently stuck at 0 makes this entry's
  score the best possible for any `i`-triggered candidate, so it would dominate
  ambient suggestions from `i` alone forever, not just occasionally.

## Decision

Add an `ambient = false` field, read by `graph.find_best()` to exclude an entry from
its candidate pool entirely (idle picker and `:Tobira` manual both). Reserve it
narrowly for entries that are **both**:

1. reactive-only — the suggestion only makes sense as a direct reply to a
   just-detected pattern, never as a proactive idle-time nudge, and
2. structurally unable to ever earn a real usage count of their own.

`<C-\><C-n>` is the only entry marked this way. The insert-mode `<C-w>` entry has
the same nominal `requires = 'i'` anchor shape, but its own count genuinely
increments (see the composite-key ADR) and its body doesn't presuppose a prior
event — ambient surfacing is legitimate for it, so it is deliberately not included.
`commands_spec.lua`'s "reactive-only ambient exclusion" test pins the exclusion set
down as an explicit, reviewable list (`assert.are.same({ '<C-\\><C-n>' }, ...)`)
rather than a silently-inferred rule.

## Consequences

- Adding a new `ambient = false` entry requires writing out the same two-part
  reasoning next to it in `commands.lua`, not just flipping the flag — and updating
  the `commands_spec.lua` assertion list, which will fail closed (not silently pass)
  if a new exclusion is added without updating the test.
- A command whose count can be incremented (even indirectly) should not use this
  flag — reach for a different design (e.g. tightening its `requires` chain) instead.
- See `docs/adr/0008-substitute-repeat-ampersand-escalation.md` for a superficially
  similar entry (`g&`) that was deliberately **not** given this flag, and why.
