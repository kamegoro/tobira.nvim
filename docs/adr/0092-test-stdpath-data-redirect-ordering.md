# Test stdpath('data') redirection must install after plenary is found, before logger is required

## Context

`tobira.core.logger` reads and writes `~/.local/share/nvim/tobira/usage.json`, and
many specs call `logger.reset()` in `before_each`, which unlinks that file. Running
the suite must never wipe a developer's real usage history just because the tests
happened to run on their machine. `tests/minimal_init.lua` is the bootstrap loaded
by every child Neovim process `PlenaryBustedDirectory` spawns, so this is the only
place the redirect can live.

There's a real ordering constraint, not just a preference: plenary.nvim itself is
located on disk (cloned if missing) under the **real** `stdpath('data')`, so the
redirect cannot be installed before that lookup. But `tobira.core.logger` captures
its data directory once, at `require()` time, so the redirect must be installed
before any spec file requires it — which in practice means before plenary's spec
runner even starts discovering spec files.

## Decision

`vim.fn.stdpath` is monkey-patched in `minimal_init.lua`, in this exact order:
locate/clone plenary under the real data dir first, then redirect `'data'` to a
fresh `vim.fn.tempname()` directory for the rest of the process. Every other
`stdpath` argument still passes through to the original implementation.

## Consequences

- Any future addition to `minimal_init.lua` that reads or writes under
  `stdpath('data')` must be placed relative to this redirect with the same care —
  before it if it needs the real plenary install path, after it if it wants
  test isolation.
- Because the redirect is process-global and installed once, all specs in a given
  child process share the same temp data dir; specs must not assume a pristine
  directory unless they call `logger.reset()` themselves.
