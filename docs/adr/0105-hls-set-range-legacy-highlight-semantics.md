# hls.set_range() reproduces legacy nvim_buf_add_highlight() semantics

## Context

All 4 panel-rendering files (`float.lua`, `guide.lua`, `progress.lua`, `stats.lua`)
applied highlight ranges through the now-deprecated `nvim_buf_add_highlight()`,
which treated `col_end == -1` as "through the real end of the line" and silently
tolerated any other out-of-range `col_end` rather than raising. Migrating each
call site directly to `nvim_buf_set_extmark()` would change behavior for every
caller: under its default `strict = true`, both a `-1` end_col and an
out-of-range end_col raise `"Invalid 'end_col': out of range"` instead of
clamping, so every panel's existing highlight-range calls would need their own
special-casing to keep working.

## Decision

`M.set_range(buf, ns, group, lnum, col_start, col_end)` wraps
`nvim_buf_set_extmark()` with `strict = false` unconditionally. This resolves
`end_col == -1` to the line's actual length and clamps any other out-of-range
`end_col` instead of erroring, reproducing `nvim_buf_add_highlight()`'s exact
behavior for every caller through one shared helper, instead of each of the 4
panel files special-casing `-1`/out-of-range itself.

`vim.hl.range()` was considered and rejected: it targets visual-selection-shaped
ranges (a pair of `(line, col)` endpoints run through `getregionpos()`, where
`-1` means `v:maxcol` rather than a plain byte offset) and always creates its
own extmark bookkeeping for an optional auto-clear timeout that none of these
call sites need. `nvim_buf_set_extmark()` is the more direct match for the old
API's plain `(line, col_start, col_end)` shape.

## Consequences

Every panel keeps calling one shared helper with the exact semantics they
always relied on, so the `nvim_buf_add_highlight()` migration required no
per-panel behavior changes. The cost is that `set_range()` always passes
`strict = false`, so a genuinely wrong `col_end` (a real bug, not an
intentional out-of-range end-of-line sentinel) is silently clamped instead of
raising — callers rely on tests, not a runtime assertion, to catch that class
of bug.
