# Jumplist/changelist underuse detection: `jump_back`, `manual_return`, `changelist_return` (`patterns.lua`)

## Context

Vim's jumplist (`<C-o>`/`<C-i>`) and changelist (`g;`/`g,`) let you snap back
to a previous position/edit in one keystroke, but many users don't know they
exist and instead manually scroll or re-navigate back. Three related
suggestions live in `patterns.lua` for this:

- `jump_back` (#52): the user typed `gg` then manually typed `G` (or vice
  versa) — `''` (jump to position before the last jump) does this in one key.
- `manual_return` (#61): the user made a big jump (`G`, `n`/`N`, `<C-d>`
  etc.) and is now manually stepping back with `j`/`k`/`<C-e>`/`<C-y>` —
  `<C-o>` would do it in one key.
- `changelist_return` (#61): the user edited one spot, edited a different
  spot, and is now manually stepping back with `j`/`k` — `g;` would do it in
  one key.

All three share the same underlying evidence shape ("5+ consecutive
return-style keys after some earlier event"), so they interact and had to be
designed together rather than as three independent features.

## Decision

**`jump_back` (gg ↔ G, #52):**
- Detected via `last_op` (reused, not a dedicated boolean) being `'gg'`/`'G'`
  — reusing `last_op` lets a further alternation keep firing, and lets
  `logger.lua`'s usage-increment logic (keyed off `op_completed`) still count
  the `gg`/`G` itself as used.
- Bug fix: firing `jump_back` immediately at the point of detection used to
  skip the `JUMP_MOTION_KEYS` bookkeeping (`jump_last_at` refresh,
  `jump_return_streak` reset) that every OTHER bare `G` gets — corrupting
  `manual_return`'s tolerance-window check for that same `G`. Fix: only
  capture a `gg_then_G`/`g_then_gg` flag at the point of detection; the
  actual fire-and-return happens later, after the relevant bookkeeping block
  has already run for that same keystroke.
- The `pending_g` dispatch table resets `seq.run = { key = nil, count = 0 }`
  unconditionally after resolving ANY `g`-compound (not just `gg`). This
  fixes a real regression: adopting the `e_repeat → ge` suggestion (typing
  `ge`) did not reset the e-streak the way `w_repeat → W`/`b_repeat → B` do
  (their remedy is a different keystroke, so `track_run()` naturally resets
  it) — leaving `seq.run` frozen re-fired `e_repeat` one press "early" right
  after the user acted on it. Resetting unconditionally for every
  `g_targets` entry is a no-op for targets nothing downstream tracks via
  `seq.run` (`g`, `d`, `f`, `;`), but load-bearing for `gj`/`gk`/`gn`/`gx`/
  `gp`/`gu`/`g0`.

**`manual_return` (#61):**
- `JUMP_MOTION_KEYS` (`G`, `n`, `N`, `<C-d>`, `<C-u>`, `<C-f>`, `<C-b>`) mark
  "a big jump happened"; `RETURN_MOTION_KEYS` (`j`, `k`, `<C-e>`, `<C-y>`)
  mark "manual stepping back". 5 consecutive return-keys within
  `JUMP_TOLERANCE_MS` (15s) of a jump fires `manual_return`, unless
  `ctrl_o_seen` is already true — once the user has demonstrably used
  `<C-o>` themselves, it's permanently retired as a suggestion for this seq.
- `gg` is deliberately absent from `JUMP_MOTION_KEYS` — it's resolved
  entirely inside the `pending_g` dispatch above, since neither `g` keystroke
  of `"gg"` ever reaches this table alone.
- `/` is deliberately absent too — `logger.lua` resets `patterns.lua`'s whole
  `seq` on every keystroke while the mode is neither normal nor insert, so a
  literal `/` key can never reliably survive long enough to matter here.
- The tolerance window (15s) is sized to catch a real "read a few lines,
  then scroll back" case while not blaming an unrelated jump from minutes
  ago for an unrelated manual scroll now.

**`changelist_return` (#61):**
- `EDIT_OP_KEYS` (buffer-mutating keys) mark an edit. `edit_second_seen`
  only becomes true once TWO edits have happened with a non-`<Esc>` key seen
  between them — i.e. genuinely different spots, not re-entering the same
  one. Then 5 consecutive `j`/`k` within `CHANGE_TOLERANCE_MS` (15s) fires
  `changelist_return`, unless `g_semi_seen` is already true (mirrors
  `ctrl_o_seen`).

**Arbitration (both ready in the same keystroke):**
- Both blocks no longer return early on their own — they only record
  `jump_ready`/`change_ready`, and a dedicated arbitration block decides.
  Whichever triggering event (`jump_last_at` vs. `edit_last_at`) happened
  MORE RECENTLY wins (the more likely thing the user is actually trying to
  get back to). The loser's streak is reset without firing — not left
  dangling — so it can still legitimately fire later if it genuinely repeats.

**Cross-cutting bookkeeping bug:**
- `track_run()` must run unconditionally for every key, even ones the
  jumplist/changelist blocks return early on. Skipping it freezes
  `seq.run`'s counter for that keystroke, so the next same-key press jumps
  the count forward by 2 instead of 1 — misfiring `j_repeat`/`k_repeat`/etc.
  one press early right after a `manual_return`/`changelist_return`. This was
  a live regression not caught by `patterns_spec.lua`'s per-call assertions
  (which check single calls, not the frozen-then-jumped sequence across a
  multi-call boundary).

## Consequences

- `jump_back`, `manual_return`, and `changelist_return` share tolerance
  windows, streak fields, and the arbitration block — changing one
  threshold or the arbitration priority requires re-checking all three.
- The "capture a flag, fire later" pattern for `gg_then_G` and the
  unconditional `seq.run` reset in `pending_g` are both fixes for real
  regressions; reverting either reintroduces the corresponding bug (stale
  `jump_last_at`, or an early re-fire after adopting a suggestion).
- Any new early-return branch inside `inner_feed` must still reach
  `track_run()` for the current keystroke, or it reintroduces the frozen-run
  bug above.
