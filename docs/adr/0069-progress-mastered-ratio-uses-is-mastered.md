# Progress's mastered-ratio counts use is_mastered(), not a raw mastery_level threshold (#123)

## Context

`#123`: the H1 line's `{n}/{total} mastered` ratio and each category heading's
`{done}/{total}` count originally incremented their tally on a raw
`mastery_level(data) >= 2` check. That check doesn't know about
`graph.is_forgotten()`, so a command that decayed into the forgotten state
still counted toward "mastered" in both ratios — self-contradictory on the
very same screen, since that same command's own grid cell already renders
the ⟳ forgotten glyph (see the sibling ADR on glyph priority), and
inconsistent with `ui/guide.lua`, which already excluded forgotten commands
from its own count.

## Decision

Both counting loops in `M.build()` (the H1 total and each category's
per-section done count) call `graph.is_mastered(item_data(item, usage))`
rather than reimplementing a `mastery_level() >= 2` comparison directly.
`is_mastered()` itself already accounts for `is_forgotten()`, so neither loop
needs to know about that check separately.

## Consequences

- Both loops stay correct automatically if `is_mastered()`'s own definition
  changes — neither should be changed independently to reintroduce a raw
  `mastery_level()` comparison.
- The two loops share a single point of truth (`item_data()` +
  `is_mastered()`) instead of two independently-derived thresholds that could
  drift apart from each other or from Guide's.
