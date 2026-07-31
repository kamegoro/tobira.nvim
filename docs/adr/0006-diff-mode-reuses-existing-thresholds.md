# Diff-mode hunk navigation reuses existing j/k thresholds (#111)

## Context

While `&diff` is set (a diff view), hammering `j`/`k` to move between changed hunks
is inefficient the same way it's inefficient outside diff mode, but the *better*
alternative is different: outside diff mode the fix is paragraph motion (`}`/`{`);
inside diff mode, jumping straight to the next/previous changed hunk (`]c`/`[c`)
beats paragraph motion, since paragraph boundaries and hunk boundaries rarely
coincide.

`vim.wo.diff` is a read-only window-local option. Reading it belongs in
`logger.lua`'s `handle_key`, not inside `patterns.lua` itself — `patterns.lua` must
stay free of `vim.*` calls per the module dependency rules
(`lua/tobira/CLAUDE.md`), so the diff flag is threaded into `patterns.feed()` as a
plain boolean parameter instead.

## Decision

- No new detection pattern or threshold: this reuses the **existing** `j_many` /
  `k_many` thresholds (10 presses in a row) that already exist for the `}`/`{`
  suggestion. The only change is which suggestion fires when the threshold is hit —
  `]c`/`[c` while `&diff` is set, `}`/`{` otherwise.
- `track = false` on both entries: like most other multi-char suggestion-only
  entries (`ddp`, `{n}j`, ...), nothing else in the registry references `]c`/`[c`
  via `requires`, so there's no downstream `count >= N` threshold depending on
  these being individually tracked.
- `requires = 'j'` / `requires = 'k'` respectively, mirroring the existing `}`/`{`
  chain's anchors rather than inventing a new anchor for the diff-mode variant.

## Consequences

- A future mode-conditional suggestion swap (same trigger, different suggested
  command depending on window/buffer state) should look here first before adding a
  new pattern — check whether an existing threshold can be reused with the state
  flag threaded through as a parameter, the way `&diff` is here.
- Because there's no new pattern, there's also no new `patterns_spec.lua` test
  category for this — the mode-conditional branch is instead covered where
  `patterns.feed()` is called with `diff = true`.
