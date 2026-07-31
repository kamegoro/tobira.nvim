# Ex-command tracking: verify-before-credit (`logger.lua`'s `handle_cmdline_key`)

## Context

`vim.on_key`'s callback for the terminating keystroke of a cmdline (`<CR>`) fires
**before** Neovim actually processes it — confirmed empirically, not just assumed:
`vim.fn.getcmdtype()`/`getcmdline()` still report the pre-submission state at the exact
moment `handle_cmdline_key` inspects them. That timing is what makes reading the whole
cmdline text at `<CR>` possible at all (see `patterns_cmdline.lua` for why the tokenizer
takes one complete string instead of accumulating keystrokes itself), but it also means
"the user submitted this command" and "this command actually did what it says" are two
different events — and QA found real false positives from conflating them:

- A `:s/pat/repl/` whose pattern matches nothing (E486) still submits a syntactically
  valid substitute command line — but performs zero substitutions.
- `:e`/`:b` on a target Neovim rejects (E94 "No matching buffer", E37 "No write since
  last change") still looks, textually, like a completed file switch.
- `:tabnew` with a duplicate filename Vim already has open elsewhere reuses the
  existing buffer instead of creating new content to browse.

## Decision

- **Credit is deferred to `vim.schedule()`, and re-verified against real state once
  Neovim has fully processed the command** — never inferred from the submitted text
  alone:
  - Substitute repeat (`track_substitute`): snapshot the target buffer's
    `changedtick` before scheduling, only credit if it changed afterward.
    `v:errmsg` was tried and rejected — every keystroke-driving path this test suite
    uses (`feedkeys`/`nvim_feedkeys`/`vim.cmd`) goes through the API/RPC dispatch
    layer, which converts errors straight into Lua exceptions without ever touching
    `v:errmsg`. `changedtick` also gets the edge cases right that neither `v:errmsg`
    nor a text diff would: `:s/foo/foo/` (text unchanged, but a real substitution)
    still increments it, while `:s///n` (report-only) and a fully-declined `:s///c`
    correctly leave it flat.
  - File ping-pong / tabnew (`feed_pingpong`, `feed_tabnew`): compare the RESULT
    against the TARGET (is the named file the current buffer now) rather than a
    before/after diff — a before/after diff stops meaning "did THIS command succeed"
    once a later command changes the buffer first.
- **`looks_like_substitute()` and `PINGPONG_WORDS` duplicate private checks that
  already exist inside `patterns_cmdline.lua` rather than importing them.** The
  tokenizer module stays a pure, `vim.*`-free string parser; these two are cheap gates
  deciding whether the deferred-credit machinery is even worth paying for on this
  particular command, and `track_substitute()`/`feed_pingpong()` re-validate the full
  command regardless. A mismatch here only ever costs one wasted `vim.schedule()`
  call, never an incorrect credit.
- **Tobira's own UI commands (`:Tobira*`) are excluded from tracking via
  `OWN_CMD_PREFIX`, checked in `logger.lua` rather than in `patterns_cmdline.lua` or
  `commands.lua`.** This is purely a "when to record" decision — the tokenizer has no
  tobira-specific knowledge, and `commands.lua` is the registry of commands tobira
  *teaches*, an unrelated concern from what it *tracks*. Without this, checking your
  own stats (`:TobiraReset`, etc.) becomes tracked usage itself, polluting the data
  being displayed (QA found `:TobiraReset` making `ex:tobirastats` show up as a top
  command in `:TobiraStats`).

## Consequences

- Every new Ex-command detector that credits something needs to ask "is submission
  the same event as success for this command?" — if not, it needs the same
  schedule-and-reverify shape as substitute/pingpong/tabnew above, not a same-tick
  credit.
- The only residual race is a single-main-loop-tick window if something else mutates
  the same buffer between the snapshot and the scheduled check (a second `:e`/`:b`
  landing before the first's callback runs). This is negligible in real interactive
  use; tests that drive back-to-back synthetic commands need a short `vim.wait()`
  between them to let each command's deferred check settle before the next starts.
- If a new Tobira UI command is added, it must share the `Tobira` prefix so
  `OWN_CMD_PREFIX`'s lowercase-prefix match keeps excluding it.
