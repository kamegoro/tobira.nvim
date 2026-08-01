# Insert-mode completion-repeat: token reconstruction, threshold, and ring size

## Context

Users sometimes retype an entire identifier or method name by hand a second
time instead of using `<C-n>`/`<C-p>` keyword completion (#112). Detecting
"the same token was just typed out in full a second time" has to work purely
from keystrokes — tobira tracks only via `vim.on_key`, never by reading
buffer content (see `lua/tobira/CLAUDE.md`'s tracking design principle) — so
this needed its own answers to: what counts as a token boundary, how long a
token must be before it's worth remembering (short, extremely common
keywords must never false-positive), how much history to keep, and how a
mid-token correction (backspace vs. cursor movement) should affect the
in-progress token.

## Decision

- **Token reconstruction:** word characters (`%w_`) accumulate into
  `iseq.token`; any non-word character or `<Esc>` closes the token. Purely
  keystroke-driven; identifiers are assumed ASCII (no multi-byte handling).
- **`TOKEN_LEN_THRESHOLD = 6`**, chosen specifically to clear common short
  keywords that are typed repeatedly and legitimately all the time —
  `const`, `class`, `value`, `break`, `while` are all 5 characters — while
  still catching the identifiers/method names the pattern targets. Tokens
  under the threshold are discarded before ever entering the ring buffer
  (not merely excluded from matching), so short words can never accumulate
  enough history to match later no matter how often they repeat.
- **`RING_SIZE = 8`**: large enough to span a typical line or two of real
  code, small enough to keep memory bounded. Because matches are always
  exact-string repeats, a larger buffer only ever produces more (still
  valid) matches, never more false positives — 8 is a deliberately modest
  starting point, not a value tuned against a specific observed failure.
- **`<Left>`/`<Right>` abandon the in-progress token** (reset it to `''`)
  instead of finalizing it: once the cursor moves off the end of what's been
  typed, further characters may land in the middle of the word rather than
  being appended, so the accumulated string can no longer be trusted to
  match what's actually in the buffer. This is a conservative false
  negative, not a false-positive risk. **`<BS>` instead truncates** the last
  accumulated character, since deleting backward from the end keeps the
  append-only assumption valid — unlike cursor movement.

## Consequences

- Raising or lowering `TOKEN_LEN_THRESHOLD` changes which real-world keywords
  false-positive; 6 was picked empirically against common keyword lengths,
  not derived from a formula. Revisit by checking common keyword lengths in
  the languages tobira's users actually edit, if it ever needs to change.
- `RING_SIZE` is not load-bearing for correctness — any size avoids false
  positives — only for how far back a repeat can be detected, traded off
  against its (bounded) memory cost.
- Any future change to what counts as a token boundary must also decide how
  `<Left>`/`<Right>` interact with it: finalizing on cursor movement instead
  of abandoning risks recording tokens that don't match the actual buffer
  content.
