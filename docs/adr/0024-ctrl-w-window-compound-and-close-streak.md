# `<C-w>` window-command compound and close-streak detection (`patterns.lua`)

## Context

`<C-w>` starts Vim's two-key window-command prefix (`<C-w>s`/`v`/`w`/`h`/`j`/
`k`/`l`/`q`/`c`/`=`). A user who closes windows one at a time with `<C-w>q` or
`<C-w>c`, repeatedly, could instead use `<C-w>o` (keep only the current
window) in one step.

## Decision

- `pending_ctrl_w` uses the same dispatch-table shape as `pending_g`/
  `pending_z`, and must precede the `f`/`F`/`t`/`T` handlers in `inner_feed`
  for the same reason those do.
- `ctrl_w_close_streak` counts `<C-w>q` and `<C-w>c` interchangeably —
  either one, or alternating between them, 2+ times running — and then
  suggests `<C-w>o`. Any other `<C-w>‹key›` resets the streak.

## Consequences

- The close-streak threshold (2) is lower than most other streak patterns in
  this file (3) — see the inline comment at `ctrl_w_close_streak` for the
  exact trigger keys if this threshold needs revisiting.
