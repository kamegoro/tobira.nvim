# lua/tobira/ui/ — CLAUDE.md

## The one rule: never hardcode a color

Every highlight group in `hls.lua` is defined with `link`, never `fg`/`bg` hex values. This is
not a style preference — it is what lets tobira render correctly in every user's colorscheme
without tobira having to know what that colorscheme is. A new UI element is done when its color
is a `link` to an existing semantic group, not when it "looks right" in one theme.

```lua
-- ✅ inherits whatever the user's colorscheme defines for Comment
vim.api.nvim_set_hl(0, 'TobiraDim', { link = 'Comment' })

-- ❌ looks fine in Catppuccin Mocha, wrong everywhere else
vim.api.nvim_set_hl(0, 'TobiraDim', { fg = '#6c7086' })
```

Before adding a new `Tobira*` group, check this file's tables first — the semantic slot you need
probably already exists.

## Two independent color vocabularies

tobira's UI uses color for two unrelated purposes. Don't mix them.

**Category color** — *what kind of command is this* (motion / edit / search / window / fold /
mark / macro). Currently only the suggestion float's border uses it (`ui/float.lua`,
`CATEGORY_HL` table). It answers "what kind" and stays constant for a given command regardless of
how well the user knows it.

**State color** — *how well does the user know this command* (never tried / learning / mastered /
forgotten / pinned). Used by Guide and Progress. It answers "how far along" and changes over time
as `usage.json` accumulates.

A command's border in the suggestion float and its mastery glyph in Guide are never the same
color for the same reason — one encodes category, the other encodes progress. Don't reach for a
category color to represent a state, or vice versa.

### Category → hlgroup (suggestion float border, `ui/float.lua`)

| Category | hlgroup | Links to |
|---|---|---|
| motion | `TobiraSuggestMotion` | `Special` |
| edit | `TobiraSuggestEdit` | `Function` |
| search | `TobiraSuggestSearch` | `String` |
| window | `TobiraSuggestWindow` | `Type` |
| fold | `TobiraSuggestFold` | `Constant` |
| mark | `TobiraSuggestMark` | `Identifier` |
| macro | `TobiraSuggestMacro` | `PreProc` |

The mapping targets Neovim's own syntax-highlighting groups, not diagnostic or UI groups — the
intuition being "motion is a keyword-ish thing, edit is function-ish, search is string-ish." If
you add an 8th category to `commands.lua`, pick the nearest syntax group by the same intuition
before inventing a new link target.

### State → hlgroup (Guide / Progress mastery symbols)

| State | Glyph | hlgroup | Links to |
|---|---|---|---|
| mastered (level 4, count ≥ 5000) | `★★★` | `TobiraGuideMastered` | `DiagnosticOk` |
| learning (level 2–3, count ≥ 100) | `★`/`★★` | `TobiraGuideLearning` | `DiagnosticWarn` |
| tried (level 1, count ≥ 1) | `☆` | `TobiraGuideHint` | `Comment` |
| never tried (level 0) | blank / dim text | `TobiraDim` | `Comment` |
| forgotten (`graph.is_forgotten()`) | `⟳` | `TobiraGuideForgotten` | `DiagnosticHint` |
| pinned | `●` | `TobiraGuidePinned` | `DiagnosticInfo` |
| suppressed | `✗` | `TobiraGuideSuppressed` | `Comment` |

`TobiraDim` and `TobiraH1` (→ `Title`, used for section/status headings across Guide, Progress,
Stats) are tracked in #66 as the shared foundation the three panel redesigns (#67, #68, #74) build
on — add new state colors there, not per-screen.

**Never reuse a state color for two states on the same screen.** `TobiraGuideForgotten` links to
`DiagnosticHint` and *not* `DiagnosticWarn` specifically because `TobiraGuideLearning` already
owns `DiagnosticWarn` — reusing it would make "still learning" and "forgotten" render identically
on the same Guide row, which defeats the entire point of a distinct signal. When adding a state
color, grep `hls.lua` for the target group first; if it's taken, pick the next unused
`Diagnostic*` group rather than doubling one up.

`TobiraGuideUpgrade` (formerly → `DiagnosticHint`, the old `:TobiraProgress` "Next: …" line) was
removed when #67 landed — the preview strip replaced that line entirely, so the group had no
remaining caller. If you're looking for the "what should I learn next" signal on Progress, that's
now `progress.preview.to_next` in the cursor-driven preview strip, not a static hlgroup.

## Why these particular design choices (pointers, not restated here)

Each screen's layout traces back to a specific piece of UX research, argued in full in its issue.
Don't re-derive these from scratch if you're touching one of these screens — read the issue first:

- Suggestion float (`ui/float.lua`, shipped in #71/#72): habit-loop (cue → routine → reward) +
  toast-notification 6–9s convention + Clippy-postmortem lessons (always show why, always show
  how to mute)
- `:TobiraGuide` (#68): Nielsen's "recognition rather than recall" — the screen's entire job is
  letting a user recognize what they already half-know instead of making them recall it
- `:TobiraProgress` (#66/#67): goal-gradient effect — visible distance to the next milestone
  (`{n} more to reach {sym}`) motivates continued use more than an abstract count
- `:TobiraStats` (#74): dashboard "5-second rule" + actionable-vs-vanity metrics — the one section
  that changes what the user does next (`efficiency_gaps`) leads; the one that doesn't (raw
  keystroke count) trails

## Extension checklist

- [ ] New hlgroup? → `link` only, no hex, added to `hls.lua`'s existing category or state table
- [ ] New state color? → check the State table above for a free `Diagnostic*` slot before adding one
- [ ] New user-visible string? → both `locales/en.lua` and `locales/ja.lua` (see
  `locales/CLAUDE.md`)
- [ ] Touching `guide.lua`/`progress.lua`/`stats.lua` rendering? → check whether the change reads
  usage data through `graph.lua`'s existing predicates (`is_mastered`, `is_forgotten`,
  `mastery_level`) rather than re-deriving thresholds inline
