# Demo recordings toggle idle-picked and reactive-pattern suggestions independently

## Context

Different demo tapes need different subsets of tobira's two suggestion sources.
The `suggest` tape demos a reactive pattern (typing `fo`/`fo` firing `f_repeat` →
`;`) and needs that source alone: with the ambient idle picker also on, its own
best guess — scored across the whole seed profile (e.g. the large `j`→`}` gap) —
can race the reactive suggestion and win, showing an unrelated float instead of
the one the tape is narrating. The `guide`/`progress`/`stats` panel tapes need the
opposite: no floating suggestion at all (from either source), since a suggestion
popping up would overlap the panel being demoed.

## Decision

Two independent environment variables, threaded from each `.tape` file via `Env`,
gate the two sources separately: `TOBIRA_DEMO_IDLE` controls ambient/idle picking
(passed straight to `setup({ idle_suggestions = ... })`), and
`TOBIRA_DEMO_PATTERNS` controls reactive pattern detection (implemented by nilling
`logger.on_pattern` outright, since production has no config flag for this — no
real user ever wants patterns off while suggestions stay on). Both default to
`'on'` when unset, so a tape that doesn't care about this gets the normal full
experience.

## Consequences

- A new demo tape must decide both toggles explicitly if it needs anything other
  than the default "everything on" behavior; forgetting one risks the same
  suggestion-racing problem `TOBIRA_DEMO_PATTERNS` was added to fix.
- `on_pattern = nil` is a demo-only sledgehammer, not a pattern for production code
  to imitate — it works here because the demo script owns the whole process and
  nothing else expects `on_pattern` to stay callable.
