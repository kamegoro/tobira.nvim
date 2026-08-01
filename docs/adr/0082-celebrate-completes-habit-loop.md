# celebrate() is a distinct, non-interactive toast that completes the cue-routine-reward habit loop

## Context

`logger.mark_adopted()` silently flips a flag the first time a suggested
command is actually used — it has no user-visible feedback. The suggestion
float's whole design already leans on habit-loop psychology (cue → routine
→ reward, see `lua/tobira/ui/CLAUDE.md`'s design-research pointers, #71/#72):
the float itself is the cue, the user trying the command is the routine,
but without a reward step the loop never closes — adoption is only ever
recorded, never celebrated.

## Decision

`M.celebrate(cmd)` renders a separate, short-lived (3.5s), unfocused,
non-interactive toast with its own `TobiraCelebrate` highlight — visually
distinct from a suggestion float (which is longer-lived and, when focused,
interactive) so it can never be mistaken for a new suggestion. It replaces
any currently-open suggestion float rather than stacking, and fires exactly
once, only the first time a command is genuinely adopted.

## Consequences

- Any future "first-time X" reward moment should reuse this same
  short/unfocused/distinctly-highlighted shape rather than inventing a new
  one, to keep the loop's reward step visually consistent across the
  plugin.
- If `celebrate()` ever needs to become interactive or long-lived, that is
  a sign it is drifting into being a second suggestion float — which
  defeats the reason it needed to be visually distinct in the first place.
