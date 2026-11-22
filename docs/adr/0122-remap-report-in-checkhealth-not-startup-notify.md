# Report keymap overrides in :checkhealth, never with a startup notification (#354)

## Context

`integrations.refresh()` used to call `vim.notify(..., vim.log.levels.DEBUG)` once per newly
detected override (`docs/adr/0055-refresh-cadence-and-notification-dedup.md`). The DEBUG level
was meant to keep it quiet, but the built-in `vim.notify` prints every level. On a stock
Neovim 0.12.6 with no user mappings, the 0.11+ defaults `]a`/`[a` were misdetected as overrides
(their `desc` was missing from the curated default table), so every startup printed

    tobira: ]a is remapped (:next) — removed from suggestion pool
    tobira: [a is remapped (:previous) — removed from suggestion pool

plus a line for matchit's `%`. In an 80x24 terminal that raised a hit-enter prompt.
Several public configs wrapped `vim.notify` only to drop these lines. The message also
said "removed" for equivalent overrides such as `%`, which stay in the pool.

## Decision

- `refresh()` is silent. The `_logged` dedup cache is gone with the notification it
  deduplicated.
- `:checkhealth tobira` calls `refresh()` and lists every override with
  `vim.health.info`: `health.remap_removed` for a non-equivalent remap, `health.remap_equivalent`
  ("still suggested") for an equivalent one, and an `ok` line (`health.remaps_none`) when
  there are none. The strings live in every locale.
- `notifications.remap_detected` stays in every locale file even though nothing emits it,
  because user configs read or match on it.

Rejected: keeping the notification at a lower level or behind an option. Any message
at startup is noise for a plugin that is meant to be ambient, and a key the user remapped
on purpose needs no announcement. The user who wonders why a key is never suggested
already has `:checkhealth` as the documented first stop (`:help tobira-troubleshooting`).

## Consequences

- No startup output on any Neovim, whatever the default-mapping table says.
- A remap is visible only when the user runs `:checkhealth tobira`. That is a deliberate
  loss of discoverability.
- The refresh cadence in ADR 0055 (setup + `VimEnter` + `SourcePost`) is unchanged.
