# Periodic save and preserving an unparsable `usage.json`

## Context

`usage.json` used to be written only on `VimLeave` plus whenever a suggestion was shown,
pinned, suppressed, etc. Plain keystroke counts (`increment()`) never trigger a write on
their own, so a session that ended without `VimLeave` — `kill -9`, a crash, the terminal
window being closed — lost every count it had collected. Long-running sessions (an editor
left open for days) had the most to lose.

Separately, `read_disk()` treated a file that failed to parse exactly like a missing file
and returned `{}`. The next `save()` then wrote the merge of `{}` and memory over it. A
truncated file (reproduced with 3000 recorded `ciw` uses) was silently replaced by a nearly
empty one, and the user had no way to know or recover.

## Decision

**Periodic save.** `logger.setup()` registers `CursorHold`, `CursorHoldI` and `FocusLost`
in the existing `tobira_mode` augroup. Each one calls the normal `save()` — the same
merge-with-disk + temp-file-and-rename path every other write uses (docs/adr/0014,
docs/adr/0118) — only if a count changed since the last successful save (`_dirty`, set in
`increment()`), and:

- `CursorHold`/`CursorHoldI`: only if `AUTOSAVE_INTERVAL_MS` (2 minutes) has passed since
  the last successful save. `CursorHold` fires after every pause of `updatetime` (4s by
  default), so without the interval a busy editing session would rewrite the file every
  few seconds. Two minutes bounds the loss on a crash to a short stretch of work while
  keeping writes rare.
- `FocusLost`: immediately. Switching away is the moment just before a terminal window
  gets closed, and it is rare enough that it needs no throttle.

Nothing runs on the `vim.on_key` hot path except setting the `_dirty` boolean.

Only `.count` (and anything else already in `usage`) reaches disk mid-session. The
session's own `sessions[]` entry is still appended only by `close_session()` on
`VimLeave`: a session that never ends cleanly simply isn't recorded as a session, while
its counts survive. Because the save goes through `merge_with_disk()` and re-syncs
`_baseline` afterwards, a mid-session save followed by the exit-time save never counts
the same keystrokes twice, and concurrent instances still add up correctly.

**Never overwrite an unparsable file.** When `usage.json` exists, is not blank, and does
not decode to a JSON object, `read_disk()` renames it to
`usage.json.corrupt-<YYYYmmdd-HHMMSS>` (adding `-2`, `-3`, … if that name is already
taken) before returning `{}`, and calls `M.on_corrupt(path)`. `init.lua` wires that
callback to a localized `vim.notify` warning (logger has no i18n dependency, same as
`on_pattern`), and wires it before `logger.setup()` so a corrupt file found by the
initial load is reported too. The warning fires once per moved file: once it has moved,
later reads find the fresh file.

If the rename fails, `read_disk()` returns `nil` and `save()` writes nothing. The in-memory
data is kept (`_dirty` stays set), the next save tries again, and the broken file is
never overwritten. A blank file (empty or whitespace only) has nothing to recover and is
still treated as empty usage.

**`:TobiraReset` asks first.** `require('tobira').reset(force)` shows `vim.fn.confirm()`
(default answer "No"; `<Esc>` also cancels) unless called as `:TobiraReset!`. It still
ends in `logger.reset()` + `logger.clear_disk()` exactly as before.

## Consequences

- docs/adr/0118's note that "nothing proactively retries a failed save" no longer holds
  for counts: a failed write leaves `_dirty` set, so the next periodic trigger retries it.
- Old `usage.json.corrupt-*` files pile up only if the file keeps getting corrupted;
  tobira never deletes them, since they may be the user's only copy of their history.
- A user who repairs a moved file by hand has to copy it back while Neovim is closed,
  otherwise the running instance's next save merges into the fresh file instead.
