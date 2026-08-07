# Guide's auto section caps per category and sorts never-tried-first, not by mastery gradient

## Context

`:TobiraGuide` is a passive "glance while you code" sidebar (recognition-rather-than-recall
per #68 — see `lua/tobira/ui/CLAUDE.md`; it defines no keymaps of its own, though #266 later
made the window focusable so overflow can be scrolled with Neovim's own defaults — see
`docs/adr/0103-guide-scrollable-focusable-window.md`). Its whole point is showing more than the
user strictly needs, quickly, so they recognize what they already half-know. If every category's
full unmastered-command list rendered, the panel would grow without bound as a user's command set
grows, defeating that "glance" design outright.

A cap alone isn't enough — it also raises the question of *which* commands in a category get
shown when there are more unmastered ones than fit. `:TobiraProgress` already exists to show
"how close am I to the next star" (goal-gradient effect, #66/#67, see `ui/CLAUDE.md`). If Guide
sorted the same way, capping to `MAX_PER_CATEGORY` would systematically hide the commands a user
hasn't touched at all in favor of ones they've already started — the opposite of Guide's actual
job, which is surfacing blind spots.

## Decision

- `MAX_PER_CATEGORY = 3`: each category in the auto section is capped independently, regardless
  of how many unmastered commands that category actually has.
- Within a category, rows sort never-tried-first (commands with `count == 0`), alphabetical
  tie-break — deliberately not by mastery-gradient closeness. That gradient view is
  `:TobiraProgress`'s job, not Guide's.
- When the cap truncates a category, an explicit `+N more` line (`push_overflow`,
  `TobiraDim`) is pushed instead of silently dropping rows — a user should never see a category
  that looks complete when it isn't.

## Consequences

- Adding a new category (e.g. #111's `diff`) gets the same cap/sort/overflow treatment for free
  — no per-category tuning needed.
- If Guide's purpose ever shifts toward "what's close to mastery" instead of "what have you
  never tried", this sort order and Progress's gradient sort would start duplicating each other
  — that's a sign to revisit both together, not just Guide's in isolation.
- Raising `MAX_PER_CATEGORY` works against the "small sidebar" premise this decision protects;
  it also changes wrapped panel height (`wrapped_height`) and the window's vertical placement in
  `M.open()`.
