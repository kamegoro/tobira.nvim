# `diw_then_insert`: giving the `diw` text-object variant its own reactive suggestion (`patterns.lua`)

## Context

`patterns.lua`'s operator-pending grammar deliberately normalizes every charwise
`d`-completion — `dw`, `d3w`, `diw`, `daw`, `di"`, `da(`, … — down to the same
`seq.last_op = 'dw'` value (see `lua/tobira/CLAUDE.md`'s "patterns.lua — state
machine" section). `dw_then_insert` reads exactly that shared value: whenever
`last_op == 'dw'` and the next key enters insert mode, it suggests `cw`.

That collapse is correct for the `_then_insert` family's original purpose — `dw`,
`d3w`, `daw`, and `di"` really do all become `cw`/`c3w`/`caw`/`ci"` respectively, so
one shared reactive check covering the whole bucket is the right level of
generality. But `diw` specifically is not just "some dw-shaped deletion" — the user
explicitly reached for the inner-word text object (`d` `i` `w`, three separate
keystrokes) rather than a bare or counted motion. `commands.lua` already treats
`diw` as tracked separately from the shared `dw` bucket for usage-counting purposes
(`docs/adr/0106-text-object-variant-own-usage-tracking.md`'s `last_op_variant`
field), and its own registry entry (`diw` → requires `ciw`) exists precisely
because `diw`/`ciw` are the more precise, more idiomatic pair for this exact
edit. Suggesting the generic `cw` when the user already typed `diw` is a weaker
answer than suggesting `ciw`, which matches what they typed keystroke-for-keystroke
and (unlike `cw`) also works correctly with the cursor mid-word — see issue #298,
filed independently against hardtime.nvim's own tracker for the identical gap.

`last_op_variant` itself can't be reused directly here: it is deliberately
single-shot, reset to `nil` at the very top of every `M.feed()` call (so
`logger.lua` can increment it exactly once per completion without double-counting),
which means it is already `nil` again by the time the *next* keystroke (the one
entering insert mode) is dispatched. `dw_then_insert`-style reactive patterns need
state that survives across that gap the same way `last_op` itself does.

## Decision

- Added `seq.last_op_diw` (boolean, default `false`) to `M.new_seq()` — a
  persistent companion to `last_op`, not a single-shot field like
  `last_op_variant`. It is not reset in `M.feed()`'s per-call bookkeeping block;
  it is only ever written at the two call sites that can set
  `last_op = 'dw'`:
  - `pending_text_obj`'s resolution sets it to `op == 'd' and inner and key ==
    'w'` — true only for the exact `diw` shape, false for every other text
    object (`daw`, `di"`, `ciw`, …).
  - The bare/counted charwise-motion resolution (`dw`, `d3w`, `de`, …) sets it
    unconditionally to `false`.

  Because these are the only two places `last_op` ever becomes `'dw'`, the flag
  never goes stale: it always reflects whether the *current* `'dw'` value came
  from `diw` specifically.
- Added a new reactive check, `diw_then_insert` → `ciw`, placed immediately
  **before** the existing `dw_then_insert` check in `inner_feed` (both read
  `seq.last_op == 'dw'`, so ordering is what makes the more specific pattern win
  the priority tie): `if seq.last_op == 'dw' and seq.last_op_diw and
  INSERT_KEYS[key] then ... end`. Firing clears both `seq.last_op` and
  `seq.last_op_diw`, matching `dw_then_insert`'s own consumption discipline.
- `dw_then_insert` itself is otherwise unchanged — `dw`, `d3w`, `daw`, `di"`, and
  every other text object still resolve to it exactly as before. Only the exact
  `diw` shape is redirected to the new, more specific pattern.
- Not reusing/renaming `last_op_variant` for this: it stays scoped to
  `docs/adr/0106`'s single-shot usage-counting purpose. A second, differently-
  scoped field is more legible than overloading one field with two lifecycles
  (single-shot vs. persistent-until-consumed) that a reader would otherwise have
  to disentangle from call site alone.

## Consequences

- `diw` followed by entering insert mode now suggests `ciw` instead of `cw`;
  every other `dw`-bucket completion (`dw`, `d3w`, `daw`, `di"`, …) is unaffected
  and still suggests `cw`. This is a visible behavior change to an existing test
  (`patterns_spec.lua`'s prior "fires for diw" case under `dw_then_insert` was
  removed in favor of the new pattern's own describe block).
- Any future text-object variant that similarly deserves its own reactive
  `_then_insert`-style suggestion (rather than folding into its shared
  charwise-motion bucket) should follow the same shape: a persistent
  companion flag set at the one or two call sites that produce the shared
  `last_op` value, checked ahead of the more generic pattern in dispatch order.
- `tests/differential/reference_model.lua` and `generator.lua` model
  `diw_then_insert` the same way as `dw_then_insert` (own `state.last_op_diw`
  field, own generator chunk, added to `M.TRACKED_PATTERNS`) — required by the
  differential fuzzer's "almost every pattern" coverage invariant.
