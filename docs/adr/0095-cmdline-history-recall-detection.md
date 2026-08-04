# Verbatim Ex-command retype detection (#241, `patterns_cmdline.lua`)

## Context

`patterns_cmdline.lua` already detects three specific cases of "retyping instead of
recalling": the same `:s///` pattern+replacement re-run on a new line (`substitute_repeat`,
#115), bouncing between the same two files with `:e`/`:b` (`ex_file_pingpong`, #114), and
opening one file per tab with `:tabnew` (`tabnew_run`, #113). Each teaches a specific,
narrow shortcut (`&`/`g&`, `<C-^>`, `<C-^>`) for its own specific habit.

None of these cover the general case: retyping *any other* Ex command verbatim — a long
`:e some/deeply/nested/path` reused as a one-off jump target rather than part of a
file-switch bounce, a `:g/pattern/d` re-run after undoing to check it again, a specific
`:!somecommand --flags` re-invoked — instead of recalling it from command-line history
(`:` then `<Up>`, or `q:`/the command-line window). The risk in adding a fourth, more
general detector to the same dispatch path is double-firing: retyping a `:s///` or
bouncing `:e`/`:b` twice would trivially also satisfy "the same full command line was
submitted twice", so a naive implementation would fire the generic suggestion ON TOP OF
(or instead of) the specific one every single time those three already fire.

## Decision

- **Exclusion by command WORD, not by exact-scope match with the specific detector's own
  parsing rules.** `feed_history_recall(state, text, word)` takes `word` — the same
  lowercased command word `command_arg()` already extracts for the ping-pong/tabnew
  detectors — and declines to track anything where:
  - `word` is a recognized abbreviation of `:substitute` (reuses `is_substitute_word()`,
    factored out of `track_substitute()` so both share one definition instead of two
    diverging over time).
  - `word` is exactly `e` or `b` (reuses the same private `PINGPONG_COMMANDS` table
    `feed_pingpong()` already uses), regardless of whether an argument was given — a bare
    `:e`/`:b` retyped verbatim is still "ping-pong territory" even though
    `feed_pingpong()` itself only acts once an argument is present.
  - `word` is exactly `tabnew`.

  This is deliberately coarser than each specific detector's own scope. `track_substitute()`
  declines a *ranged* substitute (`:%s/foo/bar/`, out of scope per
  `docs/adr/0006-cmdline-substitute-repeat-detection.md`) — but `feed_history_recall()`
  still excludes it, by word alone, rather than falling through and suggesting the generic
  `q:` hint for it. The alternative (mirroring each detector's exact scope, including range/
  argument checks) would require duplicating their full parsing logic a second time just for
  the exclusion test. The trade-off: a handful of edge cases inside the "claimed" families
  (ranged `:%s`, bare `:e`/`:b`) get no suggestion at all rather than a second-best generic
  one. This is the safer failure mode — the same edit habit can never earn two competing
  suggestions, which is the actual hazard #241 flagged.

  Command abbreviations the specific detectors don't recognize (`:edit`, `:buffer`) are NOT
  excluded and correctly fall through to this generic detector — same "abbreviations aren't
  recognized" scope limit `feed_pingpong()` documents in
  `docs/adr/0004-ex-file-pingpong-detection.md`, now generalized as a feature rather than a
  gap: whatever the specific detectors don't claim, this one picks up.

- **No priority-resolution logic is needed at the `logger.lua` call site** (contrast
  `docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md`, which had to establish an
  explicit `macro_result > result > co_result` order because multiple Normal-mode detectors
  can genuinely fire on the very same keystroke). Here, the word-based exclusion makes firing
  mutually exclusive by construction: for any given submitted command line, at most one of
  the four cmdline detectors can ever return non-nil. `logger.lua` simply calls all of them
  unconditionally, gated only by the pre-existing `OWN_CMD_PREFIX` check that already guards
  `increment()`.

- **State shape mirrors `new_substitute_state()`**: `{ entries = { [trimmed_text] =
  { count, fired } } }`, persisting for the whole session (not reset per-keystroke, same
  lifetime as `substitute_state`/`pingpong_seq`/`tabnew_seq`). Fires once, on the 2nd
  identical submission, then latches (`entry.fired`) so a 3rd, 4th, ... resubmission of the
  same text does not notify again — same "fire once, not on every repeat" precedent as
  `ex_file_pingpong`'s rotation latch and `substitute_repeat`'s count===2/count===3 branches
  (which likewise go silent past the 3rd).

- **No time window.** Entries accumulate for the whole session, exactly like
  `substitute_state`. The issue's "within a short window" framing is a description of the
  intended user experience (you just retyped this a moment ago), not a hard timing
  requirement this module needs new `vim.loop.now()`-threading infrastructure to enforce —
  none of the other three cmdline detectors use elapsed time either.

- **No verify-before-credit deferral** (contrast
  `docs/adr/0015-ex-command-verify-before-credit.md`, which defers and re-checks
  `changedtick`/buffer state for `:s`/`:e`/`:b`/`:tabnew` because "submitted" and "succeeded"
  are different events for those). For this detector the signal IS the retyping itself, not
  any effect the command has — a command that fails identically both times (e.g. a typo'd
  `:!somecommand` re-run unchanged) still means the user typed the same doomed text twice
  instead of recalling and fixing it from history. `logger.lua` calls `feed_history_recall()`
  synchronously at `<CR>` time, no `vim.schedule()` involved.

- **Suggested command is the pre-existing `q:` registry entry**, not a new one. `q:` (open
  the command-line window) already exists in `commands.lua` with full locale strings in all
  6 locales — no registry or locale-string changes were needed for the *suggested command*
  itself, only a new `float.reasons.cmdline_history_recall` entry (the "why this fired"
  line) per locale.

## Consequences

- Any future 4th+ cmdline-specific detector must extend `feed_history_recall()`'s exclusion
  condition the same way (add its claimed word(s) to the `if word and (...)` guard) —
  otherwise the generic detector will start double-firing alongside it, the exact failure
  mode this design avoids for the first three.
- The word-based exclusion is coarser than perfect: a few edge cases inside the "claimed"
  command families (a ranged `:%s`, a bare `:e`/`:b`) get no suggestion from either detector.
  Accepted, per the trade-off above — see `patterns_cmdline_spec.lua`'s
  `feed_history_recall` tests for the exact pinned boundary cases.
- Because entries never expire mid-session, a command line typed once early in a long
  session and identically retyped hours later still counts as a "2nd submission" — consistent
  with `substitute_repeat`'s existing whole-session behavior, not a new inconsistency.
