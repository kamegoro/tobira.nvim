# n_repeat becomes intent-neutral; cgn moves to a reactive n_then_change pattern (#245)

## Context

`n_repeat` fired on the 4th consecutive `n` press and unconditionally suggested `cgn`
(change-next-match), assuming a long `n`-streak means the user is about to edit every
match. Research into real Vim usage (Practical Vim and community documentation on the
`cgn` + `.` workflow) found the opposite: the efficient way to use `cgn` is to type
`cgn<replacement><Esc>` on the very *first* match, then repeat with `.`/`n.` — expert
users deliberately avoid racking up a bare `n`-streak before deciding to edit, because
avoiding exactly that manual re-navigation is the whole point of `cgn` + `.`. A long
`n`-streak with no editing action is therefore a weak signal for "about to batch-edit"
and a much better signal for plain browsing/reading through matches (or a precursor to
`:%s///g` instead).

`j_repeat`/`k_repeat`, the sibling motion-streak patterns in the same file, already
handle this exact ambiguity correctly: they suggest an intent-neutral count-prefix
(`{n}j`/`{n}k`) rather than assuming what the user wants to do next with the line they
land on. `n_repeat` was the odd one out.

## Decision

**Part 1 — `n_repeat` becomes intent-neutral.** Same trigger (the key `n`, count == 4,
same location in the `patterns.lua` threshold chain), but it now suggests `{n}n`
(count-prefix jump to the Nth next match) instead of `cgn`, mirroring `j_repeat`/
`k_repeat` exactly. `{n}n` is a new `commands.lua` entry (`requires = 'n'`), following
the same shape as `{n}j`/`{n}k`. `float.reasons.n_repeat`'s text ("You repeated a search
match 4 times") already only describes the *trigger*, not the suggested command — same
as `j_repeat`'s/`k_repeat`'s reason strings — so it needed no wording change; only the
`{n}n` suggestion strings (title/body/example, all 6 locales) were added.

**Part 2 — `cgn` moves to a new reactive pattern, `n_then_change`.** This fires only once
real edit intent is confirmed: an `n`-streak of 2 or more, followed shortly after by a
`c`-family change completing at (roughly) the cursor's position — `cw`, `ciw`, `caw`,
`ce`, `ci"`, `c3w`, etc. (anything that normalizes to `last_op == 'cw'` in this file's
existing operator-grammar reconstruction — see `lua/tobira/CLAUDE.md`'s "patterns.lua —
state machine" section), with no unrelated intervening key. `cc`/`cj`/`ck` (whole-line
change) are deliberately excluded — "changed the match" is a word/char-level claim, not
a line-level one.

Detection mechanics, modeled on the arm/consume/expire shape of
`diff_jump_then_insert_next`/`_prev` (`do`/`dp`, ADR 0099):

- A new `seq.n_change_watch` boolean arms when the `n`-streak counter reaches exactly 2
  (using the existing `track_run()` counter shared by all consecutive-key patterns, no
  new counter needed) — a lower, secondary threshold than `n_repeat`'s 4, since this
  pattern only *proposes* a candidate window rather than firing on the spot.
- An unconditional, top-of-`inner_feed` observer (same style as the existing
  changelist-underuse/`<C-o>`/named-mark blocks) expires the watch on any key that is
  not `'n'` (streak continuing) and not part of building a `'c'`-family change already in
  progress (`seq.pending_op == 'c'` or `seq.pending_text_obj == 'c'`, covering `c`,
  digit counts like `c3w`, and text-object prefixes like `ciw`/`ci"`). Any other key —
  a different operator, an unrelated motion, `:`, etc. — expires the watch immediately,
  enforcing "no unrelated intervening motion."
- The watch is consumed at the two places in this file where `last_op` is freshly set to
  `'cw'` (`op_completed = true`): the charwise-motion branch of `pending_op` (`cw`, `ce`,
  `c3w`, ...) and the `pending_text_obj` completion branch (`ciw`, `ci"`, `cit`, ...).
  Both fire `{ pattern = 'n_then_change', cmd = 'cgn' }` and clear the watch. The
  text-object site checks after its own `ci_dquote_repeat`/`ci_squote_repeat` streak
  logic, so an already-qualifying streak pattern keeps priority on the rare call where
  both conditions coincide.
- No wall-clock timer and no `logger.lua`/`vim.on_key` changes: like most patterns in
  this file, the whole state machine lives in `patterns.lua`'s pure `seq`/`feed()`, keyed
  entirely off keystroke sequencing (arm → survive-while-building → consume-or-expire),
  not elapsed time. `cw`/`ciw`/etc. never cross a mode boundary before completing (unlike
  `dw` + a separate insert-entry key), so — unlike `diff_jump_then_insert_next`/`_prev`,
  which waits for the *next* key after its trigger completes — `n_then_change` fires in
  the very same call that completes the change, no extra key required.

`cgn`'s `commands.lua` entry gets two flags, not one:

- `ambient = false` (the usual reactive-only carve-out, ADR 0007): excludes it from
  `find_best()`'s idle picker / `:Tobira` manual.
- `try_next = false`, a new and narrower flag, added to `graph.efficiency_gaps()`'s own
  gate: excludes it from `:TobiraStats`'s "Try these next" panel too. This had to be a
  *separate* flag from `ambient` — `ambient = false` was never wired into
  `efficiency_gaps()`, and an existing `ui_stats_spec.lua` test relies on that: the
  `<C-\><C-n>` entry is `ambient = false` yet deliberately still appears in "Try these
  next" (its own count-alignment hardening test uses it as a fixture). Blindly gating
  `efficiency_gaps()` on `ambient` would have silently changed that unrelated, already-
  accepted behavior. `cgn` is different in kind, not just degree: unlike `<C-\><C-n>` or
  `do`/`dp` (whose triggers structurally never earn a real count), `cgn`'s trigger `n` is
  a normal, heavily-used tracked key — so without `try_next = false`, a heavy `n` user
  would still see "you use n a lot, try cgn" as a stats-panel row, which is exactly the
  browsing-vs-editing false positive this whole fix removes from `n_repeat`. `try_next`
  is scoped to `cgn` only; `do`/`dp` and `<C-\><C-n>` are untouched by it.

## Consequences

- Catches: users who search-and-browse with `n` no longer get an unconditional `cgn`
  nudge; they get the same kind of neutral count-prefix nudge `j`/`k`-streak users
  already get. Users who *do* follow an `n`-streak with an actual change now get `cgn`
  suggested right when the evidence is strongest, not four keystrokes into a browsing
  session that may never edit anything.
- Misses: a user who searches, changes the match, but takes an unrelated action (even a
  single keystroke) in between still won't get the reactive suggestion — same
  "immediately following, no exceptions" trade-off already accepted for
  `dw_then_insert`/`diff_jump_then_insert_next`/`_prev`. A user who `cw`s the very first
  match without ever building an `n`-streak (arguably the *most* efficient `cgn` usage,
  per the Practical Vim research this ADR opens with) still gets no suggestion at all —
  `n_then_change` only watches after 2+ `n` presses, matching the issue's original scope
  (n-streak-driven false positives), not a general "detect any single change-after-search
  opportunity" pattern.
- `try_next` is a new registry field, orthogonal to `ambient`. Any future entry that
  needs "hide from find_best but keep in Try These Next" (the existing precedent) should
  use `ambient = false` alone, as before; any entry that needs "hide from Try These Next
  specifically because its trigger's raw count would otherwise reproduce a design flaw"
  should reach for `try_next = false`, following `cgn`'s reasoning here rather than
  reusing `ambient` for a purpose it was never wired to serve.
