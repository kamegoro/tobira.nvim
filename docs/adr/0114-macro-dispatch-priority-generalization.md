# Generalizing the macro-opportunity dispatch-priority exception (`beats_macro`)

## Context

`docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md` established
that `macro_result` (from `patterns.feed_macro()`) unconditionally wins
`logger.lua`'s dispatch priority over `result` (from `patterns.feed()`),
because a confirmed 3x repeated edit sequence is a rarer, bigger win than
any single-keystroke reactive pattern that happens to also match the same
final key. That ADR's own "Known limitation" section (resolved for #280)
already carved out one narrow exception: `named_mark_opportunity` wins over
`macro_result` specifically, because the only way that collision can occur
at all is when every edit in the repeated window lands on the same
returned-to line — exactly `named_mark_opportunity`'s own hypothesis, and a
weak, atypical case for macro's normal "same edit, different locations" use
case.

A systematic sweep (#312) found the identical mechanism recurring for
`dd_run`, `indent_run`, `dedent_run`, `r_run`, `fold_open_repeat`,
`fold_close_repeat`, `ci_dquote_repeat`, and `ci_squote_repeat`: each is
ITSELF a streak-completion pattern requiring 2-3 exact repetitions of a
short compound (`dd`, `>>`, `r{char}`, `zo`, `ci"`, …) — the very same shape
`macro_opportunity`'s own anchored-window algorithm (`docs/adr/0018`)
detects. Once a homogeneous run of the same short compound gets long enough
to also satisfy macro's 3x-repeat window, macro_opportunity keeps re-
matching on every subsequent repetition (not just the first collision), so
these patterns weren't merely delayed — they were silently starved
indefinitely: pressing `dd` 18 times in a row produced exactly one
`dd_run` notification instead of the 6 the streak should have re-armed and
fired.

Extending #280's fix as 8 more hardcoded one-off `logger.lua` exceptions
(`result.pattern == 'dd_run' or result.pattern == 'indent_run' or ...`)
would work, but every future pattern with the same shape (a repeat-count
streak over a short, specific compound) would need a human to remember to
add it to that list, or the same collision reintroduces silently — exactly
what happened here: 8 more instances of the identical mechanism, found only
because #312 went looking, not because anything caught the gap
structurally.

**#312's own sweep still missed two instances of its own mechanism**
(`ctrl_w_close_repeat`/`ctrl_w_resize_repeat` — #312's issue text lists both
as "confirmed SAFE"), found only during independent QA of the PR that
implemented this ADR. `<C-w>c`'s own `c` and `<C-w><`/`<C-w>>`'s own `<`/`>`
are `MACRO_EDIT_KEYS` members exactly like `dd`'s `d` or `r{char}`'s
implicit edit — a homogeneous `<C-w>c` (or `<C-w><`/`<C-w>>`) run long
enough to satisfy macro's 3x-repeat window silently starved these two
patterns the same way, undetected by the differential suite's `known_312`
bucket because that bucket is a non-failing catch-all by design (see
`tests/differential/patterns_seq_differential_spec.lua`'s own header). Both
now also declare `beats_macro = true`, bringing the total to 11 patterns.
This is itself the concrete illustration of this ADR's own "Consequences"
section below: opt-in declarations require a human to remember to check
every candidate, and #312's own investigation is proof that "structurally
can't collide" classifications need to be verified against the real
`MACRO_EDIT_KEYS` set, not just asserted.

## Decision

Replace the string-matched exception with a declared property on the
`patterns.feed()` return value itself: `beats_macro = true`. Each of the 9
confirmed-vulnerable patterns' return site now sets this field:

```lua
if seq.dd_streak >= 3 then
  seq.dd_streak = 0
  return { pattern = 'dd_run', cmd = '{n}dd', beats_macro = true }
end
```

`logger.lua`'s Normal-mode dispatch reads the field generically instead of
matching a pattern name:

```lua
local result_beats_macro = macro_result and result and result.beats_macro == true
local fired = (result_beats_macro and result) or macro_result or result or co_result
```

The knowledge of "this pattern is at least as strong evidence as macro's own
3x-repeat match, so it should win the collision" now lives right next to the
streak-threshold logic that defines the pattern in `patterns.lua`, not in a
separate list in `logger.lua` a future patterns.lua change has to remember
to keep in sync.

**Deliberately not a blanket "every `result` beats `macro_result`" flip.**
Reactive one-shot patterns (`zero_col_then_insert`, `dw_then_insert`,
`dd_then_p`, `x_then_insert`, …) are fired from a SINGLE prior keystroke, not
a counted repeat streak — for those, `macro_opportunity`'s confirmed 3x
edit-repeat genuinely is stronger evidence, and ADR 0016's original priority
still applies unchanged. Only the 9 patterns explicitly confirmed to share
macro's own "repeat a short compound N times" shape declare `beats_macro`.
A pattern that does not declare it and loses a same-keystroke collision to
`macro_opportunity` is not a bug — see `tests/differential/
patterns_seq_differential_spec.lua`'s mixed-corpus test, which found and
accepted exactly this for `dd_then_p`.

**Considered and rejected**: deferring `patterns.feed()`'s internal streak-
counter reset until `logger.lua` confirms it used the result (a rollback/
deferred-commit API), the other option ADR 0016's "Known limitation" section
already weighed for #280. This does not actually fix the observed bug on its
own: `macro_opportunity` keeps re-matching on every subsequent keystroke of
a long homogeneous run, so even with the counter preserved (not reset to 0),
the RECOMPUTED `dd_run` result would still lose the very next dispatch
decision and never reach the user. The fix has to change which result
`logger.lua` reports, not merely how `patterns.lua`'s internal state
survives a discarded call — so the priority-field approach is not a
narrower fallback here, it is the complete fix.

## Consequences

- `dd_run`/`indent_run`/`dedent_run`/`r_run`/`fold_open_repeat`/
  `fold_close_repeat`/`ci_dquote_repeat`/`ci_squote_repeat`/
  `named_mark_opportunity`/`ctrl_w_close_repeat`/`ctrl_w_resize_repeat` now
  correctly fire on every qualifying repetition, not just the first one
  before `macro_opportunity` arms.
  `macro_opportunity` can still legitimately fire on OTHER keystrokes in the
  same run that these patterns don't have an opinion about (e.g. between
  trio boundaries) — that's unrelated, correct behavior, not something this
  fix suppresses.
- A future pattern with the same "counted repeat of a short compound" shape
  must explicitly set `beats_macro = true` on its own return site to get
  this protection — it is opt-in, not automatic, so it still requires a
  deliberate decision (matching ADR 0016's own guidance that a new
  dispatch-priority-relevant pattern always needs one), but that decision is
  now made once, locally, at the point the pattern is defined, rather than
  requiring a separate edit to `logger.lua`'s arbitration logic.
- `docs/adr/0016`'s own "Known limitation" section is superseded by this
  ADR for the general mechanism; its narrative of the original #280
  investigation remains as historical record.
