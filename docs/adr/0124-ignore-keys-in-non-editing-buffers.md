# Ignore keystrokes in buffers that are not user editing

## Context

`lua/tobira/core` never looked at `buftype`, so every keystroke counted the
same wherever it was typed (#357). Reproduced: moving with `j` inside
`:TobiraProgress` showed "You pressed j 10 times" on top of tobira's own panel
and raised `usage.j.count`; `<BS>`×5 in a `buftype=prompt` buffer (how
Telescope's prompt is built) suggested `<C-w>`; `j`×10 inside `:help`
suggested `}`. These keystrokes are browsing or driving a plugin UI, not
editing text, and they skew the usage data every suggestion is built on.

## Decision

`core/buffers.lua`'s `is_ignored(buf)` decides by `buftype` and `modifiable`:

| buftype | ignored | evidence |
|---|---|---|
| `prompt` | always | single-line plugin input (Telescope prompt, REPLs) |
| `nofile` | only when not modifiable | tobira's panels and suggestion float, neo-tree, lazy.nvim, mason.nvim all set `nofile` + `nomodifiable`; but `nofile` + modifiable is real editing: the cmdline window (`q:`), the `:h scratch-buffer` idiom, chat/input buffers such as CopilotChat's |
| `help` | only when not modifiable | `:help` opens it `nomodifiable`; editing a help file is done by `:e`, which gives `buftype=""` |
| `quickfix` | only when not modifiable | default is `nomodifiable`; plugins that edit quickfix lists make it modifiable |
| `""`, `acwrite`, `nowrite`, `terminal` | never | file editing (oil.nvim uses `acwrite`); terminal behavior is unchanged |

It is read live on each keystroke (two option reads, ~0.4–0.9µs measured)
rather than cached, because plugins toggle `modifiable` around redraws.

Applied in three places:

- `logger.lua`'s `handle_key` drops Normal, Visual, Insert and other
  buffer-mode keys in an ignored buffer, so nothing is counted and no pattern
  fires. Command-line keys are still handled (an Ex command is a command
  whichever buffer is current), and so are Terminal-mode keys.
- `suggest.lua`'s `M.show` (every automatic suggestion) shows nothing and does
  not start the cooldown while the current buffer is ignored. `:Tobira`
  (`M.manual`) is an explicit request and is not affected.
- `suggest.lua`'s adoption watcher ignores keys typed in an ignored buffer, so
  moving in a panel cannot count as adopting a suggestion.

Not done here: user-configurable lists (`ignore_filetypes`/`ignore_buftypes`)
and checking whether `<Esc>` is mapped inside a terminal buffer. Both are
product decisions, not defect fixes.

## Consequences

- Panels, help, quickfix and prompts no longer inflate counts or trigger
  suggestions.
- A plugin UI that is `nofile` but left modifiable (or uses `buftype=""`) is
  still counted; there is no user-side escape hatch until an option exists.
- Keys in an ignored buffer still restart the idle timers, so moving inside a
  panel still counts as activity, not as a pause.
