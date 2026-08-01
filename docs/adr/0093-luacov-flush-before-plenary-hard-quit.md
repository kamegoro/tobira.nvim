# vim.cmd is wrapped to flush luacov stats before plenary's hard-quit

## Context

Coverage collection (`COVERAGE=1`) runs `luacov.runner` inside each headless child
Neovim process, and `luacov` normally flushes its stats via an `os.exit` hook.
Plenary's busted runner doesn't call `os.exit()` on completion, though — it quits
headless Neovim with `vim.cmd('0cq')` (or `'1cq'` on failure), which bypasses that
hook entirely. Without a fix, `luacov.stats.out` is never written and coverage
silently reports 0% no matter what the tests actually exercised (see
plenary.nvim#353).

## Decision

`vim.cmd` is wrapped: the wrapper inspects the command string for the `NcQ`
hard-quit pattern (or `qa`) and calls `runner.shutdown()` immediately before
delegating to the original `vim.cmd`, then restores the original reference. As a
second line of defense, `os.exit` is also wrapped and a `VimLeave` autocmd is
registered, both calling `runner.shutdown()` (via `pcall`, since it may already
have run).

## Consequences

- This only runs when `COVERAGE=1` is set, so normal (non-coverage) test runs never
  pay the cost of the wrapped `vim.cmd`.
- If plenary's runner ever changes its exit mechanism again, this pattern match
  needs updating — there is no test that would otherwise catch a silent 0%
  coverage report, only manually noticing the number is wrong.
