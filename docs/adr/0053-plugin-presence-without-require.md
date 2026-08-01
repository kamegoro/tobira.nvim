# Plugin detection checks runtime files, never `require()` (#63)

## Context

Phase 2 needs to know whether the user has a specific helper plugin installed (hop,
leap, flash, a surround plugin, a comment plugin) so `PROMOTION_RULES` can boost the
relevant suggestion. The obvious way to check "is module X available" in Lua is
`pcall(require, 'X')`.

Many of these plugins are lazy-loaded by design (that's the whole point of a plugin
manager's lazy-loading feature) — their module is intentionally not loaded until the
user actually triggers whatever event/command/keymap loads it. If tobira's presence
check used `require()`, the mere act of checking for the plugin would force it to load
immediately, defeating the user's own lazy-loading setup as a side effect of tobira just
looking.

## Decision

`module_available()` checks for the plugin's files on the runtimepath via
`vim.api.nvim_get_runtime_file()` instead — presence-only, never loads or executes the
module. It checks **both** shapes plugins ship in: a flat `lua/<name>.lua` file (e.g.
`mini.surround` as a submodule) and a `lua/<name>/init.lua` directory-style module (e.g.
`hop.nvim`). `KNOWN_PLUGINS` maps each module path to an integration tag; multiple module
paths can share one tag (`nvim-surround` and `mini.surround` both set the `surround` tag)
since either satisfies the same promotion rule.

## Consequences

- Adding a newly-supported plugin means adding a `{ module = ..., tag = ... }` entry to
  `KNOWN_PLUGINS`, not a `require()` call anywhere in this module — reviewers should
  flag any `require()` of a third-party plugin module introduced here.
- This can only detect presence, not version or config — `has_plugin()` says nothing
  about whether the plugin is actually set up or working, only that its files exist on
  the runtimepath.
