# Preview strip: fixed two-line contract, in-place refresh, no redundant open-guard

## Context

`M.preview_lines(item, usage)` describes whatever skill is under the cursor
and is called twice in different circumstances: once from `M.build()` before
any window or cursor exists (to reserve the strip's space), and repeatedly
from `update_preview()` on every `CursorMoved` once the window is open. If
the "cursor over nothing" case returned zero lines instead of two blank ones,
the panel's total buffer line count would change by 2 every time the cursor
entered or left a skill cell, making the whole floating window visibly resize
and jump as the user moved around.

Separately, re-running the full `M.build()`/`apply_content()` pipeline on
every `CursorMoved` would reset scroll position and cause visible flicker,
just to update two lines of text.

Finally, `update_preview()` has no `is_open()`/`_preview_lnum` guard at its
top, which looks unusual next to functions like `toggle_suppress()` that do
guard. This was deliberate, not an oversight: every caller of
`update_preview()` (`M.open()`, `refresh()`, the `CursorMoved` autocmd) only
ever runs while the window is open, and Neovim clears buffer-scoped autocmds
synchronously when the buffer is wiped — so `CursorMoved` cannot fire for
this buffer after `M.close()` runs. A guard for that combination would be
dead code with no test able to reach it.

## Decision

- `preview_lines(nil, ...)` always returns exactly two lines (both empty
  strings), never zero — the panel's height contract never depends on
  whether an item is under the cursor.
- `update_preview()` rewrites only the two preview-strip buffer lines (via
  `nvim_buf_set_lines(_buf, _preview_lnum, _preview_lnum + 2, ...)`) and only
  that region's highlight namespace, instead of re-running the whole
  build/apply pipeline.
- `update_preview()` intentionally has no `is_open()` guard, relying on the
  autocmd-cleared-on-wipe guarantee above instead of a manual check.

## Consequences

- Any future caller of `preview_lines()` must preserve the "always exactly 2
  lines" contract, including for new edge cases — a partial-line return would
  reintroduce the resize/jump bug this avoids.
- If a future refactor ever attaches the `CursorMoved` autocmd to something
  other than `buffer = _buf` (e.g. a global autocmd filtered by filetype),
  the "cannot fire after close" guarantee no longer holds and an explicit
  guard must be added back to `update_preview()`.
