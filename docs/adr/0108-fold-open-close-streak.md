# `zo`/`zc` repeated-fold streak → `zR`/`zM` (#232)

## Context

`za`/`zo`/`zc`/`zM`/`zR`/`zf`/`zj`/`zk`/`zd` are all registered in `commands.lua` under
`category = 'fold'` and appear in `:TobiraGuide`'s Fold section, but before this change no
reactive detection pattern existed anywhere in `patterns.lua` for any of them — `pending_z`
only resolved what the user had already typed, for tracking/mastery purposes. #232 flagged
this as a gap: the whole fold category was a container with no way in.

A fully useful fold suggestion — e.g. "you scrolled past a large foldable region without
folding it" — needs to read actual buffer fold state (`vim.fn.foldlevel()`/
`vim.fn.foldclosed()`), which is out of reach for `vim.on_key()`-only detection and falls
into the same architectural gray area already flagged by #59/#116. That bigger,
buffer-aware version is deliberately deferred; this change implements only the narrower,
keystroke-only fallback #232 also described: `zo`/`zc` used one-at-a-time on 2+ separate
folds in quick succession → suggest `zR`/`zM` (open/close all folds at once).

This narrow version is modeled directly on the existing `ctrl_w_close_streak`/
`ctrl_w_resize_streak` pattern (ADR 0024, ADR 0096) rather than inventing a new shape:
both are two-key compounds dispatched from a flat target table (`pending_ctrl_w`/
`pending_z`), where a small family of interchangeable "doing it the hard way" keys builds
a streak that fires a "do it all at once" suggestion, and any unrelated key in the same
family resets the count.

## Decision

- `fold_open_streak` counts `zo` 2+ times running (interrupted by anything else) and then
  fires `fold_open_repeat`, suggesting `zR` (open all folds).
- `fold_close_streak` counts `zc` the same way and fires `fold_close_repeat`, suggesting
  `zM` (close all folds).
- Unlike `ctrl_w_close_streak` (where `<C-w>q` and `<C-w>c` are interchangeable and share
  one counter), `zo` and `zc` do **not** merge into a single streak — they are two
  independent counters, each explicitly zeroing the other when it advances, the same
  "own counter, explicit cross-reset" shape ADR 0096 established for
  `ctrl_w_resize_streak` vs. `ctrl_w_close_streak`. Alternating `zo`/`zc` therefore never
  fires either suggestion.
- `za` is deliberately excluded from both streaks and resets both of them. `za` toggles a
  fold open or closed depending on the fold's current state — disambiguating that would
  require reading buffer fold state, which this narrow version does not do — so `za` is
  treated the same way `<C-w>w`/`<C-w>h`/etc. (neither a close nor a resize action) reset
  both `<C-w>` streaks.
- Every other z-target (`zt`/`zb`/`zz`/`zj`/`zk`/`zd`/`zf`) and any unrecognised key after
  `z` also resets both streaks, mirroring the `pending_ctrl_w` block's outer `else`
  branch.
- Ordinary local navigation (`CI_QUOTE_NAV_KEYS`: `w`/`b`/`e`/`h`/`l`/`j`/`k`/`0`/`^`/`$`) is
  tolerated between `zo`/`zc` presses without resetting either streak — see the
  navigation-tolerance fix documented in Consequences below. A big jump (`gg`/`G`,
  outside that set) still resets both streaks, same scope as `ci_dquote_streak`'s own
  tolerance (ADR 0020).
- Threshold is 2, matching `ctrl_w_close_streak`/`ctrl_w_resize_streak` (ADR 0024, ADR
  0096) rather than the 3 most other streaks in this file use — chosen for consistency
  with the closest existing precedent, and because folding is a pure view toggle with no
  data-loss risk, unlike `<C-w>o` actually closing windows at the same threshold.
- `zR`/`zM` were already registered in `commands.lua` (fold commands are already
  registered); only the two reason strings (`float.reasons.fold_open_repeat`/
  `fold_close_repeat`) were added, to all 6 locales.

## Consequences

- Caught: a user opening or closing several different folds one at a time in a row is
  nudged toward `zR`/`zM`.
- Explicitly deferred: anything that reads `vim.fn.foldlevel()`/`vim.fn.foldclosed()` to
  detect "the user should have folded this region but scrolled past it instead," or to
  disambiguate `za`'s actual effect — that is the bigger buffer-aware question #232 raised
  and left open, in the same category as #59/#116.
- Touching `pending_z`'s dispatch table now means touching three independent counters in
  this file's fold/window family (`fold_open_streak`, `fold_close_streak`, plus the
  pre-existing `ctrl_w_close_streak`/`ctrl_w_resize_streak` pair) — a future fold-family
  streak should follow the same own-counter, explicit-cross-reset shape rather than
  reusing either existing counter.
- Independent QA on this change (PR #288) found that the "any unrelated key resets
  state" block (the `key ~= 'p'` check, which this change adds both new counters to) is
  never actually reached by a key that starts a `d`/`c`/`y`/`>`/`<`/`=` operator sequence
  — `pending_op` resolves those entirely on its own and returns before that block runs.
  Concretely, `zo`, `dd`, `zo` wrongly fired `fold_open_repeat` on the second `zo`, and
  the identical gap already existed for `ctrl_w_close_streak`/`ctrl_w_resize_streak`
  (`<C-w>q`, `dd`, `<C-w>q` also wrongly fired) — this was not a regression introduced by
  this change, just inherited unnoticed from ADR 0024/0096. Fixed by resetting all four
  streak counters at the single shared point where `pending_op` starts (see the comment
  there), rather than duplicating the reset across every individual prefix-starter key —
  other prefix-starters (`r`, `<C-a>`, `v`, `"`, `m`, `[`, bare `g`, non-close/resize
  `<C-w>` targets) were confirmed to have the same latent gap but were deliberately left
  unfixed here as a separate, broader concern beyond this change's scope.
- The same independent QA also found a second, more consequential issue with the "modeled
  on `ctrl_w_close_streak`" choice above: `<C-w>q` naturally re-focuses the next window
  with no intervening key required, so a hard reset on any unrelated key never gets
  exercised in `ctrl_w_close_streak`'s own realistic usage. `zo`/`zc` have no equivalent
  auto-advance — reaching a DIFFERENT fold to `zo` it again always requires a real motion
  in between. Live QA confirmed the original hard-reset made the feature almost never fire
  for its actual stated purpose ("2+ separate folds"): `zo`, then any navigation at all
  (even a single `j`) to reach the next fold, then `zo` never fired `fold_open_repeat`.
  This is exactly the situation `ci_dquote_streak`/`ci_squote_streak` already solved with
  their own `CI_QUOTE_NAV_KEYS` tolerance table (ADR 0020), whose Consequences section
  explicitly says: "Any future streak that needs to 'survive across a necessary motion'
  ... should follow this same own-tolerance-table-plus-own-reset-check shape." Fixed by
  reusing `CI_QUOTE_NAV_KEYS` and giving `fold_open_streak`/`fold_close_streak` their own
  dedicated reset check (removed from the generic `key ~= 'p'` block), mirroring
  `ci_dquote_streak`'s exact structure instead of `ctrl_w_close_streak`'s. `ctrl_w_close_streak`/
  `ctrl_w_resize_streak` were deliberately left as hard-resets — they don't need this,
  since window-focus auto-advance means the scenario this tolerance fixes doesn't arise
  for them.
