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
