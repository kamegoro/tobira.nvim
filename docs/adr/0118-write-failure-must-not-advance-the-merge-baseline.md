# A failed `write_file()` must not advance the merge baseline

## Context

`save()`'s internal order used to be `merge_with_disk()` → `sync_baseline()` →
`write_file()`. `write_file()` fails silently whenever `io.open(tmp, 'w')` returns nil
(permission denied, read-only filesystem) or the write itself doesn't complete (disk
full) — it just returned early with no error surfaced.

The bug (#308): `sync_baseline()` ran *before* `write_file()`, so by the time the write
failed, `_baseline`/`_sessions_appended` had already been advanced as if the write had
succeeded. `_baseline` exists specifically so the next `save()` can tell "I changed this
locally since I last synced with disk" apart from "this was always the default" (see
docs/adr/0014). Once it's wrongly advanced, the next successful `save()` diffs the
in-memory value against a baseline that already thinks the failed write's data reached
disk — so `merge_with_disk()`'s `count_delta = mem_count - baseline_count` computes 0
(or worse, an incorrect delta if more increments happened in between), and whatever was
pending at the moment of the failure is silently discarded. No error, no retry, and the
data is gone even though nothing ever corrupted the file on disk (the temp-file+rename
pattern still protects against that).

## Decision

`write_file()` now returns `true`/`false` instead of silently swallowing every failure
mode. It reports `false` for a failed `io.open`, a failed `f:write()` (disk full), or a
failed `os.rename()` — the three points identified in #308's repro.

`save()` reorders around that signal:

1. Compute `merge_with_disk()` as before, but keep the pre-merge `usage` around as
   `previous_usage`.
2. Attempt `write_file()`.
3. **On success:** `sync_baseline()` runs exactly as before — the merged result is now
   truthfully on disk, so the baseline should reflect it.
4. **On failure:** `usage` is rolled back to `previous_usage`, and `_baseline`/
   `_sessions_appended` are left completely untouched. The in-memory state is exactly
   what it was before `save()` was called — nothing merged, nothing lost, nothing
   double-counted. The next `save()` call (the natural retry — every mutating logger
   API funnels through `save()`) re-runs `merge_with_disk()` from scratch against a
   fresh disk read and a still-accurate baseline, producing the correct merged result.

`clear_disk()` (`:TobiraReset`'s path) had the identical shape (`write_file()` then
unconditional `sync_baseline()`) and is fixed the same way, gating `sync_baseline()` on
`write_file()`'s return value — a write failure here must not make the baseline think
disk was cleared when it wasn't.

**What was deliberately not done:** no user-facing notification (`vim.notify` or a
suggestion-float message) was added for a save failure. The core guarantee this ADR
restores is that a transient failure is recoverable — data survives in memory and
persists on the next successful save with no explicit retry logic needed, since every
write path already re-enters `save()` on its own. Surfacing the failure to the user is
a separate, additive concern (and `:checkhealth tobira` already reports whether the
data directory is writable) that can be layered on later without touching this
mechanism.

## Consequences

- Any future write path added to `logger.lua` must go through `save()` (as every
  current one already does) rather than calling `write_file()` directly, or it loses
  this protection.
- `write_file()`'s return value is now part of its contract — a future refactor that
  makes it return early for a new reason (e.g. a new validation step) must also return
  `false` there, or a new silent-data-loss path reopens.
- Retrying is implicit rather than scheduled: nothing proactively retries a failed
  save. If the user never triggers another mutating action (keystroke, `mark_shown`,
  etc.) before quitting Neovim, the pending data still isn't written. This matches the
  existing behavior for any other unpersisted in-memory state at `VimLeave` and is not
  a new gap introduced by this fix — `close_session()` (bound to `VimLeave`) is itself
  one of the `save()`-calling paths, so the common "Neovim is exiting" case is already
  covered.
