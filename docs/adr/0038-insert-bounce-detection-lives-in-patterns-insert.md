# Insert-mode bounce detection lives in `patterns_insert.lua`, not `logger.lua`

## Context

`insert_bounce` fires when a user enters and immediately leaves insert mode
with nothing typed, twice in a row — the "reflexively hit `i` then `<Esc>`"
habit — and suggests `A`. Implementing it needs to know, at the moment
`<Esc>` is processed, whether the insert session that's ending was empty.

`logger.lua` caches the current mode via a `ModeChanged` autocmd rather than
calling `vim.fn.mode()` on every keystroke (see "vim.on_key() performance" in
`lua/tobira/CLAUDE.md`). That autocmd fires as a *result* of Neovim processing
the `<Esc>` keystroke, which means the keystroke itself is delivered to
`vim.on_key` — and therefore to `logger.lua`'s insert-mode branch — *before*
the mode cache flips to `'n'`. So at the exact point `feed_insert` sees
`'<Esc>'`, the mode cache still reads `'i'`, and this key is still routed here
exactly like every other insert-mode key.

## Decision

Bounce-streak bookkeeping (`had_input`, `bounce_streak`) lives in this file's
`feed_insert`, keyed off receiving `canonical == '<Esc>'`, rather than as
separate mode-transition bookkeeping added to `logger.lua` (e.g. hooking
`ModeChanged` directly to ask "was the session that just ended empty?"). This
keeps "was insert mode empty" entirely inside the one file that already owns
all other insert-mode state, and it relies on — rather than works around —
the documented delivery order of `vim.on_key` versus `ModeChanged`.

## Consequences

- Bounce detection depends on `vim.on_key` delivering `<Esc>` before
  `ModeChanged` flips the mode cache. If a future Neovim version ever changed
  that ordering, bounce detection would silently stop firing — there is no
  test that can assert on event ordering directly, so a "bounce stopped
  working" report should start here.
- Because `<Esc>` is still an insert-mode key at delivery time, the same
  `feed_insert('<Esc>')` branch is also where arming the `<C-o>` one-shot
  watch (ADR 0037) and finalizing the in-progress completion token
  (ADR 0039) happen — all three rely on the same ordering fact.
