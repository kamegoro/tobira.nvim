# Guide row indent-aware wrapping and count-column overflow guards

## Context

Guide's auto-section and pinned-section rows render inside a fixed `WIDTH`-column
floating window, but two things regularly don't fit on one line. First, a row's
description can carry a "remapped to ..." annotation naming a real user keymap
target, which can be arbitrarily long and, unlike ordinary prose, can be one
unbroken token with no internal whitespace at all (e.g. a plugin-provided
`<Plug>(...)` mapping name) — whitespace-only wrapping can never bound a token like
that no matter how long it is. Second, each row also appends a right-aligned usage
count after its description, and that count can independently overflow `WIDTH` in
two different ways: the padding added so counts align in a column across a
category's rows can push a row past `WIDTH` even when the row's own raw description
fit fine on its own, and a large historical count's digit string can overflow even
an already-unpadded row. Left to Neovim's own default zero-indent line wrap, a
wrapped row's continuation lines also don't align under the description column,
and a dangling count can land alone at column 0.

## Decision

`wrap_indented(text, indent, width)` splits `text` on whitespace the same way
Neovim's own `linebreak` does, but explicitly repeats `indent` display columns
(a display-column count, not a byte count, since a mastery glyph can be multiple
bytes but a single display column) as leading space on every line after the
first, so a wrapped row's continuation lines land under the description column
instead of at column 0. Any single word wider than the available width is
delegated to `hard_break(word, avail)`, which breaks it character-by-character
(never mid-byte, via `strcharpart`/`strdisplaywidth`) since it has no whitespace
of its own to split on.

`format_row()` re-derives the row's width twice after the initial wrap:

- Once to fall back to the unpadded single line if the `desc_col_w` alignment
  padding alone would push the row past `WIDTH`, even though the raw description
  fits — checking only `#wrapped == 1` misses this case.
- Once to give the count string its own indented continuation line if appending
  it to the last wrapped line would itself overflow `WIDTH` (e.g. a large digit
  count on an already near-full line), instead of overflowing or truncating.

## Consequences

Every row renders within `WIDTH` columns regardless of remap-target length or
historical usage count, with continuation lines correctly indented under the
description column. The two extra width re-checks in `format_row` are cheap
(`vim.fn.strdisplaywidth` calls) but add branching that must stay in sync if
`WIDTH` or the row layout changes.
