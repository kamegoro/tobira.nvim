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

- **Minimum-complexity floor: `word ~= nil and arg == nil` is excluded too** (added after a
  QA-found false positive on the shipped version of this detector, reproduced live: `:w`,
  make a small edit, `:w` again — identical text `"w"` both times — fired the `q:` suggestion
  for saving a file twice). `feed_history_recall(state, text, word, arg)` takes `arg`
  (`command_arg()`'s second return, the same call already made at the `logger.lua` site for
  `word`) and declines to track anything where a letter-word command was recognized but had no
  argument beyond the (possibly bang-forced) word itself — `:w`, `:q`, `:x`, `:wq`, `:qa`,
  `:noh`, `:qa!`, etc. A bare command word has nothing substantial to mistype or lose by
  retyping it, so the "avoid retyping this" pitch behind `q:` doesn't apply.

  This reuses `command_arg()`'s existing bang-stripping/argument-extraction logic rather than
  inventing a separate length threshold, so it stays a genuine argument/complexity check, not a
  word blacklist: `:w somefile.txt` retyped verbatim still fires, exactly like `:g/foo/d` does
  — the floor is about whether there is content worth not retyping, not about which command
  word was used. This is also why it is a second, independent guard rather than folded into the
  word-family exclusion above: the word-family list excludes specific commands *regardless* of
  argument (a bare `:e` is still ping-pong territory), while this floor excludes *any* command
  that happens to have no argument, regardless of which word it is.

  Scope limit: `command_arg()` only recognizes letter-word commands, so symbolic commands
  (`word == nil`, e.g. `:!somecommand --flags`) are unaffected by this guard and remain fully
  trackable on their raw text, same as before — a `:!` invocation's "word" and "argument" are
  not separable by `command_arg()`. A future length/complexity guard for symbolic commands would
  need its own mechanism; not needed by the QA repro that motivated this fix, which was
  exclusively bare letter-word commands.

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

- **Genuine history recall is excluded too, via a 5th `recalled_via_history` param**
  (added after a QA-found false positive, #259: `:g/uniquepattern123/d<CR>`, then `:`
  `<Up>` `<CR>` — a genuine recall via `<Up>` — still fired the "you retyped instead of
  recalling" suggestion, which is self-contradictory since `<Up>` recall is exactly what
  `q:` teaches). Text equality alone cannot distinguish "manually retyped the same
  command" from "recalled it via `<Up>`/`<Down>` and resubmitted unchanged" — both look
  identical to `vim.fn.getcmdline()` at `<CR>` time. `feed_history_recall(state, text,
  word, arg, recalled_via_history)` now takes a 5th argument and, when true, skips the
  submission ENTIRELY — `state.entries` is left untouched, not merely "not fired" — so a
  genuine recall never consumes the 2-submission slot a later manual retype of the same
  text would need to fire on its own merits.

  `patterns_cmdline.lua` stays vim.\*-free (see the file header) and only ever sees one
  complete string at `<CR>` time, so it cannot observe an `<Up>`/`<Down>` keystroke
  itself. `logger.lua`'s `handle_cmdline_key` tracks it instead: a module-local
  `cmdline_recalled_via_history` flag, set true the moment `<Up>` or `<Down>` is seen
  while `getcmdtype() == ':'`, reset to `false` the moment the cmdline session ends
  (`<CR>`/`<Esc>`/`<C-c>`) — scoped to one open-to-close cmdline session, unlike
  `history_recall_state` which persists for the whole plugin session. This mirrors how
  `word`/`arg`/`win_count` are already threaded in from vim.\* calls this module cannot
  make itself.

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
- The minimum-complexity floor is coarser than perfect in the other direction from the
  word-family exclusion: it is keyed on `arg == nil`, not on how short/trivial the argument
  itself is, so a bare command with a one-character argument (e.g. a hypothetical `:w x`) is
  treated as tracked, not excluded. Accepted — the QA repro and the required test coverage are
  all bare-word-only (`:w`, `:q`, `:x`, `:wq`, `:qa`, `:noh`), and a finer argument-quality
  threshold is exactly the kind of arbitrary magic number this design deliberately avoids in
  favor of reusing `command_arg()`'s existing nil/non-nil contract.
- The `recalled_via_history` signal (#259) is a simple whole-session-scoped boolean, not a
  precise "was THIS submission's text exactly what history returned" check: if the user
  presses `<Up>` and then edits the recalled text before `<CR>`, the submission is still
  treated as a recall and skipped, even though it now differs from — or coincidentally
  matches — a prior manual entry. Accepted: the flag exists to fix the specific
  self-contradictory case (recall-then-resubmit-unchanged), not to build a full
  keystroke-level diff of "how much editing happened after recall." A finer-grained signal
  would need to track cursor/text state across the whole cmdline session, which is exactly
  the per-keystroke complexity `patterns_cmdline.lua`'s one-shot-string design (see this
  ADR's own file header) and the tracking design principle in `lua/tobira/CLAUDE.md`
  deliberately avoid.
- Only `<Up>`/`<Down>` are treated as history-navigation keys, matching the issue's own
  repro. `<C-p>`/`<C-n>` (which behave identically to `<Up>`/`<Down>` for cmdline history
  recall per `:help c_CTRL-P`) and the command-line window (`q:`/`c_CTRL-F`) are not
  tracked as recall signals yet. If a future QA repro surfaces a false positive through one
  of those paths, extend the `key == CMDLINE_UP or key == CMDLINE_DOWN` check in
  `logger.lua`'s `handle_cmdline_key` the same way.
- Symbolic commands (`:!`, `:@`, `:=`, ...) have no equivalent floor — see the scope-limit note
  above. A bare `:!` retyped twice still fires today, same as before this fix. If that turns
  out to be a real-world false positive too, it needs its own guard (symbolic commands have no
  `command_arg()`-recognized word/argument split to reuse).
