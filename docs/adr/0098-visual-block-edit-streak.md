# Visual-block edit streak → `<C-v>` (#230)

## Context

`<C-v>` (block-visual mode) was already registered in `commands.lua` but had no reactive
detection pattern. The target shape: a user manually repeating the same single-line edit
(e.g. `A;<Esc>` to append a semicolon, `I//<Esc>` to comment out a line) on 3+ consecutive
lines, one at a time, where `<C-v>3jI...<Esc>` would apply it to all of them in one shot.

This is structurally the same "same edit sequence repeated" shape `macro_opportunity`
(ADR 0018) already detects — same anchored-match algorithm, same `seq.macro_buf` rolling
buffer, same cross-mode feed via `M.feed_macro()`. The differences are narrower: the gap
between repeats must be *exactly* one `j` (not macro's flexible up-to-`MACRO_MAX_GAP`
tolerance), and the repeated content itself must look like a plain insert-then-Escape edit,
not any arbitrary repeated sequence.

That narrower shape overlaps with macro_opportunity's own domain: `cwFooBar<Esc>`
repeated 3× with single-`j` gaps is macro_opportunity's own canonical regression test
(from ADR 0018), and a naive gap-only restriction would have silently stolen it.

## Decision

- **Reuses `seq.macro_buf`/`M.feed_macro()` entirely** — no new buffer, no new logger.lua
  wiring. `macro_detect()` now checks `visual_block_detect()` first and only falls
  through to the existing macro_opportunity search if it returns nil. This follows
  `lua/tobira/CLAUDE.md`'s module-splitting policy: this shares state and a call path with
  the existing macro code, so it belongs in the same file/function rather than a sibling.
- `visual_block_check_len(buf, n, l)` mirrors `macro_check_len`'s anchored-match shape
  (search for 3 exact-match occurrences of a length-`L` window) but fixes the gap between
  occurrences to exactly one `'j'` token, and adds two guards `macro_check_len` doesn't
  need: the window's first token must be an `INSERT_KEYS` member and its last token must
  be `'<Esc>'`. The second guard is what excludes `cwFooBar<Esc>`-shaped edits (which
  start with the operator `c`, not an insert key) — without it, visual-block would fire
  instead of macro_opportunity for that exact regression case.
- Because the `INSERT_KEYS`-start guard already guarantees the window contains a
  genuine edit (`INSERT_KEYS ⊂ EDIT_OP_KEYS ⊂ MACRO_EDIT_KEYS`), `visual_block_check_len`
  does **not** call `macro_contains_edit` the way `macro_check_len` does — that check
  would always pass and is dead code here specifically (confirmed via 100% coverage: the
  branch was unreachable until removed).
- Priority is deliberate: the narrower, more actionable `<C-v>` suggestion wins whenever
  both shapes match the same repeated edit, since block-visual is a more precise fix for
  "the same single-line edit down consecutive lines" than "record a macro" is.

## Consequences

- Any future refinement to `MACRO_NAV_KEYS`/`MACRO_MAX_GAP`/`MACRO_MIN_LEN`/
  `MACRO_MAX_LEN` affects both `macro_opportunity` and `visual_block_opportunity` — they
  share the same buffer and length-search bounds.
- If the "single-'j'-gap, insert-then-Escape" shape needs to loosen (e.g. tolerate `l`/`0`
  column-positioning inside the repeated edit before the insert key), that changes which
  events silently move from macro_opportunity's suggestion pool to visual-block's — treat
  it as a live-usage decision, same caution as ADR 0020's `CI_QUOTE_NAV_KEYS`.
