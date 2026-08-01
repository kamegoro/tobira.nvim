# Macro-opportunity detection (`patterns.lua`)

## Context

Feature #60: detect the user manually repeating an identical edit sequence 3+
times — exactly the case where recording a macro (`qq...q`, then `@q`) would
have paid off — and suggest it.

The repeated *edit* this cares about (e.g. `cwFooBar<Esc>`) spans into insert
mode. Piping those characters through `inner_feed()` would corrupt its
normal-mode operator-pending grammar (a stray `F` while `pending_op` is set
would misfire as a find-command) — the same shape of problem
`patterns_insert.lua`'s `feed_after_escape()` solves one file over.

A naive per-character classifier ("h/j/k/l/w/b/e/W/B/E/0/$/^ are motion keys —
scan for motion runs") misfires on the feature's own headline example:
`cwFooBar<Esc>` contains a lowercase `w` and uppercase `B`, both motion keys,
so a naive scanner would treat characters INSIDE the repeated sequence as
navigation BETWEEN repetitions.

## Decision

- **Own entry point, own buffer.** `M.feed_macro(seq, token, now)` is fed
  through its own call site (`logger.lua`'s `handle_macro_key()`) from BOTH
  the normal- and insert-mode branches, using `seq.macro_buf` — a rolling
  buffer distinct from `suggest.lua`'s 20-char adoption-watching one (that one
  watches adoption of an already-shown suggestion, and is far too short to
  hold 3 repetitions of a 15-key sequence).
- **Anchored-match algorithm, not a per-character scan.** For each candidate
  window length `L`, find exact matches of the trailing length-`L` window
  against earlier buffer content, and only apply the "gap must be pure
  navigation" check to keys strictly BETWEEN two matched occurrences — never
  to characters inside an occurrence. This is what avoids the `cwFooBar<Esc>`
  false negative above.
- **S must not itself contain a register/macro key** (`q` or `@`) —
  recording a macro to replay a sequence that already plays or records one is
  not a sane suggestion.
- **S must contain at least one genuine edit keystroke**, not just any 3+
  exact repeat of nav-only keys. Follow-up bug this fixes: `"jjjjjjjjjjjj"` and
  `"0fh0fh0fh0fh"` both satisfied every other check, since the anchored-match
  algorithm only inspects the GAP between occurrences for navigation-key
  membership, and neither repro has a gap at all (the repeats are
  back-to-back). This content check runs deliberately LAST, only once the
  anchored match itself is fully confirmed, so the gap-classification logic
  stays untouched by it.
- **Bounded search, not a rescan per keystroke.** `L` ranges over
  `[MACRO_MIN_LEN, MACRO_MAX_LEN]` (3–15); how far back each `L` searches is
  capped by that position's per-keystroke navigation-run counter (`nav_run`,
  O(1) to maintain) at `MACRO_MAX_GAP` (20) — so the common case tries one
  candidate per `L`, widening only when a real navigation streak exists to
  search across. `macro_buf` is trimmed back down to a soft cap once it hits
  a hard cap, amortised O(1).
- All 3 occurrences must fall within `MACRO_WINDOW_MS` (30s).

## Consequences

- Touching macro detection requires understanding both the anchored-match
  search AND its two follow-up-bug guards (`macro_contains_bad`,
  `macro_contains_edit`) — removing either guard reintroduces a known false
  positive/negative, not just a style regression.
- Any future "repeated edit sequence" classifier elsewhere in the codebase
  should reuse this "gap-check only applies between occurrences, never
  inside one" shape rather than re-deriving it from scratch.
