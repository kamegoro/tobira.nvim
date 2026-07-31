# Terminal-mode `<Esc>` streak detection (`patterns_terminal.lua`)

## Context

Inside a Neovim terminal-job buffer, `<Esc>` is forwarded straight to the job instead
of doing anything vim-side. A vim user's reflex when they want back to normal mode is
to hit `<Esc>` — everywhere else in vim that works, so here it silently does nothing,
and they don't yet know `<C-\><C-n>` is the real way out (#110).

Detecting this needed to live somewhere, and needed a trigger condition that
distinguishes "stuck, doesn't know the escape hatch" from ordinary terminal-job usage
where a single `<Esc>` is completely normal (cancelling a shell's reverse-search,
dismissing one REPL prompt, etc.) — and it needed to not spam the user once detected.

`patterns.lua` already has a normal-mode `seq`/`feed` state machine, and
`patterns_insert.lua` (split out in #99) has its own insert-mode one. The question was
whether terminal-mode detection belongs inside one of those or as its own module.

## Decision

- **New sibling module (`patterns_terminal.lua`), not added to `patterns.lua` or
  `patterns_insert.lua`.** It shares no state and is never called from the same code
  path as either (`logger.lua` only calls `feed_terminal()` while its mode cache says
  `mode() == 't'`) — same "shares nothing → new sibling file" rule as #99 (see
  `lua/tobira/CLAUDE.md`'s "Module splitting policy").
- **Trigger threshold is 2 consecutive `<Esc>` presses, not 1.** A single `<Esc>` has
  an ordinary purpose in many terminal jobs and must never be flagged. Two in a row
  with nothing in between has no such ordinary purpose — it's specifically the
  "make sure I've left this mode" reflex. Any other key resets the streak to 0, so a
  REPL that legitimately consumes one `<Esc>` at a time (interleaved with typing)
  never trips this.
- **Fires once per streak, then latches (`fired = true`) until something breaks the
  streak** (an ordinary key, or `logger.lua` discarding the seq on a real mode
  change). Without this, continuing to hammer `<Esc>` past the 2nd press would
  re-fire the suggestion on every subsequent press — the float UI's own
  cooldown/max_shown machinery already exists to prevent spam at the suggestion
  layer, so detection should not re-trigger it on every repeat.
- **Deliberately NOT implemented: treating repeated `<C-w>` as an equivalent trigger.**
  `<C-w>` (delete word before cursor) is an extremely common, legitimate, *repeated*
  shell-editing action (`<C-w><C-w>` to delete the last two words of a half-written
  command is ordinary). Counting it the same way as `<Esc>` would false-positive
  constantly for routine shell use — a failure mode `<Esc>` does not have. The
  feature's acceptance criteria only requires the `<Esc>` case.

## Consequences

- Touching one of `patterns.lua` / `patterns_insert.lua` / `patterns_terminal.lua`
  never requires reading either of the others.
- The threshold and latch behavior are load-bearing: lowering the threshold to 1 or
  removing the latch reintroduces the false-positive/spam problems above — see the
  inline pointer comments at `ESC_THRESHOLD` and inside `feed_terminal()`.
- If a future pattern needs a `<C-w>`-repeat-style trigger, it needs its own
  false-positive analysis; the reasoning above does not transfer automatically.
