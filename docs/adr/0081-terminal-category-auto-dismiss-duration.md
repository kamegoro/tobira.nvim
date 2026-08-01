# Terminal-category suggestions get a longer auto-dismiss window (#166)

## Context

`auto_close_duration(line_count, category)` scales the suggestion float's
auto-dismiss timer with content length, clamped to a toast-notification
convention of roughly 6–9 seconds on screen. That convention assumes the
audience is idle/paused at the moment the float appears — true for every
suggestion category except one.

`terminal_esc_repeat` (#110) fires while the user is, by definition, still
actively fumbling to leave terminal-job mode at that exact moment — their
hands and attention are on the stuck job, not idly watching the corner of
the screen. #166 reported this suggestion as "never becomes visible," but
investigation showed the window rendered correctly; the real cause was the
standard 6–9s window elapsing before this distracted audience got a real
chance to look (an illusion also reproduced by any multi-step verification
process with latency between trigger and observation). Live regression
passes (tmux+asciinema) confirmed this under adversarial conditions too: a
continuously-flooding terminal job, a competing first-run `:TobiraGuide`
popup, and narrow 80-col terminals.

## Decision

`auto_close_duration` special-cases `category == 'terminal'` with a wider
clamp (12000–18000ms instead of 6000–9000ms). The check is keyed off
`suggestion.category`, not the literal `'terminal_esc_repeat'` pattern name,
so any future addition to the `terminal` category inherits the longer
window automatically. This is the sibling mechanism to
`docs/adr/0046-terminal-category-cooldown-bypass.md`'s cooldown exemption —
both key off the same category field for the same underlying reason (this
audience is genuinely mid-struggle, not idle).

## Consequences

- Every other category keeps the original 6–9s convention unchanged.
- A future category is a candidate for this same carve-out only if it
  shares the "fires only while the user is genuinely mid-struggle" property
  — see `lua/tobira/CLAUDE.md`'s command-registry checklist for the exact
  criterion.
- Changing this formula requires re-validating against the adversarial
  live-regression scenarios that originally exposed the bug (tmux+asciinema
  with a flooding job / competing popup / narrow terminal), not just the
  automated suite's boundary assertions — those scenarios are what
  distinguish "renders correctly" from "the audience actually sees it."
