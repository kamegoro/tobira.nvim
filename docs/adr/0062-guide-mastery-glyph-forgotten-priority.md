# Guide's mastery glyph checks "forgotten" before the numeric level, and has no branch for level ≥ 2

## Context

`mastery_glyph(data)` picks the glyph and hlgroup shown next to an auto-section row.
`graph.lua` independently reports a numeric `mastery_level` (0-4) and a separate
`is_forgotten()` boolean (once mastered, gone quiet — see `logger.lua`'s forgotten-ratio
handling). A command that was mastered and has since gone quiet has both a nonzero level *and*
`is_forgotten() == true` at the same time, so the function has to pick one signal to display.

`M.build` only calls `mastery_glyph` for rows `guide_commands()` already included, and
`guide_commands()` filters to `not is_mastered(data)`, i.e. `mastery_level(data) < 2 or
is_forgotten(data)`. So in practice `mastery_glyph` only ever sees a level of 0 or 1, or (at any
level) a forgotten row.

## Decision

- Check `is_forgotten()` first, unconditionally, before looking at the numeric level: a command
  once mastered that's since gone quiet renders `⟳` regardless of what star count it reached
  before going quiet — it should read as "come back to this," not show its old star glyph.
- Only two branches exist after that: forgotten → `⟳`; else `mastery_level == 1` → `☆`; else
  (level 0) → blank/dim row. There is deliberately no `elseif level >= 2` branch — given
  `guide_commands()`'s filter above, a level ≥ 2 row reaching this function is always the
  forgotten case already handled, so a further branch would be dead code.

## Consequences

- This function's reachable-branch reasoning depends on `guide_commands()`'s exact filter
  predicate. If that filter ever changes (e.g. to admit some level ≥ 2 rows that aren't
  forgotten), `mastery_glyph` must be revisited — the "no elseif" simplification would silently
  become wrong (falling through to the level-0 blank case) rather than failing loudly.
