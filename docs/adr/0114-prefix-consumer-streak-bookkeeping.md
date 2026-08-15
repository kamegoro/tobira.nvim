# Prefix-consumer branches must run streak bookkeeping too

## Context

`docs/adr/0026-state-machine-bookkeeping-invariants.md` establishes that
`track_run()` (the shared `seq.run` counter behind `j_repeat`/`l_repeat`/
`w_repeat`/etc.) "must execute unconditionally on every key." That
invariant was already enforced for the jumplist/changelist keys, but
`inner_feed`'s early-return prefix-consumer branches — `pending_r`,
`pending_g`, `pending_z`, `pending_mark`, `pending_bracket`,
`pending_register`, `pending_text_obj`, `pending_ctrl_w`, `pending_gq`, and
the visual text-object chain — each `return` before ever reaching the
`track_run()` call near the bottom of `inner_feed`, and before the
tolerance-reset checks for `r_streak`/`ca_streak`/`ci_dquote_streak`/
`ci_squote_streak`/`fold_open_streak`/`fold_close_streak` that live in the
same unreached tail region.

Confirmed repro (#313): repeating `rXl` (replace-with-X, move right) 20
times spuriously fired `l_repeat` after only 5 NON-consecutive `l` presses,
because the `r`/`X` keys never touched `seq.run` — they were consumed by
`pending_r`'s own early return, leaving `seq.run` frozen at whatever it was
before. The next `l` press then jumped the count forward as if the
intervening keys had never happened.

The same freeze mechanism affects the OTHER families too, not just
`seq.run`: e.g. an unrelated `<C-w>c` compound pressed between two
`r{char}` replacements left `r_streak` itself frozen (surviving instead of
resetting), letting `r_run` fire on what should have been an interrupted,
non-qualifying streak. A worse, chained case: `'0'` sets `seq.run.key =
'0'`; a `<C-w>>` resize compound resolves via `pending_ctrl_w` and returns
before `track_run()` runs, so `seq.run.key` is STILL `'0'` afterward; the
next bare `'w'` then spuriously matches the unrelated `"0 → w"` reactive
check (`zero_then_w`), which ALSO returns early — skipping the ordinary
bottom-of-function reset that `'w'` should have applied to
`ctrl_w_resize_streak`. Two chained hops of the identical root cause.

## Decision

Each of the 9 prefix-consumer branches now calls `track_run(seq, key)`
and/or a new `reset_unclaimed_streaks(seq, key, except)` helper at the point
it resolves (consumes the key completing its own compound), not just at the
literal bottom-of-function fallthrough:

```lua
local function reset_unclaimed_streaks(seq, key, except)
  if except ~= 'r' and key ~= 'h' and key ~= 'l' then
    seq.r_streak = 0
  end
  if key ~= 'j' and key ~= 'k' then
    seq.ca_streak = 0
  end
  if not CI_QUOTE_NAV_KEYS[key] then
    if except ~= 'ci' then
      seq.ci_dquote_streak = 0
      seq.ci_squote_streak = 0
    end
    if except ~= 'fold' then
      seq.fold_open_streak = 0
      seq.fold_close_streak = 0
    end
  end
end
```

`except` names the ONE family (if any) the calling branch already manages
inline for this exact key, so the generic reset doesn't immediately undo an
increment the branch just made:

- `pending_r`'s own resolution increments `r_streak` itself → calls with
  `except = 'r'`.
- `pending_z`'s `zo`/`zc` targets manage `fold_open_streak`/
  `fold_close_streak` inline → calls with `except = 'fold'`.
- `pending_text_obj`'s `ci"`/`ci'` completion manages `ci_dquote_streak`/
  `ci_squote_streak` inline → calls with `except = 'ci'`.
- Every other branch (`pending_g`, `pending_mark`, `pending_bracket`,
  `pending_register`, `pending_ctrl_w`, `pending_gq`, and the visual
  text-object chain's resolving key) owns none of these families, so calls
  with no exception.

`track_run(seq, key)` is called unconditionally from every one of these
branches EXCEPT `pending_text_obj`'s resolution. That one exception is
deliberate: the `d`/`c`/`y` operator start that always precedes
`pending_text_obj` already unconditionally wipes `seq.run` to `{key = nil,
count = 0}` at its own starter (pre-existing, unrelated to this bug), so a
stale pre-compound value can never survive through to a text-object
completion the way it can for `pending_r`/`pending_ctrl_w`/etc. (whose own
starters do NOT reset `seq.run`). A pre-existing, deliberate regression test
(`patterns_spec.lua`, "does not leak the w of yiw into the bare-motion run
streak") also asserts text-object completions must NOT count as a bare `w`
keystroke for `w_repeat`'s own purposes — calling `track_run()` there would
have reintroduced that already-fixed defect.

## Consequences

- `seq.run` (and the tolerated-streak families) now correctly reflect the
  most recent key even when that key resolved a two-or-more-key prefix,
  instead of silently freezing across the whole compound.
- The `dd`-vs-`ctrl_w` chained cascade above no longer reproduces:
  `pending_ctrl_w`'s resolution updates `seq.run` directly, so a later bare
  key can never spuriously match a stale reactive one-shot check the way
  `zero_then_w` did.
- A future new two-or-more-key prefix consumer must decide, the same way
  the 9 branches here did, whether it owns any of the tolerated families for
  its own resolving key (pass that family as `except`) and call
  `reset_unclaimed_streaks`/`track_run` accordingly — this is not fully
  automatic; `lua/tobira/CLAUDE.md`'s "patterns.lua — state machine" section
  documents the rule for new prefixes.
- `tests/differential/reference_model.lua`'s own `reset_other_families`
  helper is deliberately a STRICT SUPERSET of what this fix resets (it also
  resets at prefix STARTERS, not just resolvers) — the differential suite's
  `known_313`-classified divergence bucket tolerates this remaining gap
  between the reference model's more aggressive reset and the real, narrower
  fix, since it only ever affects the exact TIMING of an already-tracked
  pattern, never introduces a wrong pattern name.
