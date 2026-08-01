# Equivalent-override suppression exemption

## Context

`should_suppress(cmd)` used to include a blanket `integrations.is_overridden(cmd)`
check: any command with a user keymap override was suppressed from suggestions.
But Neovim ships a factory-default `nnoremap Y y$` (`:help Y-default`), so
`is_overridden('Y')` is `true` on literally every install — not just ones where the
user actually remapped `Y` themselves. After `y_dollar` → `Y` was added as a
suggestion (#103), this default mapping made `should_suppress` treat every install
as having "overridden" `Y`, permanently suppressing the suggestion everywhere it
should have fired (#177).

`integrations.lua` already had `is_equivalent_override(cmd)` — built for
`graph.find_best()`'s ambient path and `ui/guide.lua`'s Pinned section — to
recognise exactly this "harmless equivalent remap" case via an `EQUIVALENT_REMAPS`
table.

## Decision

`should_suppress` now suppresses on override only when the command `is_overridden`
**and not** `is_equivalent_override`:

```lua
(integrations.is_overridden(cmd) and not integrations.is_equivalent_override(cmd))
```

For any `cmd` with no `EQUIVALENT_REMAPS` entry, `is_equivalent_override(cmd)` is
always `false`, so this is identical to the old blanket check for every other
command. A genuine user override of `Y` (e.g. `:unmap`-ed back to legacy `yy`
semantics) still suppresses, because `is_equivalent_override('Y')` is only true for
the specific known-harmless remap, not for arbitrary remaps of `Y`.

## Consequences

- The reactive path (`suggest.show`/`suggest.queue`) and the ambient path
  (`graph.find_best`) both now consult `is_equivalent_override`, so a future
  `EQUIVALENT_REMAPS` entry benefits both without further changes to `suggest.lua`.
- Any new command added to `EQUIVALENT_REMAPS` automatically stops being suppressed
  by its own default mapping — that table is the single place to update, not
  `should_suppress` itself.
- Adding an `EQUIVALENT_REMAPS` entry for a remap that is *not* actually harmless
  (i.e. it changes behavior in a way a user might legitimately want to opt out of)
  would silently defeat suppression for it — that table needs the same care as
  this check.
