# Text-object variants get their own tracked usage, not just the shared op..'w' bucket (`patterns.lua`)

## Context

`patterns.lua`'s `pending_text_obj` handler always sets `seq.last_op = op .. 'w'`
once a text object completes (`ciw`, `ci"`, `di(`, …), on purpose — it feeds the
shared `cw`/`dw` compound buckets that `commands.lua`'s `ciw`/`diw` entries gate on.
But `commands.lua` also chains several text-object variants off of EACH OTHER's own
usage, not the shared bucket: `ci"` → `ciw`, `ci'` → `ci"`, `cib` → `ci"`, `ciB` →
`cib`, `cit` → `cib`, `cip` → `ciw`, `diw` → `ciw`. Since only the shared `cw`/`dw`
bucket ever incremented, every one of these seven entries' own `usage[cmd].count`
was permanently stuck at 0 — `find_best()`'s `usage[trigger].count > 0` eligibility
gate could never pass, no matter how often the user actually pressed `ci"` (#254).

Separately, while wiring this up, live-QA testing surfaced that `cit` could never
even be REACHED: `patterns.lua`'s `f`/`F`/`t`/`T` search-start handler ran before
`pending_text_obj`'s consumer, so the `t` of `cit` (inner tag) was reinterpreted as
the start of a fresh `t`-search instead of completing the pending text object —
the same class of collision fixed for `pending_register`/`pending_mark` in #257.

## Decision

- `pending_text_obj`'s handler additionally sets `seq.last_op_variant` to the
  variant's own registry key (e.g. `op='c'`, `inner=true`, `key='"'` → `'ci"'`),
  built as `op .. (inner and 'i' or 'a') .. key`, **in addition to** (not instead
  of) `seq.last_op = op .. 'w'`. This mirrors `op_completed`'s reset discipline
  (`docs/adr/0026-state-machine-bookkeeping-invariants.md`): `last_op_variant` is
  reset to `nil` at the top of every `M.feed()` call, and only ever set on the
  exact call that resolves `pending_text_obj`, so it can never be double-counted
  or leak into an unrelated later keystroke.
- Restricted to a small `TRACKED_TEXT_OBJ_CHARS` lookup (`w`, `"`, `'`, `b`, `B`,
  `t`, `p`) — the characters `commands.lua`'s registry actually chains off — rather
  than recording every character that happens to follow `i`/`a`. An accidental or
  unsupported text-object keystroke (e.g. `ciZ`) must not create a throwaway
  `usage.json` entry that no `requires` chain will ever read.
- `logger.lua` increments `seq.last_op_variant` alongside `seq.last_op` (via
  `seq.op_completed`) in the same `handle_key` block, so both buckets update from
  one keystroke.
- `pending_text_obj` was moved to run **before** the `f`/`F`/`t`/`T` handler in
  `inner_feed`'s dispatch chain — the same "two-key (or here, three-key) prefix
  consumer must precede f/F/t/T" rule already applied to `pending_g`/`pending_z`
  (see `lua/tobira/CLAUDE.md`) and to `pending_register`/`pending_mark`/
  `pending_bracket` (#257, `docs/adr/0026-state-machine-bookkeeping-invariants.md`).
  Without this, `cit`/`dit`/`yit` could never complete at all — not just an
  undercounted keystroke, but a corrupted `pending_f` state that also swallowed
  the next real keystroke, exactly like #257's register/mark bug.
- As a direct consequence, `ya"`/`ya'` (which require `ci"`/`ci'` respectively,
  `docs/adr/0012-reactive-only-direct-fire-entries.md`) also become genuinely
  trackable now that their own `requires` targets are — removed from
  `commands_spec.lua`'s `KNOWN_DEFERRED` list alongside the seven variants above.

## Consequences

- `ciw`, `ci"`, `ci'`, `cib`, `ciB`, `cit`, `cip`, and `diw` (and, as a side effect
  of #253 routing `y` through the same `pending_text_obj` path, `yiw`/`yi"`/etc.
  too) now have real usage data and can be surfaced by `find_best()`/
  `efficiency_gaps()` once actually used.
- Any FUTURE text-object variant added to `commands.lua`'s registry must also be
  added to `TRACKED_TEXT_OBJ_CHARS` (if it isn't already covered by an existing
  character) or its own count will silently stay stuck at 0 again, the same way
  the original seven were.
- Any new two/three-key prefix-continuation state added to `inner_feed` must be
  checked against the `f`/`F`/`t`/`T` ordering rule — see
  `lua/tobira/CLAUDE.md`'s "patterns.lua — state machine" section, which now also
  names `pending_register`/`pending_mark`/`pending_bracket`/`pending_text_obj` as
  handlers that must precede it.
