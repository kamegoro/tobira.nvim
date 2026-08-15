# Distinguishing Normal-mode edit tokens from insert-mode characters in `feed_macro`

## Context

`patterns.feed_macro()`'s `MACRO_EDIT_KEYS` set (`d`, `c`, `y`, `>`, `<`,
plus `EDIT_OP_KEYS` = `x`, `X`, `i`, `I`, `a`, `A`, `o`, `O`, `s`, `S`) was
designed to recognize genuine Normal-mode edit operators — the keys that
start an edit sequence worth recording as a macro (`docs/adr/0018`). But
`logger.lua` feeds `feed_macro()` from TWO call sites that share this one
function: the Normal-mode branch of `handle_key()` (real operator
keystrokes) AND `handle_insert_key()` (the raw characters an insert-mode
keystroke stream produces, needed because a repeated edit like
`cwFooBar<Esc>` spans into insert mode — see `docs/adr/0016`'s cross-mode
call).

Both call sites feed the SAME `MACRO_EDIT_KEYS`-checking logic the SAME raw
character. An ordinary word typed in insert mode that happens to contain
`d`, `i`, `a`, `o`, `s`, `x`, `c`, or `y` — most English/code identifiers —
can anchor-match `macro_opportunity` purely because its own letters
coincide with the operator alphabet, with no relationship to "the user is
repeating an edit." Typing `diamond` three times (containing `d`/`i`/`a`/`o`,
all `MACRO_EDIT_KEYS` members) reliably triggered this. Per `docs/adr/0016`'s
unqualified `macro_result > result` priority, the spurious
`macro_opportunity` fire then silently swallowed whichever of
`patterns_insert.lua`'s 6 patterns would otherwise have fired on that same
keystroke — in practice, `insert_completion_repeat` (the correct "you
retyped this identifier instead of using `<C-n>`" suggestion) going missing
exactly when it should have fired.

## Decision

`feed_macro()` gains an explicit `is_normal_key` parameter that the CALLER
supplies, since only the caller (`logger.lua`) knows which of its two call
sites is feeding the token:

```lua
function M.feed_macro(seq, token, now, is_normal_key)
  ...
  buf[#buf + 1] = { tok = token, t = t, nav_run = nav_run, is_normal_key = is_normal_key == true }
  ...
end
```

`logger.lua`'s Normal-mode call site passes `true`; `handle_insert_key`'s
call site passes `false` (its tokens are ordinary typed characters or their
canonical `<Esc>`/`<BS>`/etc. names, never a genuine Normal-mode operator
keystroke).

`macro_contains_edit` (the check gating `macro_opportunity`) and
`visual_block_check_len`'s own start-of-window check (the check gating
`visual_block_opportunity`, which shares the same `MACRO_EDIT_KEYS`⊂
`INSERT_KEYS` overlap) both now require `buf[i].is_normal_key` in addition
to the existing `MACRO_EDIT_KEYS[buf[i].tok]` membership check — a token
recorded from insert-mode dispatch can never satisfy either, regardless of
which character it happens to be.

Only the CONTENT checks (`macro_contains_edit`,
`visual_block_check_len`'s start-key check) are gated this way.
`macro_windows_equal` (whether two windows are the SAME sequence of tokens)
and `macro_contains_bad` (whether S contains a `q`/`@` register key) are
deliberately left unchanged — window-equality and the register-key
exclusion are about the LITERAL token sequence matching or not, independent
of which mode a token was typed in, and `<Esc>` itself (needed to close the
loop on a `cwFooBar<Esc>`-shaped edit, and always fed from
`handle_insert_key`'s own mode-exit call) is not a `MACRO_EDIT_KEYS` member
either way, so it is unaffected by this gate.

## Consequences

- Ordinary prose/code typed in insert mode can no longer anchor-match
  `macro_opportunity`/`visual_block_opportunity` no matter which letters it
  contains — `insert_completion_repeat` and the other
  `patterns_insert.lua` patterns can no longer be silently swallowed by a
  same-shape coincidence.
- Genuine Normal-mode-triggered macro detection (`cwFooBar<Esc>` × 3, the
  canonical example) is unaffected: the operator keystroke that STARTS the
  edit (`c`, `x`, `i`, …) is always fed from the Normal-mode call site
  (`is_normal_key = true`), which is the only token `macro_contains_edit`
  needs to find within a window to qualify it.
- Any future call site that feeds `feed_macro()` (a new mode, a new
  cross-mode bridge) must decide and pass `is_normal_key` explicitly — an
  omitted argument defaults to `false` (no `MACRO_EDIT_KEYS` credit), the
  safer default given this bug's shape.
