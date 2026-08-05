# `<C-w>+`/`<C-w>-`/`<C-w><`/`<C-w>>` resize streak → `<C-w>=` (#231)

## Context

`<C-w>=` (equalize all window sizes) was already registered in `commands.lua` but had no
reactive detection pattern. A user manually nudging window sizes back to something
reasonable with `<C-w>+`/`<C-w>-`/`<C-w><`/`<C-w>>`, repeated or alternated, is the same
"doing it the hard way" shape `ctrl_w_close_streak` (`<C-w>q`/`<C-w>c` × 2 →
`<C-w>o`, ADR 0024) already covers for closing windows — `<C-w>=` resets everything to
equal in one keystroke instead.

Both streaks share the same `pending_ctrl_w` two-key dispatch table, so the risk is the
two streaks' bookkeeping bleeding into each other: does pressing a resize key reset an
in-progress close streak, and vice versa?

## Decision

- Added `+`/`-`/`<`/`>` to the existing `ctrl_w_targets` dispatch table alongside
  `q`/`c`/`=`/etc., mirroring `<C-w>c`'s own precedent of not needing a `commands.lua`
  registry entry — these four keys are only ever used as internal `last_op` tokens for
  usage-increment bookkeeping (`logger.lua`'s `increment()` writes directly to the usage
  table by string key, no registry lookup required), never as a pattern's returned `cmd`.
  The actual suggested command, `<C-w>=`, is already registered.
- `ctrl_w_resize_streak` is a **separate counter field** from `ctrl_w_close_streak`, not a
  shared one. Each branch of the dispatch table explicitly zeroes the other streak's
  counter when it advances its own (a close key resets the resize count and vice versa),
  and any unrecognised or unrelated `<C-w>` target zeroes both. This guarantees the two
  streaks can never accidentally combine presses from one family into a fire for the
  other.
- Threshold is 2, matching `ctrl_w_close_streak`'s own threshold (ADR 0024) rather than
  the 3 most other streaks in this file use — same reasoning as that ADR: window commands
  are struck deliberately and rarely accidentally, so a lower threshold is safe here.

## Consequences

- Touching `pending_ctrl_w`'s dispatch table now means touching two independent streak
  counters, not one — a future third `<C-w>` streak family should follow the same
  "own counter, explicit cross-reset" shape rather than trying to reuse either existing
  counter.
- `<C-w>+`/`<C-w>-`/`<C-w><`/`<C-w>>` remain unregistered in `commands.lua` on purpose,
  same as `<C-w>c` — see `commands_spec.lua`'s `KNOWN_DEFERRED`-adjacent reasoning for why
  this is fine (they're evidence-only, never a suggestion's own `cmd`).
