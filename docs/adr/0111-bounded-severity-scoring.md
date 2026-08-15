# Bounding find_best/efficiency_gaps by raw frequency, and computing guide_commands' ceiling per category

## Context

Two related `core/graph.lua` bugs only showed up at realistic registry scale
(#291, #292 — both surfaced by the `tests/regression/realistic_scale_spec.lua`
fixture, not the thin hand-picked fixtures in `graph_spec.lua`).

**#291.** `find_best()`'s score (`trigger_count - cmd_count`) and
`efficiency_gaps()`'s ratio (`trigger_count / max(child_count, 1)`) are both
unbounded. Base motion/edit keys (`j`, `i`, `k`, `a`, `dd`, `o`) are
mechanically the most-pressed keys in any session — after realistic extended
use their counts run into the thousands, dwarfing legitimately-important but
naturally-rarer triggers (`n`, `x`, `zz`, fold/macro/window triggers) by
10-100x. Measured: 40 consecutive `find_best()` picks in a realistic-scale
simulation all came from just 7 trigger commands, and 4 of
`efficiency_gaps()`'s top 5 rows shared the same trigger. The score/ratio
formulas don't track how *severe* a habit gap is — they track how *common*
the underlying keystroke is, and that gap widens mechanically with both
accumulated usage time and registry breadth.

**#292.** `guide_commands()` computed one GLOBAL mastery ceiling
(beginner/intermediate/advanced) from whether *any* beginner-level command
*anywhere in the registry* was still unmastered, then hid every command
above that ceiling in *every* category. `ex` (`ex:g`, `ex:norm`, `ex:cdo`,
`ex:sort` = advanced, `ex:copen` = intermediate) has zero beginner-level
commands of its own, so it could never clear the global ceiling until the
user had mastered literally every beginner command across all 9 other
categories — hiding the entire category regardless of how much the user
actually used it. `:TobiraProgress` has no such gate and shows all
categories, so the two panels disagreed about whether `ex` commands existed
to be learned.

## Decision

**#291, part 1 — `efficiency_gaps()` top-N diversity.** When `limit` is
given, the full ratio-sorted list is no longer truncated directly. Instead
it's split by `parent` (trigger), and the top-N is built by round-robin: one
gap from each distinct parent (visited in the order that parent's
best-ranked gap appeared in the sorted list), looping back for a second pick
per parent only once every parent has had a first one. The selected subset
is then re-sorted by the same ratio-desc/child-asc comparator so severity
still drives display order within the diversified result. This was the
low-ambiguity fix the issue itself called out — worth doing regardless of
part 2.

**#291, part 2 — `find_best()` score cap.** The ordinary-pool score is now
`math.min(trigger_count - cmd_count, 100)`. 100 isn't a new magic number —
it's the same count `mastery_level()` already treats as "familiar" (★)
everywhere else in this file. The reasoning: once a trigger has clearly
cleared that bar, further raw-keystroke growth stops being informative for
*how urgently* its follow-up command deserves a suggestion — what still
matters is how little the follow-up itself has been used, which the
`- cmd_count` term (uncapped) continues to express. Below the cap, ordering
is untouched — a genuinely more severe gap (bigger score) still wins.
Above it, candidates whose triggers are all well-established now tie on
score instead of the single most astronomically-pressed key always winning.

Capping made these ties common — routine, in fact, for any trigger past
~100 uses, since every one of its still-offered children (all below the
100-count mastery bar themselves) then scores identically. A tie is broken
first by `cmd_count` ascending (the candidate whose own command has been
used *less* is the more severe gap and wins), and only falls through to the
alphabetical tie-break if `cmd_count` also matches (independent QA finding:
without this secondary key, two candidates sharing a well-established
trigger but with very different `cmd_count` — e.g. never-tried vs.
near-mastery — tied on score and were decided purely by command-name
alphabetical order, which could and did pick the *less* severe of the two).

Considered and rejected: a logarithmic transform of `trigger_count`. It
smooths the curve but doesn't bound it, so an established trigger at
thousands of uses would still edge out one at hundreds by a small but
persistent margin — the same "common beats severe" bias the issue reports,
just compressed rather than removed. A hard cap makes "already well-known
enough that more raw frequency shouldn't matter" a bright line instead of a
diminishing-but-still-present bias.

Not changed: `efficiency_gaps()`'s ratio itself stays unbounded. The issue's
own fix direction treats top-N diversity as the answer for that function; a
ratio cap wasn't part of either partly-fix and would need its own separate
design pass (different formula, different threshold semantics) rather than
piggybacking on this one.

**#292 — per-category ceiling.** `guide_commands()` now computes
`unmastered_by_cat[cat] = {beginner, intermediate, advanced}` instead of one
registry-wide `unmastered` table, and `ceiling_for(cat)` applies the exact
same three-branch rule (`beginner > 0 → 1`, `elseif intermediate > 0 → 2`,
`else → 3`) scoped to that one category's own counts.

This directly answers the issue's own open question — "should a category
with zero beginner rungs just always be visible at its own natural floor?"
— with yes, and it falls out for free rather than needing a special case:
`unmastered_by_cat['ex'].beginner` is always `0` (`ex` simply has no
beginner-level commands), so `ex`'s ceiling never gets stuck at branch 1; it
proceeds straight to checking its own intermediate count. Concretely, `ex`
now opens at `ex:copen` (its own intermediate command) regardless of
whatever beginner commands remain unmastered in `motion`/`edit`/etc., and
only opens further to `ex:g`/`ex:cdo`/`ex:norm`/`ex:sort` (advanced) once
`ex:copen` itself is mastered.

This does mean a category with no beginner commands can now show
intermediate-level content to a brand-new user with zero usage anywhere —
previously true of nothing (the old global ceiling suppressed it
unconditionally at zero usage same as everywhere else). This is an
intentional, narrow trade of the "don't overwhelm with advanced content"
intent: the ceiling still fully gates `ex`'s *advanced* commands behind
mastering `ex:copen` first, so within-category pacing is preserved: only
the cross-category blocking (being gated by *unrelated* categories'
unmastered beginner commands) is removed. A category is never blocked by a
level it structurally has zero commands at.

## Consequences

- Any future score/ratio formula added to `graph.lua` that grows with a raw
  usage count should default to asking whether it needs the same treatment
  (a bounded cap, or a diversity pass at the point results get truncated)
  rather than assuming unbounded frequency differences are always
  meaningful signal.
- `FIND_BEST_SCORE_CAP` is hardcoded at 100, matching the existing
  hardcoded-not-configurable precedent for this file's other thresholds
  (mastery levels, `FORGOTTEN_*`, `REGISTER_UNDERUSE_TRIGGER`) — one fewer
  knob for users to have to understand.
- A category that gains its first-ever beginner-level command in a future
  registry change automatically reverts to the ordinary beginner-first
  ceiling behavior — `ceiling_for()` has no per-category special case to
  update.
- `tests/spec/unit/graph_spec.lua`'s `'returns only beginner commands when
  no usage'` test name is now slightly narrower than its behavior (most
  categories still do; `ex` doesn't) — see the test's own updated body and
  comment for the per-category framing.
- `efficiency_gaps()`'s round-robin guarantees a slot to every distinct
  trigger before any trigger gets a second one, which means a bare-minimum
  qualifying gap (ratio just above the `>= 5` cutoff) from an underrepresented
  trigger can displace a far more severe gap (ratio in the hundreds) from a
  high-fan-out trigger once the number of distinct triggers approaches
  `limit`. This is the intended trade — the issue's own repro was entire
  categories never getting a turn at all — not an oversight, but it means
  "top N by severity" and "top N after diversification" can diverge sharply
  when many triggers each contribute exactly one marginal gap.
- The per-category ceiling fix removes *cross*-category blocking but does not
  add a per-category equivalent of the "stuck ceiling" fix within a category
  that itself has very few beginner commands. A category with exactly one
  beginner command that a given user happens to never press (independent of
  how much they use that category's intermediate/advanced commands) still
  shows only that one command — the same shape #292 fixed at the registry
  level, just now possible to recreate inside a single sparse category. Not a
  regression (this is strictly better than the old global ceiling, which
  would have suppressed the same category's advanced content too, along with
  every other category's), and out of #292's stated scope, but worth a
  dedicated follow-up if a category this shape (currently `fold`, `window`,
  `terminal` each have exactly one beginner command) turns out to matter in
  practice.
