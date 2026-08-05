# `<C-e>`/`<C-y>` repeated → `zz` (#243)

## Context

`zz`/`zt`/`zb` were already registered in `commands.lua` but had no reactive detection
pattern of their own. `<C-e>`/`<C-y>` (scroll one line down/up, cursor position
unchanged) were already used as *evidence* inside `manual_return`'s
`RETURN_MOTION_KEYS` set (ADR 0019) — but only as one signal among four (`j`/`k`/`<C-e>`/
`<C-y>`) that the user is manually stepping back after a big jump. There was no direct
"you're repeatedly nudging the view with `<C-e>`/`<C-y>` — `zz` centers it in one
keystroke" suggestion.

The two patterns needed to coexist without corrupting each other's bookkeeping:
`manual_return`'s `jump_return_streak` and the new `zz_streak` both increment off the
same two keystrokes in some scenarios (e.g. a user presses `<C-e>` five times right
after `G`).

## Decision

- `zz_streak` is a **new, independent counter field**, incremented only for
  `<C-e>`/`<C-y>` (not `j`/`k`, unlike `RETURN_MOTION_KEYS`) and reset by any other key.
  It is computed alongside `jump_return_streak`/`change_return_streak` but never reads or
  writes either of those fields, and vice versa — the three counters observe the same
  keystroke stream independently.
- Threshold is `CURSOR_CENTER_STREAK_THRESHOLD = 5`, chosen to match
  `RETURN_MOTION_THRESHOLD` (the existing constant already established for this same key
  class in ADR 0019) rather than inventing a new number.
- **Priority when both are ready on the same keystroke:** `manual_return`/
  `changelist_return` win over `cursor_center_repeat`. Both are computed as boolean
  readiness flags first (`jump_ready`/`change_ready`/`zz_ready`), then arbitrated in
  priority order — jump/change (already arbitrated between themselves by recency, per ADR
  0019) first, `zz_ready` only as a fallback `elseif`. Rationale: `manual_return` is the
  more specific, more valuable suggestion in that exact scenario (a preceding big jump
  plus manual stepping back means `<C-o>` returns you to the *exact* prior position,
  which subsumes what `zz` would do). `zz_streak` is explicitly reset to 0 whenever
  `jump_ready`/`change_ready` fires, so the loser doesn't leave a stale count that
  could misfire shortly after.
- A plain `<C-e>`/`<C-y>` streak with no preceding jump never sets `jump_last_at`, so
  `jump_ready` structurally cannot become true — `cursor_center_repeat` fires cleanly on
  its own in the common case.

## Consequences

- Any future pattern that also watches `RETURN_MOTION_KEYS` or a subset of it must follow
  the same "own counter, computed as a readiness flag, arbitrated explicitly" shape —
  reusing `jump_return_streak`/`change_return_streak` directly would reintroduce the
  cross-contamination this ADR avoids.
- The priority order (jump/change > zz) is a live design decision, not incidental —
  changing it changes which suggestion a user sees after `G` + 5×`<C-e>`.
