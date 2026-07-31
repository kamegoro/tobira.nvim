# Register-underuse promotion bypasses the generic trigger-count threshold (#59)

## Context

The generic promotion rule in `graph.find_best()` is "the `requires` command's
usage count crosses a threshold" — e.g. `cw` gets suggested once `dw` has been used
enough times. `"+y"` (yank to the system clipboard register) doesn't fit this
model: it isn't gated behind some *other* command being used a lot, it's gated
behind the user using the **plain, unnamed-register** `y` a lot while *never*
reaching for a named/system register — the interesting signal is an absence
(register underuse), not a presence (motion mastery).

`"+y"` is also not a single-keystroke command to begin with — it's the 3-key
literal sequence `"+y`, tracked as its own compound by `patterns.lua`'s
`pending_clipboard_yank` state, not by the generic operator grammar or a bare
keystroke.

There's also no dedicated "register" category in the category taxonomy (a closed
enum — see `lua/tobira/CLAUDE.md`), and registers/marks are already grouped
together in the project's own design notes, so `"+y"` uses `category = 'mark'` as
the closest existing bucket rather than adding an eighth category for one entry.

## Decision

- `requires = 'y'` stays as the nominal chain anchor (satisfies the schema guard,
  matches the "what manual behavior does this replace" convention used everywhere
  else in the registry), but promotion is **not** gated by `y`'s trigger count.
  `graph.is_register_underused()` implements a purpose-built check instead, and
  `find_best()` special-cases this one command to consult it rather than the
  generic threshold.
- `track = false`: the 3-key sequence is recorded by `patterns.lua`'s
  `pending_clipboard_yank`, not the generic single-keystroke TRACK table.
- `category = 'mark'`: reuse the existing register/mark bucket rather than invent a
  new top-level category for a single entry.

## Consequences

- Reading `find_best()` in isolation, `"+y"` looks like an ordinary
  `requires`-gated suggestion; its actual gate lives in
  `graph.is_register_underused()` and must be read there, not inferred from the
  registry entry alone.
- A future "you have a habit but never use the tool for it" suggestion (the same
  absence-based shape as this one) is a candidate for the same
  special-cased-threshold pattern rather than forcing a presence-based `requires`
  count to represent an absence.
