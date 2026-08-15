# Unified reactive/ambient suggestion scheduling and adoption-watch consolidation

## Context

`suggest.lua` had three related bugs, all in its scheduling code, all only
visible at realistic session scale/duration (thin, hand-picked test fixtures
structurally cannot reproduce any of them — see `tests/CLAUDE.md`'s
"Realistic-scale fixture suite" and "Long-session resource-bound suite"
notes):

1. **Reactive-vs-ambient race.** `M.queue()` (armed the instant a specific
   pattern like `f_repeat` fires) and the ambient idle watcher set up by
   `M.setup_idle()` (reset on every keystroke, calling `fire_ambient()` ->
   `graph.find_best()`) were two independent, unordered timers. Both get
   armed within microseconds of the same last keystroke and both fire
   `idle_delay` later, with no ordering between them. At realistic registry
   scale, `find_best()` returns non-nil almost always, so every idle pause
   became a live race — and the ambient timer's callback consistently won it
   in observed testing, showing an unrelated generic pick, then dropping the
   reactive suggestion moments later once `cooldown_blocks()` saw the
   ambient pick had just started the cooldown clock. This defeated the "you
   just did X -> here's the tip for X" cue-routine-reward loop that reactive
   pattern detection exists for.

2. **Cooldown drop-without-requeue.** `M.queue()` checked
   `cooldown_blocks(cmd)` *before* arming its timer. A genuinely-earned,
   eligible reactive suggestion firing while `suggestion_cooldown` (default
   300s) was still active from an earlier, unrelated suggestion was dropped
   at that instant — never deferred, never retried once cooldown lifted.
   Given the 300s default, any moderately active session plausibly triggers
   2+ genuinely different eligible patterns inside one cooldown window,
   making this the common case, not an edge case.

3. **Adoption-watch registration leak.** `watch_adoption(cmd)` registered a
   brand-new `vim.on_key` namespace every time a suggestion was shown, torn
   down only on adoption or via `reset_session()` — which is never called
   from any production code path, only from tests. Every shown-but-not-
   adopted suggestion leaked one live `vim.on_key` registration for the rest
   of the session, each doing real per-keystroke work (`keytrans()` + string
   matching), degrading hot-path performance as the session went on.

(1) and (2) are distinct mechanisms (ordering at one idle boundary, vs. full
loss across a cooldown window) but live in the same subsystem and interact —
a fix for one that ignored the other risked leaving the scheduling behavior
inconsistent, so they're addressed together here. (3) is a separate resource
lifecycle problem in the same file, addressed in the same pass since it also
concerns how long a suggestion's supporting state stays alive.

## Decision

### Reactive suggestions take priority over the ambient pick, don't race it

Rather than literally merging the two timers into one, `fire_ambient()` now
checks whether a reactive suggestion is currently pending (`session.timer ~=
nil`) and, if so, yields without showing anything or touching the cooldown
clock:

```lua
local function fire_ambient()
  if session.timer then
    return
  end
  ...
end
```

This was chosen over a literal single-timer merge for two reasons:

- **Independence from `idle_suggestions`.** Reactive pattern suggestions
  (`M.queue()`) have never been gated by the `idle_suggestions` config value
  — only the ambient/proactive picker is. If the ambient idle watcher's own
  timer became the *only* scheduling mechanism, disabling `idle_suggestions`
  would silently disable reactive suggestions too, a behavior change nobody
  asked for. Keeping two timers with an arbitration rule preserves this
  independence for free.
- **The race is symmetric by construction, so a simple guard is enough.**
  Because `M.queue()` is called synchronously from the same `on_key`
  dispatch tick that also resets the ambient idle timer (both triggered by
  the same keystroke), `session.timer` is already set by the time *either*
  timer's callback actually runs later. A one-line check is sufficient to
  make the outcome deterministic regardless of which underlying libuv timer
  happens to fire first — no need for a more invasive redesign.

When nothing reactive is pending, `fire_ambient()` behaves exactly as
before — this is the majority case (only one thing eligible at a time), left
untouched.

### Cooldown-blocked reactive suggestions retry once the cooldown lifts

`M.queue()` no longer checks `cooldown_blocks(cmd)` before arming its timer —
only `should_suppress(cmd)` (mastered/suppressed/max_shown/override), none of
which are time-based and none of which are worth waiting out. The cooldown
check moved into the timer's resolution step, `resolve_queued()`:

```lua
local function resolve_queued(pattern, cmd)
  session.timer = nil
  if should_suppress(cmd) then
    return
  end
  if cooldown_blocks(cmd) then
    session.timer = vim.defer_fn(function()
      resolve_queued(pattern, cmd)
    end, cooldown_remaining_ms())
    return
  end
  M.show(cmd, pattern)
end
```

If cooldown is still active when `idle_delay` elapses, `resolve_queued`
re-arms `session.timer` for exactly the remaining cooldown time and checks
again — self-correcting even if another suggestion extends the cooldown
window again in the meantime, since `cooldown_remaining_ms()` is always
computed fresh against the current `session.last_auto_at`.

`should_suppress` is deliberately re-checked at *every* resolution (both the
initial `idle_delay` fire and each retry), not just at the original
`M.queue()` call — a command can become suppressed (mastered, hit
`max_shown`, etc.) while a retry is in flight, and a suggestion that's no
longer eligible must not surface just because it was eligible when queued.

**Multiple reactive suggestions landing in the same blocked window: most
recent wins.** `M.queue()` already called `cancel_timer()` before arming a
new one, discarding any not-yet-fired reactive suggestion in favor of the
newest pattern match — this predates the bug fixes here. That behavior now
also applies uniformly to suggestions waiting out a cooldown retry, since
`session.timer` is the same field either way. This was kept rather than,
say, queueing every blocked suggestion in order: the reactive suggestions
this system produces are timely nudges tied to what the user *just* did: an
older nudge about to become stale on the user's screen once a much later
action even fired the check is not worth resurrecting once cooldown lifts —
the most recent thing the user did remains the most relevant thing to
surface. Queueing everything would also mean an idle session could suddenly
show a *burst* of suggestions the instant cooldown lifted, which is exactly
the "don't push more than necessary" restraint this project already commits
to (`max_shown`, cooldown, one-idle-suggestion-per-window all exist for the
same reason).

### Adoption-watch: one shared `vim.on_key` registration, not one per suggestion

`watch_adoption(cmd)` no longer creates a per-command `vim.on_key` namespace.
Instead, every pending watch is a `{ buf, match_target }` entry in a shared
`session.watches` table, and a single `vim.on_key` callback
(`adopt_on_key`) is registered once, iterating that table on every
keystroke:

```lua
local function adopt_on_key(key, typed)
  if typed == '' then return end
  local k = vim.fn.keytrans(typed or key)
  for cmd, watch in pairs(session.watches) do
    watch.buf = (watch.buf .. k):sub(-KEY_BUF_MAX)
    if buf_matches(watch.match_target, watch.buf) then
      mark_adopted(cmd)
      session.watches[cmd] = nil
    end
  end
  if next(session.watches) == nil and _adopt_ns then
    vim.on_key(nil, _adopt_ns)
  end
end
```

Each pending suggestion still keeps its own independent rolling buffer
(`watch.buf`), so adopting one suggested command still cannot interfere with
detecting another — the per-watch independence ADR 0047 established is
unchanged, only the registration count is. The shared callback detaches
itself once the last pending watch resolves (whether by adoption or by
`reset_session()`), rather than staying attached for the rest of the session
regardless of whether there's anything to watch for — keeping the
`vim.on_key` hot path work at zero when nothing is pending.

## Consequences

- A reactive suggestion firing alongside ambient eligibility now reliably
  shows the reactive/specific suggestion — the scenario this project's core
  cue-routine-reward loop depends on.
- A reactive suggestion landing inside another suggestion's cooldown window
  is retried once that cooldown lifts instead of being silently and
  permanently lost. Worst case it fires up to `idle_delay +
  suggestion_cooldown` after the triggering pattern instead of never.
- `vim.on_key` namespace count for adoption watching now stays at 0 or 1
  regardless of how many suggestions have been shown-but-not-adopted in a
  session, closing the unbounded per-keystroke overhead growth.
- The "most recent reactive suggestion wins" choice means a reactive
  suggestion can still be silently superseded by a later, different
  reactive suggestion before ever firing (unchanged from the pre-existing
  `cancel_timer()` behavior, now also applied during a cooldown-retry wait).
  This is a deliberate product choice (see Decision above), not an oversight
  — if a future need arises to queue multiple distinct reactive suggestions
  in sequence, that is a new decision to make explicitly, not a side effect
  to discover.
- `fire_ambient()`'s yield check only looks at `session.timer` being
  non-nil, not at *what* is pending — it cannot distinguish "a reactive
  suggestion is about to fire in 10ms" from "a reactive suggestion is stuck
  waiting out a multi-minute cooldown retry." In the latter case the ambient
  picker also yields for that entire wait. This is intentional, not just a
  simplification: `fire_ambient()` already independently bails via
  `over_auto_limit()` whenever cooldown is active, and a cooldown-retry wait
  by definition only happens while cooldown is active — so the two checks
  never diverge in practice.
