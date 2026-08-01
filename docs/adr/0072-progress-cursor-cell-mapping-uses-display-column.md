# Cursor-to-command mapping converts byte offset to display column before dividing by cell width (#124)

## Context

`#124`: `item_at_cursor()` maps the cursor's column back to which skill cell
it's over. `nvim_win_get_cursor()` returns a **byte** offset, but each grid
cell occupies a fixed **display-column** budget (`COL_W = 14`). Mastery
glyphs (★/☆/✗, 3 bytes each) and the pin marker (●, 3 bytes) each occupy only
1-2 display columns but 3-4x that many bytes. On a row with several
mastered-and-pinned cells before the cursor's position, the gap between
"bytes consumed so far" and "display columns consumed so far" grows with
every such cell to its left. Dividing the raw byte offset directly by
`COL_W` resolved the cursor to the wrong — usually a neighboring — cell once
enough multibyte glyphs preceded it in the same row.

## Decision

Convert the cursor's byte column to a display column first —
`vim.fn.strdisplaywidth(line:sub(1, col))` — and only then compute
`cell_idx = math.floor((disp_col - 2) / COL_W) + 1` from that display
column. The raw byte offset is never divided by `COL_W` directly.

## Consequences

- Any future change to which glyphs are multibyte, or to `COL_W` itself,
  must preserve this byte→display conversion — reverting to a direct
  byte-offset division silently misattributes the cursor to the wrong cell
  again as soon as a row has enough preceding multibyte glyphs.
- `tests/spec/unit/ui_progress_spec.lua`'s "multiple mastered+pinned cells in
  the same row" case exists specifically to catch a regression here.
