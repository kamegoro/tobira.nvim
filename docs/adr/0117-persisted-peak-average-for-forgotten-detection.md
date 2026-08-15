# Persisted peak average so `is_forgotten()` keeps long memory despite a short `sessions[]` window

## Context

`usage[cmd].sessions` is capped at `MAX_SESSIONS = 10` entries (`logger.lua`). This cap
is load-bearing for things that genuinely only need recent history: `ui/spark.lua`'s
sparkline preview, `is_adopted()`'s last-3-sessions average, and `usage.json`'s own disk
size over months of accumulated use. None of those need more than 10 slots.

`graph.is_forgotten()` (docs/adr/0029) is different — it exists specifically to catch
habits abandoned *months* ago, which requires comparing recent usage against a
genuinely long-term historical average. Before this change, that "historical" average
was computed as `avg(sessions[1 .. n-2])` — i.e., from whatever was still sitting in
the same 10-slot window. For a user who closes/reopens Neovim multiple times a day,
that window can cycle through in a few days to two weeks.

The concrete failure (#307): a command with `count = 1821` (a real, heavily-used habit)
and `sessions = [10, 11, 12, 8, 9, 10, 11, 1, 0, 0]` (just abandoned) starts out
correctly flagged `is_forgotten() == true`. But each further session close appends
another 0 and evicts the oldest entry. After only 2-3 more closes, every high-usage
session has rolled out of the window, `historical` drops below `FORGOTTEN_ADOPTED_BAR`,
and `is_forgotten()` flips to `false` — permanently, regardless of `count`, which stays
at 1821 the whole time. This is exactly backwards from ADR 0029's stated goal: a
command that was genuinely mastered and then abandoned is supposed to stay excluded
from "mastered" and reappear in the Guide, not silently graduate to "mastered forever"
the moment its evidence ages out of a 10-slot array.

No amount of cleverness inside `is_forgotten()` can fix this on its own: once an entry
is evicted from `sessions[]`, the information is gone, and a pure function reading only
the current array cannot recover it. Something has to persist a signal about "was this
ever genuinely adopted" independently of the window that's deliberately kept short for
other reasons.

## Decision

Add one new persisted field per command, `peak_avg`: a running high-water mark of the
`sessions[]` window's own average, sampled at every session close, before that close's
new count is appended and the oldest entry potentially evicted.

In plain terms: every time a session ends, before we make room for the new entry,
`logger.lua` looks at whatever's still in the 10-slot window right now and checks
"is this the best sustained-average window this command has ever had?" If so, that
average is saved to `peak_avg` and never lowered again. `sessions[]` itself keeps
cycling as before — short, capped, fine for sparklines — but `peak_avg` remembers the
best it ever saw, forever.

`graph.is_forgotten()` then uses `math.max(data.peak_avg or 0, windowed_historical)` as
its `historical` value, instead of `windowed_historical` alone. Once a command has
genuinely earned a place above `FORGOTTEN_ADOPTED_BAR`, that fact can't be erased by
the window cycling — `is_forgotten()` keeps evaluating the (still live) `recent` average
against it, so a command that resumes regular use is still correctly un-forgotten (via
`recent` climbing back up), but a command that goes quiet stays flagged forgotten
indefinitely instead of reverting after a handful of session closes.

`peak_avg` is guarded the same way `is_forgotten()` itself is (`#sessions >= 3` before
it updates), so an early 1-2-session average can't lock in a misleadingly high peak from
noise.

**Concurrent-write merge (docs/adr/0014):** `peak_avg` is monotonic — it only ever grows,
never shrinks. That makes its merge strategy simpler than every other field in the
per-command merge: `math.max(mem.peak_avg, disk.peak_avg)` is correct regardless of
which instance last synced with disk, so — unlike `.count` (additive against a
baseline) or the sticky flags (`.suppressed`/`.pinned`/`.celebrated`, which need a
baseline to tell "changed locally" apart from "was always the default") — `peak_avg`
needs no `_baseline` entry at all.

**What was deliberately not done:**
- **Widening `sessions[]` itself past `MAX_SESSIONS = 10`.** That cap is shared by
  `is_adopted()`'s short-window semantics, `ui/spark.lua`'s sparkline, and
  `usage.json`'s disk footprint — none of which want a bigger window, and none of
  which have the bug this ADR fixes. Solving #307 by growing the array would fix one
  consumer's problem by breaking assumptions for the others.
- **Recomputing "true historical" from scratch on every `is_forgotten()` call.** Not
  possible — see above, the array genuinely only has 10 slots' worth of data at any
  moment. Any fix needs a persisted side-channel; `peak_avg` is that side-channel, kept
  as small and mechanically simple (one float, monotonic, no baseline) as possible.

### The bursty-usage false positive (#307's secondary finding) — deferred

The issue also reports a lower-confidence false positive: a command used heavily every
3rd session (`sessions = [15, 0, 0, 14, 0, 0, 16, 9, 0, 0]`) reads `is_forgotten() ==
true`, because `FORGOTTEN_RECENT_WINDOW = 2` happens to land on a trough of the cycle.
Widening the window (e.g. to 3, matching `is_adopted()`'s own window) does fix this
specific example, but breaks several of `graph_spec.lua`'s existing, deliberately-chosen
`is_forgotten()` boundary tests (e.g. the exact-30%-boundary case), which were tuned
against `FORGOTTEN_RECENT_WINDOW = 2` specifically. Those thresholds are hardcoded
product-tuning decisions (docs/adr/0029), not incidental — changing the window changes
what "recent" means for every command, not just bursty ones, and needs its own
deliberate re-tuning pass against real usage data, not a one-line change bundled into
an unrelated correctness fix. This is left as a follow-up (tracked separately from
#307's core bug) rather than addressed here.

## Consequences

- `usage.json` gains one new numeric field per command (`peak_avg`, default `0`).
  `migrate_entry()` fills it in for pre-existing entries on load, same as every other
  field added to this format historically.
- A command that had one unusually heavy, short burst of use (enough to clear
  `FORGOTTEN_ADOPTED_BAR` and register a peak) but then settles into a lower, genuinely
  steady habit needs to climb back to ≥30% of that all-time peak (not just 30% of its
  new steady-state average) to be considered "not forgotten" again. This is an
  intentional, conservative trade-off: the entire point of this fix is that abandonment
  should be sticky, and a peak computed from an averaged 10-session window (not a
  single spiky session) is a reasonably stable basis for that stickiness.
- Any future field added to a usage entry should ask the same question `peak_avg`
  answers here: is this value monotonic (safe to merge with a plain `max()`/`min()`,
  no baseline needed) or does it need the baseline-diff treatment ADR 0014 describes?
  Getting this wrong in either direction either reintroduces a lost-update bug or adds
  unnecessary baseline bookkeeping.
