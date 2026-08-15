# Bounding patterns_cmdline.lua's session-lifetime state maps (#314)

## Context

`new_substitute_state()`/`new_history_recall_state()` each return `{ entries = {} }`,
keyed by every distinct `:s/pattern/replacement/` pair (substitute) or every distinct
non-substitute/e/b/tabnew Ex command line (history-recall) ever submitted in the
session. Both persist for the module's entire lifetime (same lifetime as
`logger.lua`'s `seq`), only cleared by `M.reset()` — itself only reachable via
`:TobiraReset` or tests. A user doing many distinct find/replaces or ad-hoc
`:g`/`:norm`/`:sort` commands over a long session — completely ordinary editing —
accumulates one entry per distinct command line forever.

A second, independent growth vector lives inside each substitute entry:
`entry.lines = {}` records every distinct line number that pair was ever applied to.
`track_substitute()`'s own logic only ever *acts* on `entry.count` reaching 2 (`&`) or
3 (`g&`) — past that, the entry has nothing left to teach, but the original code kept
adding to `entry.lines` (and incrementing `entry.count`) for every further distinct
line regardless, so a single frequently-reused pair could itself grow without bound.

Unlike `patterns.lua`'s `seq.macro_buf` (a flat array, capped at
`MACRO_BUF_HARD_CAP=150` and trimmed back to 100 once exceeded — see that module's own
header), these are maps keyed by distinct command-line text. There is no "oldest slot"
to slide a window over; eviction has to pick a key.

## Decision

- **Hard cap of `ENTRY_CAP = 20` distinct keys per map**, enforced by evicting the
  single least-recently-touched entry the moment a genuinely new key would exceed the
  cap. "Touched" means either the entry's creation or any later call that looked it up
  again (a repeat submission of the same pair/text) — so a pattern the user keeps
  actively repeating stays warm and is always the last thing evicted, no matter how
  many one-off commands run in between.
- **LRU via an explicit monotonic counter, not a real ordered structure.** Each state
  table carries a `clock` field, incremented on every touch; each entry stores the
  clock value at its most recent touch. Eviction does a linear scan of the (at most
  `ENTRY_CAP`) entries for the minimum `touched` value. This is simpler than
  maintaining a doubly-linked list or a separate ordering array, and cheap enough:
  cmdline submissions happen at human typing speed, never in `vim.on_key`'s per-
  keystroke hot path (see `lua/tobira/CLAUDE.md`'s "Ex-command tracking" section — this
  module is only ever invoked once per complete submitted command line, at `<CR>`
  time). A tie is impossible: `clock` is a strictly increasing integer unique per
  touch, so eviction is deterministic regardless of `pairs()` iteration order.
- **20 was chosen empirically against `tests/regression/long_session_resource_spec.lua`
  (#318)**, which asserts both maps stay `<= 20` after a session that generates 40
  distinct substitute pairs and 40 distinct history-recall command lines — comfortably
  exercises eviction while still being generous for the realistic case (a handful of
  find/replace variations or ad-hoc Ex commands actually in flight at once).
  `tests/differential/generator_cmdline.lua`'s fuzz corpus reuses small fixed pools (4
  distinct substitute pairs, ~14 distinct trackable history-recall texts) specifically
  to exercise each detector's own count/threshold logic — both stay well under 20, so
  eviction never engages there and the differential suite's reference model needed no
  changes.
- **`track_substitute()` now returns immediately once `entry.count >= 3`**, before
  touching `entry.lines` at all. Past the `g&` threshold there is nothing left this
  entry can fire, so there is no reason to keep recording further distinct lines. This
  caps every entry's own `lines` set at 3 as a side effect of the existing "already
  fired the widest suggestion" logic, rather than needing a second, separate cap.

## Consequences

- An entry that goes cold for 20+ other distinct commands and is then resubmitted is
  treated as brand new — its count restarts from 1, so a pattern last used a long time
  ago (with 20+ different commands run since) needs to be seen twice again before `&`
  re-fires. Accepted: this only affects genuinely stale entries by construction (an
  actively-repeated pattern is never the least-recently-touched one), and matches the
  same trade-off `seq.macro_buf`'s trim already makes for normal-mode macro detection.
- Eviction is a linear scan bounded by `ENTRY_CAP`, not O(1). Fine at this cap size and
  this call frequency (see above); would need revisiting if `ENTRY_CAP` ever grew by an
  order of magnitude.
- `M.reset()`'s state shape is unaffected — `new_substitute_state()`/
  `new_history_recall_state()` still return fresh `{ entries = {}, clock = 0 }` tables,
  so no migration or format change is needed anywhere `logger.lua`'s `get_state_table_sizes()`
  or `M.reset()` already read/write these tables.
