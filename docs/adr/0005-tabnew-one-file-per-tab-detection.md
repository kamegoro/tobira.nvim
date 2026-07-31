# Tabnew one-file-per-tab habit detection (#113, `patterns_cmdline.lua`)

## Context

Some users treat tabs as a VSCode-style file browser: `:tabnew` a new file, one tab per
file, repeatedly, when Vim's own buffer-switching commands (`:b`, `<C-^>`) would serve the
same need without accumulating tabs. This needed a trigger condition that reliably means
"browsing files by opening new tabs" and reuses `commands.lua`'s existing `<C-^>` entry
rather than duplicating it.

A QA bug shaped the current design: the first version tracked only "was *some* argument
given" as a boolean, so re-opening the exact same file 3 times via `:tabnew` fired the
suggestion — but Vim reuses the existing buffer for a filename already open elsewhere, so
there's only ever 1 real buffer in that scenario, making the `:b`/`<C-^>` suggestion
nonsensical.

## Decision

- **Second, independent state machine in the same file** as `tokenize()`/`command_arg()`
  — shares no state with them, but stays here because it fires from the same call site
  (the tokenized Ex-command name at `<CR>` time, inside `logger.lua`'s
  `handle_cmdline_key`; call path, not shared state, decides module splitting — see
  `lua/tobira/CLAUDE.md`).
- **Threshold is 3 consecutive `:tabnew` submissions**, each opening a genuinely new file,
  with no intervening window split.
- **A bare `:tabnew` (no file argument) resets the streak.** It opens an empty scratch
  tab, not "one more file browsed" — it says nothing about the habit this feature targets.
- **A repeated filename resets the streak (the QA fix), rather than being ignored or
  counted as a new streak's first file.** `seq.files` tracks every filename already seen
  this streak; the moment `:tabnew` reuses one, that's evidence the user isn't purely
  file-browsing — resetting (not merely not-counting) means 2 more distinct files after
  the repeat still don't reach 3 and fire.
- **An added window split resets the streak too.** `win_count` is the *current* tabpage's
  window count, read by `logger.lua` since `vim.on_key` fires before this `<CR>`'s effect
  lands — so at the moment this fires, "current tabpage" is still the tab the *previous*
  `:tabnew` opened, exactly the one that needs checking for an added split. If it picked
  up a second window (`:split`, `<C-w>v`, ...) before this `:tabnew`, that's a legitimate
  multi-window layout, not one-tab-per-file browsing — but this `:tabnew` still starts a
  fresh potential streak of its own rather than being discarded outright.

## Consequences

- The threshold (3), the bare-tabnew reset, the split reset, and the repeated-filename
  reset are all load-bearing — removing any of them reopens either a false positive (the
  QA bug above) or a missed detection. See the inline pointer comments on
  `new_tabnew_seq()`/`feed_tabnew()`.
- `feed_tabnew()` is only ever called for `":tabnew"` submissions — `logger.lua` checks
  `tokenize()`'s result first, so any other Ex command is silently a no-op for this
  streak (not a reset), since it says nothing about window layout.
