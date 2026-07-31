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
