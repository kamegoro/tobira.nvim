# Demo seed data hand-tunes counts to hit specific mastery glyphs and efficiency-gap ratios

## Context

`docs/demo-init.lua` seeds `usage.json` before every demo recording (`docs/make-demo.sh`).
The demo GIFs need to show every visual state the UI can render — mastered (★★★),
practiced (★★), familiar (★), tried (☆), forgotten (⟳), suppressed (✗), and pinned (●)
— inside a single short recording, plus a handful of clearly-worse-than-alternative
commands so `:TobiraStats`'s "Try these next" panel has something obviously worth
showing. A random or minimal seed would not reliably land in the right mastery
bucket for each glyph, or produce a `:TobiraStats` efficiency ratio worth
screenshotting.

## Decision

The seed table hardcodes a specific count/session-array per command, chosen so each
one lands in a specific bucket relative to `graph.lua`'s mastery thresholds:
`h/j/k/l/i/ciw` clear the ★★★ (≥5000) bar, `w/b/u/dw/cw/a` clear ★★ (≥1000), and so
on down through ☆ (1-99). `<C-i>` is seeded with a heavy early history and zero in
its last two sessions specifically to land in `graph.is_forgotten()`'s window. `dd`
and `<C-r>` get `suppressed`/`pinned` flags set directly rather than earned through
simulated use, since those are user actions the demo can't simulate by count alone.
The efficiency-gap pairs (`j`→`}`, `n`→`cgn`, `w`→`E`, `*`→`gn`, `f`→`;`) are chosen
so each ratio is large enough to be the obvious top pick in `:TobiraStats`.

## Consequences

- If `graph.lua`'s mastery thresholds (`mastery_level`, `is_forgotten`) ever change,
  this seed data must be re-tuned or a glyph will render wrong in the next demo
  recording — there is no test coupling the two, only this file's own comments.
- New demo tapes that need a different profile should extend this table rather than
  duplicating a second seed script, to keep the mastery-bucket mapping in one place.
