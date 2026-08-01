# Guide's auto section drops invalid remaps entirely; the pinned section keeps the row and corrects the wording

## Context

`integrations.lua` (#63) detects the user's own keymap overrides via `nvim_get_keymap` and
distinguishes "equivalent" remaps (functionally identical to what `commands.lua` documents,
e.g. `nnoremap Y y$`) from remaps that make tobira's documented description of that key flatly
wrong. `graph.lua`'s `find_best()` (see `docs/adr/0030-keymap-override-exclusion-contract.md`)
excludes any overridden key from its suggestion pool outright, regardless of the `equivalent`
field — but `ui/guide.lua` bypasses `find_best()` entirely (it's a persistent reference sheet
built directly from `guide_commands()`/pinned data), so it needs its own answer to "what do we
show for a key the user has remapped."

Guide has two sections with different lifecycles, and they need different answers:

- The **auto section** is disposable and regenerated on every build — rows come and go
  automatically as mastery data changes.
- The **pinned section** is the user's own explicit curation — they typed a command to pin this
  exact row. Silently removing it would read as tobira losing track of a pin the user
  deliberately asked for.

## Decision

- **Auto section** (`M.build`'s per-category filter, `auto_suffix`): a command overridden by
  something that is *not* equivalent to what `commands.lua` documents is dropped from the auto
  section entirely. An equivalent remap (e.g. `Y` → `y$`) still renders normally, with
  `remapped_suffix` appended via `auto_suffix()`.
- **Pinned section** (`format_pinned_row`): never omits a row for a remap, equivalent or not. An
  equivalent remap gets the same `remapped_suffix` appended. A non-equivalent remap instead
  replaces the description outright with `remapped_invalid` — the row stays visible, with
  corrected wording instead of tobira's now-wrong original description.

## Consequences

- The `equivalent` field materially changes rendered output only in `ui/guide.lua` — every other
  reader of `overrides` (`find_best`, `efficiency_gaps`) ignores it entirely (see ADR 0030). Any
  new consumer of `integrations.get_override()` must decide fresh whether it needs this
  distinction.
- This auto/pinned split — disposable content can omit, user-curated content must never silently
  vanish — generalizes beyond remaps. A future proactive surface with the same
  disposable-vs-curated distinction is a candidate for the same pattern.
