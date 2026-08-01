# Register/mark/bracket single-char prefix consumers, and the `"+y` tail-guard bug (`patterns.lua`)

## Context

`"`, `@`, `m`, `'`, `` ` ``, `[`, `]` each start a two-key sequence whose
second key is arbitrary (a register name, mark name, or bracket target) and
carries no pattern-detection meaning on its own — most of these just need to
be consumed so they don't fall through and get misinterpreted as something
else. One combination needs special handling: `"+y` (explicit yank to the
system-clipboard register).

## Decision

- `pending_register`/`pending_mark`/`pending_bracket` are generic one-key
  consumers (`key_consumed = true`, no further action) — except
  `pending_register` additionally arms `pending_clipboard_yank` when the
  register consumed was specifically `+`.
- `pending_clipboard_yank` + `clipboard_yank_tail`: completing `"+y` sets
  `last_op = '"+y'` AND arms a one-key `clipboard_yank_tail` guard. Bug this
  fixes: without the guard, the very next `y` (as in `"+yy`) falls through to
  the generic operator-start branch and sets a dangling `pending_op = 'y'`
  that silently eats the FOLLOWING keystroke too. Repro: `"+yy` followed by 5
  `j` presses needed a 6th press to fire `j_repeat` — the dangling
  `pending_op` had swallowed one of the 5.
- `pending_mark` also resolves the `gq`-then-backtick jump-back case (see
  `docs/adr/0022-gq-operator-pending-and-post-format-jumpback.md`), since
  `` ` `` is one of the three mark-prefix keys.

## Consequences

- Any future `"‹key›‹key›`-shaped compound needs the same tail-guard pattern
  if its second key could otherwise be reinterpreted as an operator start —
  omitting the guard reintroduces the dangling-`pending_op` bug above.
