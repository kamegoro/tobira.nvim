# Terminal category bypasses the global suggestion cooldown

## Context

`suggestion_cooldown` (default 300s) is a single global gate: only one auto
suggestion may fire per window, tracked via `session.last_auto_at`.
`patterns_terminal.lua`'s `<Esc>`-streak detector for exiting terminal mode (#110)
latches after firing once and never re-fires for the same streak.

Combine the two and there's a real bug (#166/#173): if *any* unrelated auto
suggestion (an ambient idle pick, or another reactive pattern) fires shortly before
a genuine terminal `<Esc>`-streak, the global cooldown silently drops the terminal
suggestion — and because the latch never re-fires that streak, this isn't a delay,
it's a permanent loss. The user is stuck in terminal mode wondering how to get out,
and the one suggestion that would have helped never appears.

## Decision

Add `bypasses_cooldown(cmd)`, consulted by `cooldown_blocks(cmd)` (the single choke
point used by both `M.queue` and `M.show`): entries in the `terminal` category skip
the cooldown gate entirely, the same way `:Tobira` manual already bypasses it
(`M.manual()` never calls `over_auto_limit()`).

The check is scoped to `graph.suggestions[cmd].category == 'terminal'`, not the
literal `'terminal_esc_repeat'` pattern name, so any future addition to the
`terminal` category inherits the exemption automatically — mirroring the same
category-keyed shape `ui/float.lua`'s `auto_close_duration()` already uses for this
category's longer on-screen window (#166).

**Spam risk, considered and rejected:** bypassing the cooldown here does not reopen
the spam problem the cooldown exists to prevent. `patterns_terminal.lua`'s `fired`
latch already guarantees at most one `on_pattern` call per uninterrupted
`<Esc>`-streak, so `suggest.lua` never even sees repeat attempts within one streak.
A *new*, separate streak firing again later in the same session is not spam
either — it's a fresh instance of the user genuinely being stuck again, which is
exactly what this exemption exists to surface promptly. `max_shown` (default 2)
remains a second, independent line of defense against unbounded repeats within one
session even with the cooldown bypassed.

## Consequences

- Only the `terminal` category is exempt; every other category remains subject to
  the global cooldown exactly as before.
- A future category is a candidate for the same exemption only if it shares the
  "fires only while the user is genuinely mid-struggle, not idle/paused" property —
  see `lua/tobira/CLAUDE.md`'s command-registry checklist for the exact criterion.
- Removing or weakening `patterns_terminal.lua`'s latch would reintroduce a spam
  path here; `max_shown` alone would then be the only remaining guard.
