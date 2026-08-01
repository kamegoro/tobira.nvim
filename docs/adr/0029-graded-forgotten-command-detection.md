# Graded (average-based) forgotten-command detection, not a binary zero check

## Context

`graph.is_forgotten()` decides whether a command the user once relied on has
fallen out of use, so it can be re-surfaced instead of staying permanently
excluded once mastered. The original rule (#62) was binary: "were the last 2
sessions exactly 0?" A single stray use — one accidental keystroke, one
session where the user happened to reach for the command out of habit — was
enough to keep a command classified as "not forgotten" no matter how far its
real usage had actually collapsed (e.g. from an average of 8 uses/session down
to 1). The rule also compared against a fixed prior session's *count*, not an
average, so one unusually heavy session in the history could set a bar that
made an otherwise perfectly steady habit look "forgotten" by comparison.

## Decision

Replace the binary check with a ratio comparison between two rolling
averages, gated on having at least 3 sessions of history to be meaningful:

- `FORGOTTEN_RECENT_WINDOW = 2` — the same recency window the old binary rule
  used, kept for continuity.
- `FORGOTTEN_ADOPTED_BAR = 5` — reuses `is_adopted()`'s own "meaningfully
  used" bar, so "forgotten" is only ever evaluated against a command that was
  genuinely adopted in the first place.
- `FORGOTTEN_RATIO = 0.3` — the recent average must fall below 30% of the
  historical average (the average of every session *before* the recent
  window, not just its peak) to count as forgotten.

`guide_commands()` (and `is_mastered()`, which it depends on) deliberately use
`is_forgotten()` rather than a raw `mastery_level(data) < 2` check, so a
command that crossed the mastery threshold but has since gone quiet reappears
in the Guide panel instead of staying excluded forever (#68). This also means
a command's forgotten-ness feeds into the Guide's category "ceiling"
calculation — a forgotten beginner command still counts as unmastered when
deciding whether to open up intermediate/advanced categories.

## Consequences

- These thresholds are hardcoded, not exposed via `core/config.lua`, for the
  same reason as the mastery-level thresholds (100/1000/5000) and the
  adoption bar (avg ≥ 5): one fewer knob for users to have to understand.
- Any new "should this reappear" decision should go through `is_mastered()` /
  `is_forgotten()` rather than inlining a fresh `mastery_level(data) < 2`
  check — that would silently regress #68.
- A command fading gradually (not hitting exactly zero) is now caught; a
  command with one unusually heavy historical session is not unfairly
  penalized, because the historical side of the ratio is an average, not a
  peak.
