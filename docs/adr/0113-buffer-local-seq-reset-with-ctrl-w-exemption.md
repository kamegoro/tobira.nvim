# Buffer-local `seq` reset on `BufEnter`, with a `<C-w>` streak exemption

## Context

`logger.lua` declares `local seq = patterns.new_seq()` once at module load and
never resets or re-scopes it per buffer. Every streak-based pattern (dd/cc
streaks, indent/dedent streaks, ci-quote streaks, r-streaks, fold streaks,
the plain `seq.run` consecutive-key counter used by j/k/l/h/w/b/e/x/p/~/.,
etc.) is therefore a single continuous counter across the whole Neovim
session, not scoped to "the same editing context": 2x `dd` in one buffer
followed by 1x `dd` immediately after switching to an unrelated buffer fires
`dd_run`, attributing a three-in-a-row habit to a streak the user never
actually performed in one place. The same applies to `j_repeat` and every
other streak field `seq` carries.

A blanket "reset everything on any window/buffer focus change" is too
aggressive, though: `<C-w>q`/`<C-w>c`'s own effect on a window layout IS a
window (and often buffer) switch, so resetting `seq` on every such switch
would make `ctrl_w_close_repeat`/`ctrl_w_resize_repeat` — which are
specifically 2+ `<C-w>X` compounds pressed across consecutive window
switches by construction — structurally undetectable. `<C-w>s`/`<C-w>v`
(split) also move focus to a new window showing the SAME buffer.

## Decision

Reset `seq` on `BufEnter` (not `WinEnter`), preserving only the `<C-w>`
window-command streak fields (`pending_ctrl_w`, `ctrl_w_close_streak`,
`ctrl_w_resize_streak`) across the reset:

```lua
function M.reset_for_buffer_switch(seq)
  local fresh = M.new_seq()
  fresh.pending_ctrl_w = seq.pending_ctrl_w
  fresh.ctrl_w_close_streak = seq.ctrl_w_close_streak
  fresh.ctrl_w_resize_streak = seq.ctrl_w_resize_streak
  return fresh
end
```

`logger.lua`'s `M.setup()` registers a `BufEnter` autocmd that reassigns
`seq = patterns.reset_for_buffer_switch(seq)`.

`BufEnter` rather than `WinEnter` specifically: `BufEnter` only fires when
the CURRENT buffer identity actually changes. Switching between two windows
showing the same buffer (`<C-w>w` between two splits of one file) does not
fire it, so that case correctly keeps every streak's continuity — it is
genuinely the same editing context, just viewed through a different window.
`WinEnter` fires on every window focus change regardless of buffer identity,
which would have reset ordinary streaks (dd, j, r, …) on every `<C-w>w`
between same-buffer splits — far more aggressive than the bug report's own
repro, which is specifically about buffer switches.

The `<C-w>` exemption is intentionally narrow: only the two streak counters
and the one pending flag that `<C-w>`'s own compound grammar needs are
preserved. Every other field (including `macro_buf`, since a repeated-edit
macro suggestion spanning an unrelated buffer switch doesn't make sense
either) resets to its fresh-`new_seq()` default, same as any other buffer
switch.

## Consequences

- Streaks now correctly require continuity within one buffer to fire — the
  exact false-positive the bug report describes (`dd_run`/`j_repeat` firing
  across an unrelated buffer switch) no longer reproduces.
- `<C-w>q`/`<C-w>c`/`<C-w>s`/`<C-w>v`-driven `ctrl_w_close_repeat`/
  `ctrl_w_resize_repeat` streaks still fire correctly across the very window
  (and buffer) switches those compounds themselves cause.
- Tab switches that do not change the current buffer (rare — most tab
  switches also change buffer) do not reset `seq`. This is a known,
  accepted limitation: `BufEnter` cannot distinguish "same buffer, different
  tab" from "never left this buffer" and this design does not attempt to.
- A future streak field that, like `<C-w>`'s, is genuinely meant to span
  buffer switches by construction needs the same explicit exemption added to
  `reset_for_buffer_switch` — it is not automatic.
