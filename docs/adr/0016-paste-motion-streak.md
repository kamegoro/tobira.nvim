# Cursor-skip-past-paste detection: `p`/`P` → `gp`/`gP` (`patterns.lua`)

## Context

After pasting (`p`/`P`), the cursor lands before the pasted text. If the user
then moves past it with plain rightward motions (`l`/`w`/`W`/`e`/`E`/`$`)
three times, `gp`/`gP` (paste, then leave the cursor right after the pasted
text) would have done that in one step.

## Decision

- Checked FIRST in `inner_feed`, before any other handler, so it observes
  every key that follows a paste — including keys other handlers would
  otherwise consume (`g`, `"`, `m`). If it ran later, those handlers would
  consume the key before this observation ever saw it.
- Unlike the other `pending_*` handlers in this file, this does NOT return
  early on a non-firing key: rightward motions still fall through to their
  own patterns (`l_repeat`, `w_repeat`, ...), and non-motion keys just
  cancel the streak and fall through too — it observes without consuming.
- `p`/`P` re-presses are exempted from cancelling the streak, so
  `p_repeat`/`P_repeat` (the separate "pressed `p`/`P` 3×" pattern) are
  unaffected by this tracking.

## Consequences

- Any future "observe without consuming" pattern added to the front of
  `inner_feed` should follow this same non-early-return shape — returning
  early there would silently break whichever pattern normally handles that
  key.
