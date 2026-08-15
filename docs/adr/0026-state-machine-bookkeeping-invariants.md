# State-machine bookkeeping invariants: `op_completed`, `key_consumed`, `track_run` ordering (`patterns.lua`)

## Context

`patterns.lua`'s `seq` carries two per-call bookkeeping flags
(`op_completed`, `key_consumed`) and one per-keystroke counter
(`track_run()`) whose correctness depends on call-ordering rules that aren't
obvious from reading any single handler in isolation.

## Decision

- `op_completed` is set true only on the call that FRESHLY sets `last_op`,
  and is reset to `false` at the top of every `M.feed()` call. `logger.lua`'s
  usage-increment logic reads this flag rather than diffing `last_op`'s
  before/after value, because a value diff can't distinguish "the same
  compound completed again" from "nothing happened" — a diff-based approach
  undercounts back-to-back repeats like `dd dd` (`last_op` stays `'dd'`
  across both calls).
- `key_consumed` is set true when `M.feed` consumed the key as the second
  half of a compound. `logger.lua` uses it to skip standalone TRACK counting
  for that key, so a compound's second character isn't ALSO counted as a
  bare keystroke.
- `track_run()` must execute unconditionally on every key, including ones
  the jumplist/changelist blocks return early on (see
  `docs/adr/0019-jumplist-changelist-underuse-detection.md`) — skipping it
  for those keys freezes `seq.run`'s counter, so the next same-key press
  jumps the count forward by 2 instead of 1, firing consecutive-run
  patterns one press early. This was a live bug that
  `patterns_spec.lua`'s per-call assertions did not catch, since they check
  single calls rather than a frozen-then-jumped sequence across a
  multi-call boundary.

## Consequences

- Any new early-return branch added to `inner_feed` must be checked against
  these three invariants — in particular, a branch that returns before
  reaching `track_run()` needs to justify why it's safe to skip that
  keystroke's contribution to `seq.run`.

### Addendum: the invariant was violated by 9 more branches (#313, resolved by docs/adr/0115)

The `track_run()`-must-run-unconditionally invariant above was only actually
enforced for the jumplist/changelist keys it was written about. `inner_feed`'s
two-or-more-key prefix-consumer branches (`pending_r`, `pending_g`,
`pending_z`, `pending_mark`, `pending_bracket`, `pending_register`,
`pending_text_obj`, `pending_ctrl_w`, `pending_gq`, and the visual
text-object chain) all `return` before ever reaching `track_run()`, freezing
`seq.run` across the whole prefix instead of correctly reflecting the
resolving key — and the same freeze mechanism affected the tolerated-streak
families (`r_streak`/`ca_streak`/`ci_dquote_streak`/`ci_squote_streak`/
`fold_open_streak`/`fold_close_streak`) too, not just `seq.run`.
`docs/adr/0115-prefix-consumer-streak-bookkeeping.md` documents the fix (each
branch now calls `track_run()`/a new `reset_unclaimed_streaks()` helper at
its own resolution point) and the one deliberate exception
(`pending_text_obj`, which must NOT call `track_run()` — see that ADR for
why). Any new prefix-consumer branch must follow the same rule this
addendum's own history demonstrates was easy to miss: check against ALL
of `track_run()` and the tolerated-streak resets, not just the one this
ADR's original text called out by name.
