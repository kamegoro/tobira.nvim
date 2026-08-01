# Promotion rules reuse existing commands.lua entries, not new ones (#63)

## Context

Once phase 2 detects a helper plugin, `PROMOTION_RULES` needs to decide *what* to boost.
The plugin itself often has commands tobira doesn't know about at all (e.g. flash's own
jump keys, a surround plugin's `cs<char><char>` change-surround chord). Teaching those
directly would mean a new `commands.lua` registry entry per plugin, each needing its own
locale strings (`en.lua`/`ja.lua`) and test coverage — a much bigger surface than "notice
a plugin and nudge harder toward something tobira already teaches."

## Decision

`PROMOTION_RULES` deliberately promotes existing `commands.lua` suggestions rather than
inventing new ones. Each rule is `{ plugin, trigger, cmd, threshold }`: once `plugin` is
detected and the user's usage count for `trigger` crosses `threshold`, `cmd` bypasses
`find_best()`'s ordinary trigger-count gate.

The two seed rules pick the closest conceptual stand-in for what the plugin teaches:

- `surround` + `dw` usage ≥ 30 → promotes `ci"` (a surround plugin's core value
  proposition is fast text-object-based changes; `ci"` is tobira's existing text-object
  entry closest to that habit).
- `flash` + `f` usage ≥ 30 → promotes `;` (flash's jump model builds on the
  repeat-search convention `;` already teaches).

## Consequences

- A new promotion rule must point at a `cmd` that already exists in `commands.lua` — if
  the right thing to teach genuinely doesn't exist yet, that's a `commands.lua` registry
  change with its own test/locale footprint, done separately, not a shortcut through
  `PROMOTION_RULES`.
- The `trigger`/`threshold` pair reuses the same usage-count data `find_best()` already
  tracks — no new tracking path is introduced for promotion rules.
