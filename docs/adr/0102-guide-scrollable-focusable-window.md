# Guide window becomes focusable so its own overflow is scrollable

## Context

`:TobiraGuide`'s content grows with how many categories a user has populated.
`docs/adr/0060-guide-auto-section-capped-never-tried-first.md` already caps each
category at 3 unmastered commands, but with realistic usage spread across many
categories the *number of categories themselves* still adds up: #266 found that on a
long-time user's data, the panel's raw content was 45 buffer lines before
line-wrap expansion, while `M.open()` capped the window height at
`math.min(wrapped_height(lines), screen_h - 4)` and set `focusable = false`. On a
100×34 terminal this meant 7 of 10 categories rendered completely off-window —
permanently unreachable, with no scroll, no pagination, and no indication more
content existed at all.

This collides with the panel's original design principle from #68 (see
`lua/tobira/ui/CLAUDE.md`'s "Why these particular design choices" section):
Nielsen's "recognition rather than recall" shipped Guide with zero keymaps on
purpose, unlike Progress/Stats — see also `doc/tobira.txt`'s ":TobiraGuide ...
passive and read-only ... no keybindings of its own." A fix that added
Guide-specific scroll keymaps (`q`/`j`/`k`-style bindings, mirroring how Stats and
Progress define their own close/navigation keys) would trade that property away.

## Decision

Set `focusable = true` on the Guide floating window (previously `false`), while
leaving `enter = false` on `nvim_open_win()` unchanged — opening the panel still never
steals focus. `focusable = true` alone is enough for Neovim's own window-navigation
commands (`<C-w>w`, mouse click, `<C-w>` + direction, etc.) to move the cursor into
the window; once inside, Neovim's built-in scrolling (`j`/`k`/`<C-d>`/`<C-u>`/`gg`/`G`,
...) works exactly as it would in any other window. No plugin-defined keymap is added
— Guide still defines none of its own, matching #92's original reasoning for why the
panel has no footer hint either.

This was chosen over adding explicit scroll-only keymaps because it is a strictly
smaller change (one boolean) and keeps "Guide defines no keymaps of its own" fully
intact, rather than narrowing it to "no keymaps except scrolling."

`M.refresh()`'s window-height calculation was also changed to reuse the same
`screen_h - 4` cap `M.open()` already applied (both now go through a shared
`target_height()` helper). `M.refresh()` previously called
`nvim_win_set_height(_win, wrapped_height(lines))` with no cap at all — a latent
inconsistency with `M.open()`'s own cap that the original bug report didn't surface,
since `M.refresh()` only runs on a `WinEnter`/`BufEnter` into some *other* window, not
on every open.

## Consequences

- Every category is now reachable on any terminal size, at the cost of an extra
  manual step (moving focus into the window) to reach content that doesn't already
  fit. There is still no visual affordance inside the panel hinting that more content
  exists below the fold, beyond the existing per-category "+N more" overflow line
  (see `docs/adr/0060-guide-auto-section-capped-never-tried-first.md`) — a user has to
  already know (or discover by trying `<C-w>w`) that the window can be entered.
- The panel remains passive by default: opening it still leaves focus wherever it
  was, matching its original ambient, non-intrusive design.
- `doc/tobira.txt`'s `:TobiraGuide` section was updated to describe the window as
  enterable-to-scroll via Neovim's own defaults, while keeping the "no keybindings of
  its own" line accurate.
