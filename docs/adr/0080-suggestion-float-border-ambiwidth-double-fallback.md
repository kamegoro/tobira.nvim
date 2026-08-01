# Suggestion float border is a custom per-segment table, with an ASCII fallback under ambiwidth=double

## Context

`ui/float.lua` is the only panel whose border color varies by content (the
`CATEGORY_HL` table — motion/edit/search/etc. each get a distinct border
color, mirroring nvim-notify's per-level colored border). Getting a colored
border requires passing Neovim a custom per-segment border table (each
segment as `{ char, hl }`), unlike `guide.lua`/`progress.lua`/`stats.lua`,
which all use the plain `'rounded'` string preset since they don't need
per-instance color.

Box-drawing characters (`╭─╮│╯╰`) are Unicode "Ambiguous width": narrow
(1 cell) under the default `ambiwidth='single'`, but double-width under
`ambiwidth='double'` (set by users to match wide CJK fonts). Neovim
validates a custom border table cell-by-cell, so with `ambiwidth='double'`
it hard-errors with "expected only one-cell chars" — a crash the string
preset `'rounded'` never hits, because Neovim treats that preset specially
and never validates its cell width the same way.

## Decision

`border_with_hl(hl)` returns the Unicode rounded-border segments (tagged
with `hl`) by default, but switches to a plain ASCII border (`+`, `-`, `|`,
still tagged with `hl`) whenever `vim.o.ambiwidth == 'double'`. Only this
module needs the check — every other panel's plain `'rounded'` preset is
unaffected by `ambiwidth` either way.

## Consequences

- Users running `ambiwidth=double` see a squarer ASCII border on the
  suggestion float specifically, while every other tobira panel keeps its
  Unicode rounded border. This asymmetry is accepted rather than switching
  every panel to ASCII, since the colored-per-category border is the one
  feature that forces the custom table in the first place.
- Both branches (`ambiwidth` default and `double`) must stay covered by
  `ui_float_spec.lua`'s tests — this is the kind of bug that only reproduces
  under a specific user setting, not the default dev environment.
