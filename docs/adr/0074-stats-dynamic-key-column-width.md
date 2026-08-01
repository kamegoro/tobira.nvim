# Stats key-column width is computed per render, not a hardcoded constant

## Context

`:TobiraStats`'s "Try these next" and "Top commands" sections both render a
command-key column that must line up (the count/arrow column after it has to
start at the same position in every row). A bare hardcoded width previously
drifted out of sync between the two sections (5 vs. 6) and, more fundamentally,
any fixed constant recurs as the same bug the day a longer key becomes
reachable: `commands.lua` already registers `<C-w>h/v/j/k/l/q/=` (6 columns)
and `<C-\><C-n>` (10 columns, reachable when `requires = 'i'`), and nothing
bounds how long a future key can be (#125).

## Decision

`M.render()` scans the actual keys it is about to render this call — every gap
row's parent/child key plus every Top-N command key — and takes the max
`vim.fn.strdisplaywidth()` across all of them, floored at `KEY_COL_MIN` (6) so
a render with only short keys still gets a deliberate-looking column instead of
a cramped one. Both sections read this one shared `key_col_w` instead of each
hardcoding its own literal.

## Consequences

- A future command with a key longer than today's longest never breaks column
  alignment — the width adapts automatically instead of needing a manual bump.
- The cost is one extra pass over `gaps` and `sorted` before rendering, which
  is negligible at these list sizes (`GAPS_N` / `TOP_N` are both single-digit
  caps).
- If `KEY_COL_MIN` itself ever needs to change, it's one named constant, not a
  literal duplicated across sections — keep it that way rather than
  reintroducing a per-section number.
