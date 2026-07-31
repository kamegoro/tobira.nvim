# Reactive-only registry entries for direct pattern fires

## Context

Most registry entries get suggested through one uniform path: a pattern in
`patterns.lua` increments some command's usage count, and once a *different*
command's `requires` count crosses a threshold, `graph.find_best()` promotes it
into the suggestion pool.

A recurring minority of entries don't work that way at all. Their trigger pattern
(in `patterns.lua` or `patterns_insert.lua`) fires the suggestion **directly** —
`on_pattern` → `suggest.queue` → `do_show` — the moment the pattern is recognized,
completely bypassing `find_best()`'s promotion path. Examples: `ddp` (dd followed
by p), `{n}x` (x repeated, suggesting a count-prefix), `g<C-a>` (`<C-a>` streak of
3+ across a visual-block increment), `gv` (v tapped and immediately escaped 3
times, `v_repeat`, #55), and `ya"` / `ya'` (`ci"`/`ci'` repeated 3x on separate
lines, `ci_dquote_repeat`/`ci_squote_repeat`, #53).

These entries still need a `commands.registry` row — without one,
`suggest.show`'s lookup into `graph.suggestions` for title/body/example strings
silently no-ops, i.e. the suggestion is detected but nothing is ever shown. But
their `requires` field, unlike the uniform-path entries, doesn't represent a real
promotion gate — it's a nominal "what manual habit does this replace" anchor,
because the schema guard (`commands_spec.lua`) requires every non-compound entry to
have one.

## Decision

- Give each of these entries a normal-looking `requires`/`category`/`level` row so
  the registry lookup and schema guard both succeed, but document at each entry
  that it is reactive-only: the row exists for the string lookup, not because
  `find_best()` will ever promote it through the `requires` chain.
- `track = false` on all of them: none of these commands has a `pending_*`
  dispatch entry in `patterns.lua` recording literal keypresses for them (same
  shape as the other track=false multi-char entries), so there is nothing for the
  generic TRACK table to watch for.
- For `ya"`/`ya'` specifically: chose built-in Vim commands with no plugin
  dependency, over the vim-surround-dependent `cs'"` alternative that the original
  issue also discussed — see that issue/PR for the plugin-dependency tradeoff.

## Consequences

- Don't "fix" one of these entries' `requires` chain to make promotion "actually
  work" — promotion was never the intent. If a genuinely promotable variant of one
  of these is wanted later, that's a new, additional entry, not a change to the
  reactive one.
- `commands_spec.lua`'s `KNOWN_DEFERRED` table already accounts for several of
  these (their nominal `requires` target is itself untrackable) — read that table's
  header before treating one as a tracking bug.
- A new direct-fire pattern should follow the same shape: registry row for the
  lookup, `track = false`, and a one-line note at the entry pointing back to this
  ADR instead of re-explaining the mechanism.
