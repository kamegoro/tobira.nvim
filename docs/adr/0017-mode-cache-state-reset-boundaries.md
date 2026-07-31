# Mode-cache state reset boundaries (`logger.lua`)

## Context

`logger.lua` caches the current mode (`current_mode`, updated via a `ModeChanged`
autocmd) instead of calling `vim.fn.mode()` on every keystroke, for hot-path
performance (see `lua/tobira/CLAUDE.md`'s "vim.on_key() performance"). But a cached
value updates on a delay relative to the raw keystroke stream, and that delay caused a
real, silent bug (#179):

`current_mode` only catches up to `'v'`/`'V'`/`'\22'` via `ModeChanged` **after** the
Normal-mode `'v'` keystroke that started a Visual session has already been processed by
`vim.on_key`. Every subsequent key genuinely typed while inside Visual mode (`i`, `w`,
`<Esc>`, …) used to arrive at `handle_key` while looking, from the cache's point of
view, like "some other mode" — and fell into the generic non-Normal-mode branch that
unconditionally wipes `seq`. That silently broke `viw`'s `visual_textobj` detection and
`v_repeat` (#55) in real interactive use, despite both passing unit tests that call
`patterns.feed()` directly and bypass this dispatch gate entirely — the bug was in the
routing, not the pattern logic.

Terminal-job mode (`'t'`) has an analogous but different problem: `terminal_seq`'s
`<Esc>`-streak state is only meaningful within one continuous stay in terminal-job
mode, but the mode cache does not distinguish "still in the same terminal session" from
"left and re-entered a different one."

## Decision

- **`VISUAL_MODES` (`v`/`V`/`'\22'`) is routed through `patterns.feed()` — the same
  path as Normal mode — instead of being wiped by the generic non-Normal-mode reset.**
  Select mode (`'s'`/`'S'`/`'\19'`) and Replace mode (`'R'`) are deliberately NOT
  included: `patterns.lua`'s `pending_visual`/`v_streak` tracking is armed specifically
  by a genuine Normal-mode `'v'` press, and only these three modes are what that
  tracking needs to see through. Everything else still falls through to the generic
  reset.
  - `insert_seq`/`terminal_seq` are still reset upon entering this branch — Visual
    mode is neither Insert nor Terminal, so any half-finished state in either would
    otherwise sit stale until the next real mode switch.
- **`terminal_seq` is reset the moment the `ModeChanged` autocmd observes
  `current_mode == 't'` transitioning to anything else** (successful escape, or the
  terminal buffer closing under the user) — not lazily on the next terminal-mode key.
  Without this, a leftover half-streak from a previous terminal session could combine
  with the first `<Esc>` of a later, unrelated one.
- **Macro recording/replay exclusion (`_recording_macro` or `reg_executing() ~= ''`)
  is checked independently inside every mode branch** (Normal, Insert, cmdline,
  Terminal, and Visual), rather than once at the top of `handle_key` — each branch
  reads and mutates different module-local state, so the guard has to sit at the point
  where that state would otherwise be touched.

## Consequences

- Any new mode-specific branch added to `handle_key` needs to ask both questions this
  ADR is about: (1) does the mode cache's one-keystroke lag matter for this branch's
  state machine, the way it did for Visual mode's `seq`? and (2) does this mode's
  session-scoped state (like `terminal_seq`) need an explicit reset trigger tied to
  *leaving* the mode, not just entering it?
- The Visual-mode routing fix is dispatch-layer only — `patterns.lua`'s own
  `pending_visual`/`v_streak` logic was already correct; the bug and the fix both live
  entirely in which branch of `handle_key` a keystroke reaches, not in the pattern
  state machine itself. A future regression of this class would similarly pass
  `patterns_spec.lua`'s direct unit tests while failing in real usage — this class of
  bug is only caught by driving the real `vim.on_key` → `handle_key` path end-to-end,
  which is why `logger_spec.lua` has dedicated coverage for it rather than trusting
  `patterns_spec.lua` alone.
