# `~` streak refinement: text-object-scoped case toggle at higher counts (#235)

## Context

The existing `tilde_repeat` pattern (`~` × 3 → `{n}~`) only teaches "count-prefix the
same single-char toggle" — still character-by-character thinking. A user pressing
`~~~~~~` to toggle case across a whole word one character at a time would benefit more
from `g~iw` (toggle the whole word in one motion) than from `6~` (still counting
characters). The issue asked for a judgment call: is this a refinement of `tilde_repeat`
or a new sibling pattern?

Two follow-on questions patterns.lua cannot answer from keystrokes alone: (1) `guiw` /
`gUiw` require knowing whether the *original* characters were upper or lower case, which
needs buffer content patterns.lua deliberately never reads; (2) "spans a whole line" has
no keystroke-visible signal like an actual end-of-line position.

## Decision

- **Refinement, not a new pattern family** — reused the existing `count == N` streak
  mechanism (`track_run` off the literal `~` key) that already implements
  `tilde_repeat`, adding two more `elseif key == '~' and count == N` branches at higher
  thresholds. This follows the file's own established convention for exactly this
  situation: `j_repeat(5)` / `j_many(10)` already supersede each other for the same key
  via strict `==` (not `>=`), each threshold firing exactly once as count climbs — see the
  inline comment at that block. No new state fields were needed.
- **Thresholds**: `TILDE_WORD_THRESHOLD = 6` (double the existing `tilde_repeat`
  threshold of 3 — "plausibly spans a whole word", the same doubling relationship
  `j_repeat`→`j_many` already uses) and `TILDE_LINE_THRESHOLD = 12` (double again —
  "spans well past a single word"). Both are keystroke-count proxies, not real word/line
  boundaries, since patterns.lua has no buffer visibility — documented explicitly as an
  approximation rather than a precise measurement.
- **`g~iw`, not `guiw`/`gUiw`**: since patterns.lua cannot see whether the toggled
  characters were originally upper or lower case, suggesting a *fixed-direction* operator
  (`gu`/`gU`) would be a guess that's wrong roughly half the time. `g~` (toggle) is the
  direct one-shot equivalent of what `~` itself already does, so it's always correct
  regardless of original case.
- **`g~$` at the line threshold**, not `g~` combined with an actual line-end check —
  same reasoning: "ran long enough to plausibly reach end of line" is the only available
  proxy.
- `tilde_repeat` (`{n}~`) is left firing unchanged at count 3 — the issue's own acceptance
  criteria requires preserving it for shorter streaks where the text-object framing isn't
  clearly better yet.
- New registry entries `g~iw` (requires `g~`) and `g~$` (requires `g~iw`), both
  `track = false`, category `edit`. Both added to `commands_spec.lua`'s `KNOWN_DEFERRED`
  list: `g~` itself has no `pending_g` dispatch-table entry (only `gu` does), so it has no
  tracking path other than reactive suggestion, same as `gU`.

## Consequences

- A future pattern needing "supersede an existing streak suggestion at a higher count"
  should reuse this same `== N` / `== M` (`M > N`, doubling) shape rather than
  introducing a parallel counter.
- The word/line thresholds are keystroke-count heuristics, not measured against actual
  buffer content — expect them to need retuning from live usage, same caveat as
  `JUMP_TOLERANCE_MS`/`FORGOTTEN_RATIO` elsewhere in this codebase.
