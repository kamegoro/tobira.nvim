# Architecture Decision Records

This directory holds short, git-versioned records of non-obvious design decisions —
the "why we chose this over the alternatives" narrative that used to get pasted as a
prose header into whichever `.lua` file the decision affected (see #183).

## Why ADRs instead of inline comments or CLAUDE.md

- **Inline comments** should state the present-tense rule a maintainer needs to not
  break the code (`-- threshold is 2, not 1 — see ADR`), not the multi-paragraph
  history of how the team arrived at that rule. Long narrative buried in the file
  makes the actual logic hard to scan.
- **A project `CLAUDE.md`** is the wrong place for this bulk too: it's read in full by
  any agent touching the module, relevant or not, so moving narrative there just
  relocates the fixed-cost tax instead of cutting it.
- **An ADR** is read only by whoever is about to touch the specific module it covers,
  linked from the code by a single pointer comment. Cost is paid once, on demand,
  by the person who actually needs the context.

## Format: MADR-minimal

One file per decision (or one file per small cluster of closely-related decisions).
No pros/cons tables, no status/date/author metadata — just three sections:

```markdown
# <short title of the decision>

## Context

What problem or constraint forced a choice. Include the concrete scenario/example
that motivated it, not just the abstract issue.

## Decision

What was actually decided (and, where useful, what was deliberately NOT done).

## Consequences

What this buys you, and what it costs / what to watch out for.
```

See `0000-template.md` for a copy-pasteable skeleton, and `0001-terminal-mode-escape-streak-detection.md`
for a real example.

## Naming and linking

- Files are numbered sequentially: `NNNN-slug.md`.
- Reference an ADR from code with a one-line pointer comment, e.g.:
  ```lua
  -- see docs/adr/0001-terminal-mode-escape-streak-detection.md for why this
  -- module/threshold/design exists
  ```
- If you're about to edit a module that carries an ADR pointer comment, **read the
  ADR first** — it has the rationale/history. Don't re-derive or re-explain it inline;
  update the ADR itself if the decision changes.

## Superseding vs. amending an existing ADR

ADRs are an immutable decision log — once accepted, a file's history is never deleted
or rewritten. When a later change touches a decision an ADR already covers, pick one
of these two moves; don't default to "just start a new file" without checking which
one actually applies:

- **The decision was replaced/reversed** (a genuinely different choice was made, not
  a tweak to the original one): write a **new ADR** for the new decision, and add a
  one-line marker near the top of the old file:

  ```markdown
  # <original title>

  **Superseded by [docs/adr/NNNN-slug.md](NNNN-slug.md).**

  ## Context
  ...
  ```

  Never delete or rewrite the old ADR's `Context`/`Decision`/`Consequences` — the old
  reasoning is still valuable history even after it stops being current practice.

- **The same original decision was refined** (an edge case turned up later, a
  threshold got tuned, an exemption got added — the original choice still stands,
  just with more nuance): **amend the existing ADR in place** instead of forking a new
  file. Add to its `Consequences` section, or add a short `### Known limitation` /
  `### Addendum` subsection. `0016-pattern-dispatch-priority-and-key-collisions.md`
  does this correctly — its "Known limitation (investigated in #265, resolved in
  #280)" subsection was added by a later PR to record a follow-up finding about the
  same dispatch-priority decision, then amended again in place (not forked into a new
  ADR) once that finding was actually resolved. Use it as the reference example.

  A new ADR number is *not* required just because a later PR is doing the editing —
  only because the decision itself changed.

**Before creating a new ADR, always compute the next number from the actual
directory** — never from memory of "the last number I saw." Two independently
authored PRs (#274, #277) once picked the same next-free number this way and both
merged, because nothing checked at review time; #284 fixed the collision and added
the CI gate below, but the gate is a safety net, not a substitute for checking first:

```bash
ls docs/adr/*.md | grep -oE '^docs/adr/[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1
```

Run that (or the equivalent) immediately before naming the new file, right before you
create it — not earlier in the session, since another ADR may land in between.

CI (`.github/scripts/check_adr_numbering.py`, run from the "Scripts (Python unit
tests)" step in `ci.yml`) fails the build if two `docs/adr/*.md` files ever share a
number prefix. That catches a collision that slips through review; it does not
replace computing the number correctly in the first place.

## Index by module

Ground-truth index of every ADR, grouped by which module actually points to it via a `-- see docs/adr/NNNN-*.md` pointer comment. Generated by grepping the codebase for that exact pattern (not hand-maintained) — if this drifts from reality, regenerate it rather than hand-editing it out of sync.

81 ADRs total, across 14 `lua/tobira/` modules.

### lua/tobira/commands.lua

- 0007 — reactive-only-ambient-exclusion
- 0008 — composite-keys-for-dual-meaning-bytes
- 0009 — register-underuse-bypasses-trigger-count
- 0010 — ex-command-never-tried-gate
- 0011 — diff-mode-reuses-existing-thresholds
- 0012 — reactive-only-direct-fire-entries
- 0013 — substitute-repeat-ampersand-escalation
- 0099 — diff-obtain-put-after-hunk-jump
- 0101 — tilde-repeat-text-object-refinement
- 0107 — n-repeat-intent-neutral-reactive-cgn

### lua/tobira/core/graph.lua

- 0007 — reactive-only-ambient-exclusion
- 0010 — ex-command-never-tried-gate
- 0029 — graded-forgotten-command-detection
- 0030 — keymap-override-exclusion-contract
- 0031 — priority-pool-for-gate-bypassing-candidates
- 0032 — find-best-sentinel-negative-infinity
- 0107 — n-repeat-intent-neutral-reactive-cgn
- 0111 — bounded-severity-scoring

### lua/tobira/core/integrations.lua

- 0008 — composite-keys-for-dual-meaning-bytes
- 0051 — integrations-phase-gating
- 0052 — equivalent-remap-distinction
- 0053 — plugin-presence-without-require
- 0054 — promotion-rules-reuse-existing-commands
- 0055 — refresh-cadence-and-notification-dedup
- 0102 — builtin-default-mapping-sid-detection

### lua/tobira/core/logger.lua

- 0014 — usage-json-concurrent-merge-and-migration
- 0015 — ex-command-verify-before-credit
- 0016 — pattern-dispatch-priority-and-key-collisions
- 0017 — mode-cache-state-reset-boundaries
- 0095 — cmdline-history-recall-detection
- 0099 — diff-obtain-put-after-hunk-jump
- 0106 — text-object-variant-own-usage-tracking
- 0112 — buffer-local-seq-reset-with-ctrl-w-exemption
- 0113 — macro-dispatch-priority-generalization
- 0115 — macro-edit-keys-mode-source-distinction

### lua/tobira/core/patterns.lua

- 0018 — macro-opportunity-detection
- 0019 — jumplist-changelist-underuse-detection
- 0020 — ci-quote-streak-and-tolerance
- 0021 — visual-repeat-gv-detection
- 0022 — gq-operator-pending-and-post-format-jumpback
- 0023 — register-mark-bracket-prefix-consumers
- 0024 — ctrl-w-window-compound-and-close-streak
- 0025 — paste-motion-streak
- 0026 — state-machine-bookkeeping-invariants
- 0027 — tolerated-motion-streaks-r-and-ctrl-a
- 0096 — ctrl-w-resize-streak
- 0097 — cursor-centering-streak
- 0098 — visual-block-edit-streak
- 0099 — diff-obtain-put-after-hunk-jump
- 0100 — named-mark-repeated-line-return
- 0101 — tilde-repeat-text-object-refinement
- 0106 — text-object-variant-own-usage-tracking
- 0107 — n-repeat-intent-neutral-reactive-cgn
- 0112 — buffer-local-seq-reset-with-ctrl-w-exemption
- 0113 — macro-dispatch-priority-generalization
- 0114 — prefix-consumer-streak-bookkeeping
- 0115 — macro-edit-keys-mode-source-distinction

### lua/tobira/core/patterns_cmdline.lua

- 0002 — ex-command-tokenizer-one-shot-parsing
- 0003 — cmdline-command-arg-shared-argument-extraction
- 0004 — ex-file-pingpong-detection
- 0005 — tabnew-one-file-per-tab-detection
- 0006 — cmdline-substitute-repeat-detection
- 0015 — ex-command-verify-before-credit
- 0095 — cmdline-history-recall-detection
- 0110 — cmdline-state-lru-eviction

### lua/tobira/core/patterns_insert.lua

- 0037 — insert-co-oneshot-crosses-mode-boundary
- 0038 — insert-bounce-detection-lives-in-patterns-insert
- 0039 — insert-completion-repeat-token-reconstruction

### lua/tobira/core/patterns_terminal.lua

- 0001 — terminal-mode-escape-streak-detection

### lua/tobira/core/suggest.lua

- 0045 — equivalent-override-suppression-exemption
- 0046 — terminal-category-cooldown-bypass
- 0047 — adoption-watch-keytrans-rolling-buffer
- 0112 — unified-suggestion-scheduling

### lua/tobira/ui/float.lua

- 0080 — suggestion-float-border-ambiwidth-double-fallback
- 0081 — terminal-category-auto-dismiss-duration
- 0082 — celebrate-completes-habit-loop

### lua/tobira/ui/guide.lua

- 0060 — guide-auto-section-capped-never-tried-first
- 0061 — guide-auto-vs-pinned-remap-visibility
- 0062 — guide-mastery-glyph-forgotten-priority
- 0103 — guide-scrollable-focusable-window
- 0104 — guide-row-indent-aware-wrapping

### lua/tobira/ui/hls.lua

- 0105 — hls-set-range-legacy-highlight-semantics

### lua/tobira/ui/progress.lua

- 0068 — progress-forgotten-overrides-mastery-glyph
- 0069 — progress-mastered-ratio-uses-is-mastered
- 0070 — progress-preview-strip-stable-height-and-in-place-refresh
- 0071 — progress-preview-key-padding-minimum-gap
- 0072 — progress-cursor-cell-mapping-uses-display-column
- 0073 — progress-nav-hints-in-window-footer

### lua/tobira/ui/stats.lua

- 0030 — keymap-override-exclusion-contract
- 0074 — stats-dynamic-key-column-width
- 0075 — stats-actionable-first-ordering
- 0076 — stats-forgotten-overrides-mastery-star

### Test / demo infrastructure (not a `lua/tobira/` production module)

These ADRs document decisions in test or demo scaffolding rather than plugin source, so there's no `lua/tobira/` module to sort them under. They still have real inbound pointer comments from code — just from `tests/*.lua` or `docs/demo-init.lua` — so they are not orphans.

- 0090 — demo-seed-data-mastery-profile (`docs/demo-init.lua`)
- 0091 — demo-idle-and-pattern-toggles-are-independent (`docs/demo-init.lua`)
- 0092 — test-stdpath-data-redirect-ordering (`tests/minimal_init.lua`)
- 0093 — luacov-flush-before-plenary-hard-quit (`tests/minimal_init.lua`)
- 0094 — locale-spec-dynamic-locale-discovery (`tests/spec/unit/locale_spec.lua`)

### Not referenced from code

No `-- see docs/adr/NNNN` pointer exists anywhere in the codebase for these ADRs (checked every `.lua` file under `lua/`, `plugin/`, `tests/`, and `docs/`). This audit exists to surface exactly this case — treat each entry as a prompt to check whether its pointer comment was lost in a later refactor, not as proof the decision no longer matters.

- 0028 — operator-streak-tracking-dd-cc-indent-dedent
