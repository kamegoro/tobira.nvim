# `usage.json` concurrent-write merge strategy (`logger.lua`)

## Context

Multiple Neovim instances can have the same `usage.json` open at once (two split
terminals, a `:terminal` inside one editor spawning another, etc.), and each instance
only calls `save()` when its own state changes. If `save()` just serialized in-memory
`usage` straight to disk, the last instance to write would silently erase every other
instance's contribution since the file was last read — including entries this instance
never touched, and counts other instances added.

The straightforward fix, "always add my own delta to whatever is currently on disk,"
does not extend cleanly to every field: `.shown` is deliberately per-launch (`load()`
resets it to 0 so `max_shown` caps per session, not for all time), `.sessions` is a
capped rolling array that can have entries evicted by the `MAX_SESSIONS` limit on either
side, and `.suppressed`/`.pinned`/`.celebrated` are booleans where "this instance never
touched it" and "this instance explicitly set it back to false" must be told apart.

## Decision

- **`_baseline`** snapshots every command's `{count, shown, suppressed, pinned,
  celebrated}` at the moment `usage` was last synced with disk (`setup()`,
  `load_from_disk()`, or right after a `save()`'s merge is written). Every later
  `save()` diffs the in-memory value against this snapshot, not against disk, to tell
  "I changed this locally since I last synced" apart from "this was always the
  default" — `merge_with_disk()`'s `merge_flag()` helper.
- **`_sessions_appended`** tracks, per command, how many `sessions[]` entries this
  instance appended since its own baseline. An array-length diff cannot recover this
  once the rolling `MAX_SESSIONS` cap has evicted entries from either side — the array
  can be the same length before and after real new data was added.
- **Per-field merge strategy** in `merge_with_disk()`:
  - `.count`: additive — `disk_count + max(0, mem_count - baseline_count)`. Stacks
    this instance's real growth on top of whatever else landed on disk.
  - `.shown`: local only, never merged with disk — folding disk's old value back in
    would make the per-session cap cumulative across launches.
  - `.sessions`: union — disk's array is kept, and only the entries this instance
    appended since its baseline (per `_sessions_appended`) are added on top, then the
    `MAX_SESSIONS` cap is re-applied.
  - `.suppressed` / `.pinned` / `.celebrated`: sticky — if this instance's value
    differs from its own baseline, that's a deliberate local decision and wins
    outright; otherwise disk's current value is adopted as-is. In the pure
    concurrent-write case (no local change either side) this behaves like an OR: once
    any instance sets the flag, it stays set — which matches how `.celebrated`
    specifically is used (no "uncelebrate" call exists).
- **`clear_disk()` deliberately bypasses this whole merge.** `:TobiraReset` is an
  explicit "erase everything" user action, not an incremental update. Routing it
  through the normal merge would resurrect every entry a concurrent instance (or a
  previous run) still has on disk from an empty in-memory `usage`, and reset would
  silently stop resetting anything.
- **Old-format migration (`migrate_entry`)** runs inside `load()`, converting the
  legacy `adopted = true` boolean into `sessions = { 10 }` and filling in defaults for
  fields that did not exist yet, so existing users' accumulated data survives format
  changes without a manual migration step.

## Consequences

- Any new field added to a usage entry needs its own entry in `baseline_of()` and its
  own branch in `merge_with_disk()`'s per-command merge — an omitted field silently
  falls back to whichever instance's `save()` runs last winning, reintroducing the
  original bug for just that field.
- Touching `merge_with_disk()` without touching `_baseline`/`_sessions_appended`
  tracking (or vice versa) is almost always wrong — they are two halves of the same
  mechanism.
- `clear_disk()` must never be reused as a general-purpose save path; it exists
  specifically to counteract the merge for the one caller (`:TobiraReset`) that needs
  disk to end up empty, not merged.
