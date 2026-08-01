# Progress pins nav-hint keybindings to the window footer instead of the scrollable buffer

## Context

The keybinding hints (`x`=suppress, `p`=pin, `g`=guide, `s`=stats, `q`=close)
need to stay visible regardless of scroll position, but the skill grid
itself is a plain scrollable buffer with no fixed regions of its own — a
hint line placed inside `lines` would scroll out of view as soon as the
skill tree grew taller than the window.

## Decision

The nav-hint line is rendered through the floating window's native `footer`
option (set once in `M.open()`, built by `footer_chunks()`/`ui/footer.build()`)
rather than as a line inside the `lines` array returned by `M.build()`.
`FOOTER_KEYS`'s key order is fixed directly in source, not derived from
`pairs()` (whose iteration order is not guaranteed stable across Lua
versions/platforms) — only the per-key display label is looked up from the
locale table.

## Consequences

- The footer-building helper (`ui/footer.build()`) is shared with
  `ui/stats.lua`; a future third caller must keep to the same
  `{ key, label_key }` list shape this module and stats both pass in.
- Any new Progress keybinding must be added to `FOOTER_KEYS` (not printed as
  a line in `M.build()`'s output) to actually appear in the footer.
- `tests/spec/unit/ui_progress_spec.lua`'s "does not also render the footer
  labels inside the scrollable buffer" case guards against accidentally
  duplicating this content into `lines`.
