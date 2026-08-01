# Progress mirrors Guide's priority: forgotten overrides the numeric mastery glyph

## Context

`ui/progress.lua`'s skill grid renders one glyph per command, chosen from the
numeric `mastery_level()` ladder (☆ → ★ → ★★ → ★★★). A command that once
reached level 4 but hasn't been used in a while is also flagged by
`graph.is_forgotten()`. If the grid picked its glyph from `mastery_level()`
alone, a forgotten command would still show ★★★ here while `ui/guide.lua`
already renders the same command as ⟳ (needs review) — the two panels would
visibly disagree about the same command's state.

## Decision

`mastery_sym()` checks `data.suppressed` first, then `graph.is_forgotten(data)`,
and only falls through to the numeric `mastery_level()` ladder after both are
false — the same priority order `ui/guide.lua`'s `mastery_glyph()` already
uses. Suppressed outranks forgotten because it's an explicit user action;
forgotten outranks the numeric level because it's the more useful signal
("come back to this") even for a command that reached the highest level
before going quiet.

## Consequences

- Progress and Guide always agree on whether a command currently reads as
  forgotten vs. still-mastered.
- A future third state added to either panel's glyph logic must decide where
  it slots into this same priority chain and update both panels together —
  don't add a state to only one of the two glyph functions.
