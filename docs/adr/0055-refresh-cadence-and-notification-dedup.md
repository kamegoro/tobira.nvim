# Refresh cadence (setup + VimEnter + SourcePost) and notification dedup (#63)

## Context

Keymap overrides and plugin presence are not static for the lifetime of a Neovim
session: a user's config can define mappings and lazy-load plugins across multiple
sourced files, and `VimEnter` fires before some of that is guaranteed to have happened
for every possible config layout. A single detection pass at `setup()` time risks
caching a stale, incomplete picture if anything remaps a suggestible key or installs a
plugin afterward (e.g. a `SourcePost`-triggered plugin config, or a mapping defined in
an autocmd that runs after tobira's own `setup()`).

Re-running detection on every relevant event is also naturally chatty: the debug
notification in `log_override()` exists to tell the user *why* a suggestion disappeared
(#63's acceptance criteria: "s is removed from the suggestion pool with a debug log
line"), but re-running `M.refresh()` on both `VimEnter` and `SourcePost` would otherwise
re-emit that same notification every time a mapping that was already known about is
simply re-detected.

## Decision

`M.setup()` calls `M.refresh()` once immediately, then registers a `tobira_integrations`
augroup that calls `M.refresh()` again on both `VimEnter` and `SourcePost` — catching
mappings/plugins that become available after `setup()` runs.

A separate `_logged` cache (`cmd -> true`) tracks which overrides have already had their
one-time debug notification emitted. `M.refresh()` only calls `log_override()` for a cmd
newly appearing in `_logged`; entries that drop out of the current override set are
removed from `_logged` too, so if the same key is unmapped and later remapped again, it
is treated as a fresh override and logged again.

## Consequences

- Any new caller that invokes `M.refresh()` directly (outside the `VimEnter`/`SourcePost`
  autocmd) inherits this same dedup behavior for free — `_logged` is refresh-agnostic,
  not tied to a specific call site.
- `M.reset()` clears `_logged` along with `_overrides`/`_plugins`/`_initialized` — a test
  or a real `:TobiraReset` that calls `reset()` then `setup()` again will re-log any
  still-present override, since from `_logged`'s perspective it's newly appearing again.
