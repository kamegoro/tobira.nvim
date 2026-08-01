# Forgotten state overrides the mastery star in Top commands

## Context

"Top commands" originally derived its glyph purely from
`graph.mastery_level(data)`. A command that had decayed into
`graph.is_forgotten()` (once well-used, now stale) could still render as
`★★★` in Stats while `:TobiraGuide` already flagged the same command with `⟳`
needing review — the two panels disagreed about one command's state (#123).

## Decision

The Top-commands row checks `graph.is_forgotten(item.data)` first and only
falls back to the mastery-level star table (`STAR_BY_LEVEL`) when the command
is not forgotten. This mirrors the precedence `graph.is_mastered()` already
applies internally — forgotten is checked before a command is allowed to read
as mastered.

## Consequences

- Stats and Guide always agree on whether a given command currently needs
  review; a viewer never sees `★★★` in one panel and `⟳` in the other for the
  same command.
- Any future per-command glyph added to a new panel must apply the same
  forgotten-first precedence, or it reintroduces the #123 disagreement.
