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
  `docs/adr/0010-jumplist-changelist-underuse-detection.md`) — skipping it
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
