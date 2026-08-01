# Keymap-override detection is ungated; plugin-detection promotions are gated (#63)

## Context

`integrations.lua` does two conceptually different things behind one `M.refresh()`:

1. **Phase 1** — detect the user's own keymap overrides (`nvim_get_keymap`), so
   `graph.find_best()` and `ui/guide.lua` never present a remapped key as if it still
   did what `commands.lua` says it does (e.g. the user has `nnoremap s <Plug>(...)`
   from a plugin, so tobira's own `s` suggestion body would be actively wrong).
2. **Phase 2** — detect installed helper plugins (`nvim_get_runtime_file`) and use that
   to promote specific existing suggestions (`PROMOTION_RULES`) ahead of `find_best()`'s
   ordinary trigger-count gate.

Both are "integration with the user's real editor environment", so it would be
consistent to gate both behind the same `config.values.integrations` flag. But they
have very different failure modes if left on unconditionally:

- Phase 1 off means tobira happily suggests a key the user has already repurposed for
  something else — that's not a stylistic choice, it's tobira being wrong about what a
  keystroke does in the user's actual editor.
- Phase 2 off just means tobira doesn't get extra help from noticing a plugin is
  installed; the suggestions it makes without that help are still correct, just
  possibly less well-prioritized.

## Decision

Phase 1 is **not** gated by `config.values.integrations` — it always runs. A config flag
to disable it would be a footgun: "never suggest a command whose key you've personally
remapped" is baseline correctness, not an optional integration a user might reasonably
want less of.

Phase 2 (`M.get_promotions`) **is** gated: it returns an empty table outright whenever
`config.values.integrations` is disabled, before even checking `M.has_plugin()`. This is
the one part of the module some users may reasonably want to opt out of, since it
actively changes which commands get pushed harder based on plugins tobira detects on
their runtimepath.

## Consequences

- A new detection feature added to this module needs the same question asked before
  wiring it up: does skipping it make tobira actively *wrong* (→ ungated, like phase 1),
  or does skipping it just make tobira less well-informed (→ gated, like phase 2)?
- `M.refresh()` itself always does both phases' detection work regardless of the config
  flag — only `M.get_promotions()`'s *use* of the phase-2 result is gated. This keeps
  `_plugins` available for `M.has_plugin()` callers that aren't the promotion path,
  without needing a second gate inside `detect_plugins()` itself.
