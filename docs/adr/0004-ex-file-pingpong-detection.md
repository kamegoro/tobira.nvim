# Ex-command file ping-pong detection (#114, `patterns_cmdline.lua`)

## Context

A user repeatedly bouncing between the same two files via `:e`/`:b` (`:e A` → `:e B` →
`:e A`, or the `:b` equivalent) is a direct signal for `<C-^>`, which jumps straight to
the alternate file. This needed a trigger condition that distinguishes a genuine two-file
habit from browsing through many files, and it needed to fire once, not on every
alternation.

It also surfaced a QA-found false positive: `logger.lua`'s `vim.on_key` callback for the
`<CR>` that submits `:e`/`:b` runs **before** Neovim actually validates or executes the
command, so typing `:e foo` is not the same as the switch actually happening — Neovim can
still reject it (`E94 No matching buffer`, `E37 No write since last change`). Crediting
the pattern from the typed text alone would count switches that never really occurred.

## Decision

- **Kept in this same file, not a new sibling one**, even though it shares no actual
  state with `tokenize()`/`command_arg()` — it's fed from the exact same call site
  (`logger.lua`'s `handle_cmdline_key`, at `<CR>` time). Call path, not shared state, is
  the deciding question (see `lua/tobira/CLAUDE.md`'s module-splitting policy).
- **Only remembers the two most recently *distinct* filenames**, not a full history —
  this is what makes bouncing among 3+ different files never satisfy "is this the file
  from two switches ago" (a genuinely third file always overwrites the older of the two
  remembered names, permanently forgetting it for this rotation).
- **Fires once per rotation, then latches** until a third, different file breaks it —
  same "fire once per streak" precedent as `patterns_terminal.lua`'s `terminal_esc_repeat`
  — so continuing to alternate between the same two files never re-fires the suggestion.
- **Deliberately literal command words only (`e`, `b`)**, not abbreviation expansion
  (`:edit`, `:buffer`, ...) — same "no abbreviation table" call `tokenize()` makes, for
  the same reason. Revisit if usage data ever shows real users typing `:edit`/`:buffer`
  for this habit.
- **`feed_pingpong()` itself stays a pure function that trusts its `word`/`arg` inputs**
  — it does no verification of its own. The fix for the false-positive above is to defer
  *calling* it: `logger.lua` snapshots the target filename, defers into `vim.schedule()`,
  and only calls `feed_pingpong()` if the current buffer after Neovim finishes processing
  the command actually matches the target (result-vs-target, not a before/after diff —
  a diff stops meaning "did THIS command succeed" once a later command changes the buffer
  first). This keeps `patterns_cmdline.lua` pure and vim.*-free while still getting a
  real-effect check; see `logger.lua`'s `handle_cmdline_key` for the scheduling code.
- Reopening the file that's already current (`arg == seq.second`) is a no-op: it isn't a
  new switch, and touching the latch here would disturb an in-progress or already-fired
  rotation for no reason.

## Consequences

- The 2-file memory and fire-once latch are load-bearing: see the inline pointer comment
  above `new_pingpong_seq()`/`feed_pingpong()` — changing either reintroduces the
  3+-file false positive or the re-fire-on-every-alternation spam this design avoids.
- `feed_pingpong()` itself has no notion of "did the switch really happen" — that
  verification is entirely the caller's responsibility. Any new caller of
  `feed_pingpong()` must reason about whether it needs the same defer-and-verify
  treatment `logger.lua` gives it, or risks crediting attempted-but-rejected switches.
- This is one signal among potentially several that can all suggest `<C-^>` —
  `commands.lua` has exactly one `<C-^>` registry entry regardless of how many patterns
  recommend it; only the "why am I seeing this" reason line differs per trigger.
