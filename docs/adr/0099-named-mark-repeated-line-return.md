# Named-mark opportunity: repeated returns to the same line → `ma` (#238)

## Context

Named marks (`ma` then `` `a ``/`'a`) were already registered in `commands.lua` with no
reactive detection pattern. This is a different skill from the existing `jump_back`/
`manual_return`/`changelist_return` patterns (ADR 0019), which all react to *implicit*
jumplist/changelist history via tight, consecutive keystroke streaks. Named marks are for
*deliberately* bookmarking a spot you'll want to return to multiple times across a longer
editing session — e.g. a function definition you keep referencing while editing its many
call sites.

`patterns.feed()` already receives the current `line` on every call (used by `f_repeat`).
No new plumbing was needed, but this is the first pattern in the file to track `line`
*changing over time* rather than just comparing it within a single call.

The open design question (flagged directly in the issue): what threshold/window
distinguishes "genuinely bookmarking one reference point across real work" from "normal
editing that happens to revisit one area," and how to avoid double-firing alongside the
three existing return-oriented patterns for what's really the same event.

## Decision

- **State**: `mark_anchor_line` (the line being tracked), `mark_return_count`,
  `mark_left_anchor` (has the cursor left the anchor since the last count), and
  `mark_edited_away` (did a genuine edit happen while away). `mark_prev_line` tracks the
  last-seen line cheaply so the bookkeeping below only does work on an actual line change.
- **Bookkeeping runs unconditionally at the top of `inner_feed`**, same shape as the
  existing changelist-underuse block (ADR 0019): it observes every key, never
  consumes/returns. On a line change: if there's no anchor yet, the line just *left*
  becomes the new anchor (count starts at 0 — choosing an anchor is not itself a return to
  it); if arriving back at the anchor, `mark_return_count` increments only if the cursor
  had genuinely left AND a genuine edit (`EDIT_OP_KEYS`) happened while away; arriving at
  any other line just marks "left the anchor."
- **Firing is deferred** to the same arbitration block as `manual_return`/
  `changelist_return`, as the lowest-priority `elseif` (after `jump_ready`/`change_ready`/
  `zz_ready`) — checking `seq.mark_return_count >= NAMED_MARK_RETURN_THRESHOLD` (3,
  matching the issue's own "3+ returns"). This means a fire can occasionally be delayed by
  one keystroke if the exact 3rd-return keystroke happens to be consumed by an earlier,
  unrelated handler — the counter isn't reset in that case, so it fires on the very next
  eligible keystroke instead of being lost.
- **Off-by-one caught during testing**: the anchor-establishment step originally
  initialized `mark_return_count = 1` (treating the departure itself as return #1),
  which made the threshold reachable after only 2 genuine leave-edit-return cycles instead
  of 3. Fixed to initialize at 0 — only genuine arrivals back at the anchor count.
- **Re-anchoring bug caught by live tmux QA, not unit tests**: `logger.lua` reads
  `vim.fn.line('.')` inside the `vim.on_key()` callback, which fires *before* the current
  keystroke's own motion is applied — so a motion key's own `line` value is one keystroke
  stale, and the settled destination only becomes visible attached to whichever key
  arrives *next*. This "line arrives one key late" property meant the very first line the
  cursor happened to leave in a session (e.g. wherever it was when the file opened, before
  any deliberate navigation) got permanently locked in as `mark_anchor_line`, since nothing
  ever reset it — the real line the user kept returning to during actual work never got a
  chance to become the anchor at all. Unit tests never caught this because they call
  `patterns.feed()` directly with hand-chosen `line` values per key, sidestepping the
  real one-key-late property entirely. **Fix**: in the "moved to a third line" branch, if
  `mark_return_count == 0` (no genuine return has ever confirmed the anchor is meaningful),
  re-anchor to the line just left instead of keeping the stale one. Once a real return
  lands (`mark_return_count > 0`), the anchor is committed and this re-anchoring never
  fires again until the pattern fires or resets. A dedicated regression test
  (`patterns_spec.lua`, "re-anchors to the real reference line...") reproduces the bug
  shape without needing the real `vim.on_key` timing quirk.
- **Coexistence with `jump_back`/`manual_return`/`changelist_return`**: these three
  require 5 *consecutive* return-motion keystrokes within a 15s tolerance window with
  **no edit in between** (`manual_return`) or exactly two edits with a tight `j`/`k`
  streak back (`changelist_return`). `named_mark_opportunity` requires the opposite — a
  genuine edit between every return. The two shapes are structurally disjoint: a keystroke
  sequence satisfying one cannot satisfy the other, so no explicit mutual-exclusion logic
  was needed beyond each pattern's own precondition.
- Deliberately does **not** try to distinguish "returns to exactly one other line" from
  "returns while doing real work across many other lines" — the distinguishing signal
  used is temporal/behavioral (spread-out editing vs. a tight scroll-back loop), not the
  count of distinct alternate locations. A slow A↔B bounce with real edits at each visit
  is treated as a legitimate `ma` candidate in its own right, not a false positive.

## Consequences

- This is the first `patterns.lua` state machine keyed off `line` changing across calls
  rather than compared once per call — any future line-based pattern should reuse this
  "anchor + left + edited-away" shape rather than re-deriving it, **and must account for
  the one-key-late `line` property** documented above: `logger.lua`'s `vim.fn.line('.')`
  read happens before the current keystroke's own motion applies, so a transition is only
  ever visible on the keystroke *after* the one that caused it. A pure `line ~= prev`
  transition check (as used here) still detects every real transition exactly once
  despite this, but any anchor-selection logic built on top of it must not assume the
  very first observed transition is meaningful — see the re-anchoring fix above.
- The exact threshold (3) and the "any edit anywhere while away" gate are tuned choices,
  not derived from a formula — similar to `JUMP_TOLERANCE_MS`/`FORGOTTEN_RATIO` elsewhere
  in this codebase, expect this to need revisiting from live usage.
- Live interactive QA (tmux + a real Neovim instance) caught a real bug that 100%
  unit-test coverage and passing tests did not — patterns_spec.lua's own `feed()` calls
  supply `line` directly and can't exercise `vim.on_key`'s actual timing. Any future
  line-dependent (or generally "reads live editor state") pattern should get the same
  live QA pass before shipping, not just unit coverage.
