# A separate priority pool for candidates that bypass the ordinary trigger-count gate

## Context

Two features need `find_best()` to offer a candidate even though its trigger
hasn't been used the ordinary way:

- The system-clipboard nudge (`"+y`, #59): once the user has yanked (`y`)
  heavily but never once used the `"+y` register, this is worth suggesting
  even though `"+y` has no `requires`-style trigger count of its own to score
  against.
- Plugin-detected promotions from `integrations.lua` (#63 phase 2): a
  candidate the integrations layer has independently verified usage evidence
  for should skip the generic "trigger used at least once" requirement.

The first implementation of the `"+y` nudge added a fixed `+1000` boost
directly to `usage.y.count` before scoring. That approach cannot work in
general: an ordinary score (`trigger_count - cmd_count`) grows with the raw
trigger count, which routinely reaches the thousands for a real long-term
user, so no fixed constant can outrace an unbounded competitor forever
(regression-tested against `j` counts of 1030 and 50000 — both would
eventually have beaten a fixed `+1000` boost).

## Decision

Both cases are collected into a separate `best_priority_cmd` /
`best_priority_score` pool inside `find_best()`, checked and returned first
if non-empty, falling back to the ordinary pool only when it's empty. This
makes "a qualified priority candidate always wins" true by construction
(it's checked first, unconditionally) rather than by arithmetic (no boost
value to out-grow).

`is_register_underused()` gates the `"+y` case on
`REGISTER_UNDERUSE_TRIGGER = 20` (`y` count) and zero `"+y` uses. Only this
clipboard heuristic is implemented; the same issue's "wrong paste" and
register-0 heuristics are deliberately deferred pending a separate design
review (see the issue's own "Phase 2 (later, needs discussion)" section) —
this ADR covers only what's actually built.

Both the `"+y` pool entry and a `promotions[cmd]` pool entry still have to
pass every other ordinary gate first (mastery, suppression, shown-count cap)
— only the trigger-count requirement is bypassed.

## Consequences

- Any future gate-bypassing candidate should reuse this same priority-pool
  mechanism rather than inventing another additive score boost — the boost
  approach is a proven dead end once a real trigger count gets large enough.
- Extending register-underuse detection beyond the clipboard case requires
  the deferred design review first; don't fold new heuristics into
  `is_register_underused()` without it.
