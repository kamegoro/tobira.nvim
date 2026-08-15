# Cross-pattern-module dispatch priority and same-key collisions (`logger.lua`)

## Context

`logger.lua` feeds the same physical keystroke into more than one detector at once,
and more than one of them can produce a suggestion for it:

- In the Normal-mode branch, `patterns.feed()` (`result`), `patterns_insert.feed_after_escape()`
  (`co_result`), and `patterns.feed_macro()` (`macro_result`) are all fed the same key.
  `<Esc>0i`, for example, matches both `patterns.lua`'s `zero_col_then_insert` (suggest
  `gI`) and `patterns_insert.lua`'s generic `insert_co_oneshot` (suggest one-shot
  `<C-o>`). Before an explicit priority existed, whichever call happened to run second
  in `handle_key`'s source order won by accident.
- Separately, the same raw byte means something different depending on mode: `<C-w>`
  is the Normal-mode window-command prefix but delete-word-back in Insert mode;
  `<C-n>`/`<C-o>` have their own unrelated Normal-mode meanings too. Recording both
  under one registry key would conflate two different user actions into one count.
- Macro-opportunity detection (`patterns.feed_macro`) itself spans the mode boundary:
  the repeated *edit* it watches for (e.g. `cwFooBar<Esc>`) includes the Insert-mode
  typed replacement text, not just the Normal-mode `c`/`w`/`<Esc>` around it — so it has
  to be fed from both `handle_insert_key` and the Normal-mode branch of `handle_key`.

## Decision

- **Explicit priority when multiple results exist for one keystroke:**
  `macro_result` wins over everything, then `result`, then `co_result`.
  - `macro_result` is checked first because it only fires after 3 full repetitions of
    an entire edit sequence — a rarer, bigger win than any single-keystroke pattern
    that happens to also match the same final key (retyping `cwFooBar<Esc>` 3 times
    also satisfies `patterns_insert.lua`'s `insert_completion_repeat` on that same
    `<Esc>`, but "you retyped this whole edit 3 times" beats "you retyped one word").
  - `result` (patterns.lua) wins over `co_result` (patterns_insert.lua) because
    patterns.lua's suggestions here are specific, single-purpose tips (`gI` for `0i`,
    `s` for `xi`, `A` for `$a`) that are objectively more direct than the generic
    "you could have stayed in insert mode" hint. `co_result` only fires when `result`
    is nil — the common case for motions with no competing specific pattern.
- **Same-byte, different-mode keys are recorded under separate composite registry
  keys**, gated on which mode's handler is actually consulting `INSERT_SPECIAL`/`TRACK`.
  Insert-mode `<C-o>` is counted under `i_<C-o>`, never the raw `<C-o>` key that
  `TRACK` (built from `commands.registry`) already claims for the Normal-mode
  jumplist-back meaning. This is safe because `INSERT_SPECIAL` is only ever consulted
  from `handle_insert_key`, once the mode cache already says Insert mode.
- **`seq.op_completed` (not a before/after value comparison on `seq.last_op`) gates
  compound-operator counting.** Two identical compounds back-to-back (`dd dd`, `dw
  dw`, …) reassign the same string to `last_op` — a value-change check would silently
  drop the second occurrence (the bug behind #119). `patterns.feed()` sets
  `op_completed` on the exact call that freshly completes an operator, regardless of
  whether the resulting string matches the previous one.
- **`seq.key_consumed` gates single-char `TRACK` counting**, so a key that was just
  consumed as the second character of a multi-key compound (`gj`, `zz`, `"a`, `]c`, …)
  is not also counted as a standalone keystroke.

## Consequences

- Adding a new pattern-producing call site to `handle_key`/`handle_insert_key` means
  deciding where it sits in this priority chain, not just wiring it in — an unplaced
  new result risks silently winning or losing races the way `co_result` used to.
- If a future key needs a Normal-vs-Insert (or Normal-vs-Terminal) split like
  `<C-w>`/`<C-n>`/`<C-o>`, it must follow the same "separate composite key, gated by
  which mode-specific table looks it up" shape — reusing the bare key for both
  meanings will silently conflate two different actions' counts.
- Lowering the compound-tracking check back to a value-comparison on `last_op`
  reintroduces the #119 undercount for repeated identical compounds.

### Known limitation (investigated in #265, resolved in #280)

`macro_result` winning over `result` can silently discard a `named_mark_opportunity`
that had already fired-and-reset internally. Repro: 3 "leave anchor → edit → return"
cycles using a byte-identical short edit each time (e.g. `x` every time) — the
identical-window match satisfies `macro_opportunity` (`patterns.feed_macro`) on the
exact same keystroke that `named_mark_opportunity`'s `mark_ready` branch
(`patterns.feed`) also fires on. Per this ADR's priority, `logger.lua` reports only
`macro_opportunity`; the caller never sees `named_mark_opportunity`. But
`patterns.feed`'s `mark_ready` branch has already unconditionally reset
`seq.mark_return_count`/`seq.mark_anchor_line` as a side effect of computing that
now-discarded return value — `logger.lua` cannot suppress this after the fact, since
`patterns.feed()` and `patterns.feed_macro()` are separate calls (`feed_macro` runs
second, so by the time its result is known, `feed`'s state mutation has already
happened). The user loses that specific `ma` suggestion and has to complete 3 more
full return cycles before it can fire again.

Confirmed reproducible; at the time deliberately left unfixed. A correct fix needs one
of: reordering `feed_macro()` before `feed()` and threading its result into `feed()` so
`mark_ready`'s reset can be made conditional (couples two entry points ADR 0018
explicitly keeps separate — `feed_macro`'s cross-mode buffer has nothing to do with
`inner_feed`'s normal-mode operator grammar), or a deferred-commit/rollback API on
`patterns.lua`'s mark-tracking state that only commits once the caller confirms it
actually used the result (new public surface, threaded through both the
normal-mode and insert-mode call sites of `feed_macro`). Both were judged more
invasive than this narrow, low-frequency collision (requires literally identical
short edits on every cycle) justified at the time.

**Resolution (#280):** rather than either `patterns.lua`-level option above, the fix
lives entirely in `logger.lua`'s existing arbitration, since `logger.lua` already
receives both `result` (`patterns.feed()`) and `macro_result` (`patterns.feed_macro()`)
independently for the Normal-mode branch of `handle_key`. The collision only ever
happens when every edit in the repeated window lands on the same returned-to line —
exactly `named_mark_opportunity`'s own specific, already-confirmed hypothesis ("you
keep returning to this exact spot"). `macro_opportunity`'s real value is the same edit
applied across *different* locations; once the location is confirmed identical on
every repetition (the only way this collision can occur at all), it is actually a
weak, atypical fit for macro's normal use case. So when `macro_result` and `result`
are both ready on the same keystroke *and* `result.pattern == 'named_mark_opportunity'`,
`named_mark_opportunity` now wins instead of `macro_result`. This is a narrow,
one-pair-only exception: `macro_result` still wins over `result` for every other
pattern, exactly as the unqualified priority above states. `patterns.feed()`'s
`mark_ready` reset is unaffected (and still unconditional) — the fix only changes
which already-computed result `logger.lua` reports, not `patterns.lua`'s internal
state machine, so neither invasive option above was needed after all.

### Addendum: the one-pair exception generalized (#312, resolved by docs/adr/0114)

A systematic sweep found 8 more pattern pairs sharing the identical collision
mechanism (`dd_run`, `indent_run`, `dedent_run`, `r_run`, `fold_open_repeat`,
`fold_close_repeat`, `ci_dquote_repeat`, `ci_squote_repeat` vs.
`macro_opportunity`) — each is itself a same-family repeat-count streak
completion, the same shape as `named_mark_opportunity` above, just not yet
caught. Rather than growing this section into 9 hardcoded one-pair
exceptions, `docs/adr/0114-macro-dispatch-priority-generalization.md`
replaces the `result.pattern == 'named_mark_opportunity'` string match with
a declared `result.beats_macro = true` field, set at each of the 9
patterns' own return sites (including `named_mark_opportunity`'s). See that
ADR for the full mechanism and why a blanket "every `result` beats
`macro_result`" flip was deliberately rejected — the unqualified priority
this ADR states above still holds for every pattern that does not declare
`beats_macro`.

That same sweep's own "confirmed SAFE" list turned out to still contain two
false negatives — `ctrl_w_close_repeat`/`ctrl_w_resize_repeat` share the
identical mechanism too (`<C-w>c`'s `c` and `<C-w><`/`<C-w>>`'s `<`/`>` are
all `MACRO_EDIT_KEYS` members), found only during independent QA of the PR
implementing `docs/adr/0114`. Both now also declare `beats_macro = true` —
see that ADR's own addendum for detail. The total is 11 patterns, not 9.

### Addendum: cross-mode `feed_macro` calls now distinguish their source (#334, resolved by docs/adr/0116)

The cross-mode `feed_macro` call this ADR describes above (fed from both
`handle_key`'s Normal-mode branch and `handle_insert_key`) used to feed both
call sites' raw characters through the identical `MACRO_EDIT_KEYS` check,
letting an ordinary insert-mode-typed word anchor-match `macro_opportunity`
purely by letter coincidence with the Normal-mode operator alphabet. See
`docs/adr/0116-macro-edit-keys-mode-source-distinction.md` for the
`is_normal_key` parameter that now gates this — the cross-mode call still
exists exactly as designed here, but the two call sites are no longer
indistinguishable to `feed_macro`'s own edit-key content check.
