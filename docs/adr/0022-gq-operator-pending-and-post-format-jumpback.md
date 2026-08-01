# `gq` operator-pending tracking and post-format jump-back detection (`patterns.lua`)

## Context

`gq` (the format operator) is a real Vim operator requiring a further motion
(`gqq`, `gqap`, `gq}`) before it's complete — unlike the simple two-key
`pending_g` targets (`gg`, `gj`, `gd`, …), which are complete two-key
commands on their own.

Separately: a user who `gq`-formats text and then manually jumps back to
where they started (via `<C-o>` or `` `` ``, backtick-backtick) is doing by
hand exactly what `gw` (format-and-return) does in one step — a second
suggestion opportunity riding on the same operator.

## Decision

- `pending_gq` mirrors `pending_op`'s `d`/`c` shape (count prefix,
  text-object prefix, linewise double, or a plain motion char) but always
  collapses to `last_op = 'gq'` — nothing downstream needs to know which
  motion was used, only that a format operation completed.
- `pending_gq`/`pending_gq_text_obj` handling must precede the `f`/`F`/`t`/`T`
  handlers in `inner_feed`, same as `pending_g`/`pending_z`/`pending_ctrl_w`
  — otherwise a motion like `gqf{char}` would be consumed as the start of an
  f-search instead of `gq`'s motion.
- `gq_then_jumpback` (suggest `gw`) fires from two different post-`gq`
  return paths:
  1. `<C-o>` immediately after `last_op == 'gq'` — a direct check, since
     `<C-o>` is already a complete "jump back" command on its own.
  2. `` `` `` (backtick-backtick) — needs `pending_gq_backtick`, a one-key
     lookahead flag set only when the mark-prefix key (`` ` ``) is pressed
     while `last_op == 'gq'`. This lets `pending_mark`'s resolution tell
     "`` `` `` right after `gq`" apart from an unrelated "`` `a `` (jump to
     mark `a`)".

## Consequences

- Both jump-back paths must stay in sync if `gw`'s trigger condition ever
  changes (e.g. a third "jump back" input is added).
- `pending_gq_backtick` only ever survives exactly one key — it is consumed
  at `pending_mark`'s resolution regardless of outcome, so it can never leak
  into an unrelated later mark-jump.
