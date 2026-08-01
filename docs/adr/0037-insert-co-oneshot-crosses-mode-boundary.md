# Insert-mode `<C-o>` one-shot detection crosses the mode boundary

## Context

Insert-mode `<C-o>` runs exactly one Normal-mode command without fully leaving
insert mode. A user who doesn't know it does the manual equivalent instead:
`<Esc>`, one Normal-mode command, then `i`/`a`/`A`/`I` to resume typing (#105).
Detecting that round trip to suggest `<C-o>` needs to watch the Normal-mode
keystrokes that happen *between* leaving and re-entering insert mode — but
`patterns_insert.lua` is otherwise an insert-mode-only file, and the
Normal-mode keystroke stream in `logger.lua` is otherwise owned by
`patterns.lua`'s `seq`/`feed`.

## Decision

- The watch's state (`watching_co`, `post_esc_keys`) lives in this file's
  `iseq`, alongside all the other insert-mode-only state, even though it is
  fed through a second entry point (`feed_after_escape`) that `logger.lua`
  calls from its *Normal*-mode branch, not from `feed_insert`. This is not a
  state-sharing violation of the patterns.lua/patterns_insert.lua split (see
  `lua/tobira/CLAUDE.md`'s "Module splitting policy") — `seq` (patterns.lua)
  and `iseq` (this file) stay fully separate objects with no shared fields;
  only `logger.lua`'s orchestration layer calls into both for the same
  keystroke, which is exactly its job.
- `feed_insert('<Esc>')` (re-)arms the watch unconditionally on every exit
  from insert mode, overwriting whatever a previous, never-resolved arm left
  behind (e.g. a Normal-mode command that auto-entered insert without ever
  passing through `feed_after_escape`'s return-key check) — so the watch can
  never go stale.
- "One command" is a **keystroke count**, not a timing window: this file has
  zero `vim.*` dependencies, so there is no clock to measure a timing window
  against. A count of exactly one raw keystroke before the return-to-insert
  key is an equivalent, simpler proxy for "genuine one-shot vs. multi-step
  detour". `feed_after_escape` disarms itself as soon as a 2nd keystroke
  arrives while watching, rather than continuing to count and only checking
  at the return point.
- **Deliberately NOT implemented:** recognizing a compound Normal-mode command
  (`dd`, `dw`, `ciw` — several keystrokes forming one conceptual edit) as "one
  command". Doing that would mean replicating `patterns.lua`'s operator-grammar
  tracking here, which costs more complexity than the feature is worth. Known
  limitation: only single-keystroke round trips (`j`, `k`, `x`, `p`, `~`, `.`,
  `u`, ...) are recognized.

## Consequences

- Multi-keystroke compound edits between `<Esc>` and the return key never
  trigger this suggestion, even though a real `<C-o>` user would use it just
  as reasonably for those. This is an accepted non-goal, not a bug to fix
  without revisiting the tradeoff above.
- Because re-arming is unconditional on every `<Esc>`, no stale `watching_co`
  state can survive past the next `<Esc>`.
- Anyone changing the "disarm after 2nd keystroke" threshold must keep it
  consistent with what "one shot" means in the fire condition
  (`post_esc_keys == 1` at the return key).
