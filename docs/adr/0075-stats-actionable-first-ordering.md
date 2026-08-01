# Stats panel leads with actionable content and uses two deliberately different data scopes

## Context

`:TobiraStats` originally opened with Mastery and a raw keystroke count as its
headline numbers — neither tells the user what to actually do next. The
dashboard "5-second rule" (the most important information should be visible
without scrolling or reading) and the actionable-vs-vanity-metrics distinction
(surface what changes the user's next action; de-emphasize what's merely
interesting) argued for the reverse: the one section that tells the user what
to try next (`graph.efficiency_gaps()`, "Try these next") should lead, and the
raw keystroke total — fun to see, drives no decision — should trail as a
dimmed footer line (#74).

Getting the order right also surfaced that the sections don't all count the
same thing, and that's intentional rather than an oversight: "Top commands"
and the footer's keystroke total sum every entry in the raw `usage` table
(basic keys like `j`/`k`, compound ops like `dd`) because they answer "what
did I actually press" — while Mastery's discovered/total ratio comes from
`graph.knowledge_dist()`, which is scoped to `commands.lua`'s registry, because
it answers "how much of the taught curriculum have I learned."

## Decision

- Render order is fixed: Try these next → Mastery → Top commands → footer
  summary (`TobiraDim`), omitting the Try-these-next section entirely when
  `graph.efficiency_gaps()` returns no rows.
- "Top commands" and the footer's total keystrokes deliberately read the full
  `usage` table (any tracked key, including ones outside the registry).
- Mastery's percentage and distribution deliberately read
  `graph.knowledge_dist()` instead, which only counts registry commands.

## Consequences

- A new section must decide up front which of the two scopes it belongs to
  (raw usage vs. registry-scoped) and where it sits on the
  actionable-vs-vanity spectrum before a position is chosen — don't default to
  appending at the bottom.
- Conflating the two scopes (e.g., deriving "discovered" from the raw `usage`
  table instead of `knowledge_dist`) would silently miscount, since basic keys
  and compound ops aren't part of the taught curriculum the ratio describes.
