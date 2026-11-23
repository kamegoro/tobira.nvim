# Reactive suggestions are idle-gated and shown only in their own context

## Context

`suggest.queue()` armed a one-shot `vim.defer_fn(idle_delay)` when a pattern
fired. Later keystrokes never touched that timer, so `idle_delay` was a fixed
delay after the pattern, not a pause. `resolve_queued()` then called
`M.show()`, which checked neither the mode nor the buffer (only the ambient
`fire_ambient()` checked for Normal mode). Two reproductions (#356):

- `dddddd`, then `o` and keep typing at ~4 keys/s: the `{n}dd` float appeared
  1.5s later while the user was still in Insert mode.
- With an ambient suggestion holding the cooldown, `j`×10, then `:e other`
  and type in Insert mode: when the cooldown lifted (the cooldown-retry from
  docs/adr/0112-unified-suggestion-scheduling.md), "You pressed j 10 times"
  appeared in the other buffer, in Insert mode.

## Decision

- **True idle.** While a reactive suggestion is pending, a `vim.on_key`
  watcher (its own namespace, attached only while something is pending)
  restarts the timer for `idle_delay` on every typed key (`typed ~= ''`).
- **Context check at show time.** When the timer finally resolves (including
  after the cooldown-retry wait, which is kept), the suggestion is shown only
  if the current window and buffer are the ones the triggering keystroke left
  the user in, and the mode is Normal (`mode():sub(1, 1) == 'n'`, the same test
  `fire_ambient()` uses). The `terminal` category is also allowed in Terminal
  mode, since its whole point is to appear while the user is stuck there
  (docs/adr/0046-terminal-category-cooldown-bypass.md). If the check fails the
  suggestion is dropped, not kept for a later pause.
- **Anchor after the key is applied.** `queue()` runs inside logger's
  `vim.on_key` callback, before Neovim applies the key. Patterns whose last
  key itself moves the user (`:e a<CR>` for `ex_file_pingpong`, `:tabnew`,
  `<C-w>c`) would otherwise be anchored to the buffer/window being left and
  never shown. So the buffer/window capture and the watcher attachment run in
  a `vim.schedule` callback. This also avoids adding a key to `vim.on_key`'s
  callback table while Neovim is iterating it with `pairs()`.
- **Stale timer callbacks are ignored.** `vim.defer_fn` schedules its callback
  when the timer expires; closing the timer after that does not cancel it. A
  keystroke landing between the two would otherwise let the old callback
  resolve early. Each armed timer only resolves if it is still
  `session.timer`.

Deliberately not done: an expiry time after which a pending suggestion is
dropped. The context check removes the reported cases (wrong mode, wrong
buffer), but a suggestion can still appear long after its pattern when the
user stays in the same window and buffer: measured with
`suggestion_cooldown = 12`, a `j_many` suggestion queued during the cooldown
and followed by 14s of steady `h`/`l` movement appeared 15.5s after the
`j` streak. With the default 300s cooldown the bound is the cooldown plus the
first pause. Whether that is acceptable, and what limit to use, is a product
decision left open here.

## Consequences

- Nothing reactive appears while the user is typing; it waits for the first
  `idle_delay` pause.
- A reactive suggestion whose pause happens in Insert, Visual, Command-line
  or Terminal mode (other than the terminal tip), or in another window or
  buffer, is lost. Insert-mode patterns survive the usual flow (keep typing,
  `<Esc>`, pause) because every key restarts the wait, but a pause of
  `idle_delay` inside Insert mode drops them.
- Returning to the original buffer and window before the pause still shows
  the suggestion: the check is made at show time, not on every buffer switch.
- At most one extra `vim.on_key` namespace (`tobira_pending`) exists, and it
  is detached whenever nothing is pending.
