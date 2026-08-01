# Preview strip key padding computes an explicit floor instead of relying on a %-Ns format spec (#154)

## Context

`#154`: the preview strip's first line glues the item's key (e.g. `cw`) to
its description. The original implementation used a `%-6s`-style format
spec to pad the key to a minimum column width before appending the
description. A `%-Ns` spec only ever *adds* padding — once the key's own
length already meets or exceeds `N`, it contributes zero separating
characters. Keys at or beyond 6 characters (`<C-\><C-n>`, `<C-w>q`,
`g<C-a>`) therefore rendered with the description text glued directly onto
the key, no gap at all.

## Decision

Compute the pad length explicitly as
`string.rep(' ', math.max(1, 6 - #item.keys))` and concatenate it, instead of
using a `%-6s`-style format spec. The `math.max(1, ...)` floor guarantees at
least one separating space survives no matter how long `item.keys` is.

## Consequences

- Any future change to the target column width (currently `6`) must keep the
  `math.max(1, ...)` floor, or long keys regress back to the #154 bug.
- `tests/spec/unit/ui_progress_spec.lua`'s "key at or beyond the padding
  width" cases guard this specifically — don't remove them when touching this
  padding logic.
