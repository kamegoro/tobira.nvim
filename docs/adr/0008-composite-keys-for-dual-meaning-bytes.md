# Composite registry keys for keys with mode-dependent dual meanings

## Context

`commands.registry` is a flat Lua table keyed by the string the user types. Several
physical keystrokes mean two entirely different things depending on mode, but a Lua
table can only hold one value per key string:

- `<C-w>`: in normal mode it's the window-command prefix (`<C-w>s`, `<C-w>w`, ...,
  already registered); in insert mode it deletes the word before the cursor — a
  completely different, single-shot command (#58-era insert-mode inefficiency
  detection).
- `<C-n>`: in normal mode it's the built-in down-motion; in insert mode it triggers
  completion. `insert_completion_repeat` (`patterns_insert.lua`) detects a fully
  retyped identifier of 6+ characters and wants to suggest `<C-n>` for it.
- `<C-o>`: the registered normal-mode entry means "jump back in the jumplist". A
  *different* insert-mode command bound to the identical physical key runs one
  normal-mode command and returns to insert automatically (#105).

Two further constraints: `logger.lua`'s `build_track_table()` builds a generic,
mode-unaware map from raw byte to command name for its `vim.on_key` hot path — it
cannot distinguish which mode a byte was pressed in. And any UI that renders a
registry key as "the key to press" (`ui/guide.lua`, `ui/stats.lua`,
`core/skills.lua`) needs to show the user the real keystroke, never an internal
disambiguation artifact.

## Decision

- **`<C-w>` (insert) and `<C-n>` (insert)**: keep the literal raw-byte key string in
  the registry (no renaming), but set `track = false` on the insert-mode meaning and
  count it explicitly from inside `handle_insert_key()` after the mode cache
  confirms insert mode — see `logger.lua`'s `INSERT_SPECIAL`. This keeps
  `build_track_table()`'s generic table from also claiming the byte for the
  insert-mode command, which would otherwise misattribute normal-mode presses to it
  (or vice versa).
- **`<C-o>` (insert)**: the same raw-byte approach doesn't work here because the
  *normal-mode* meaning already legitimately owns the literal `'<C-o>'` key with
  `track = true`. Instead this command gets its own composite registry key,
  `'i_<C-o>'`, so `graph.lua` can derive a second, independent suggestion entry from
  it. The user never types `'i_<C-o>'` literally.
- **`commands.display_key(cmd)`**: strips a leading `i_` prefix back off before any
  UI shows a registry key as "the key to press". Ordinary registry keys (including
  `'<C-w>'`/`'<C-n>'`, which were never renamed) pass through unchanged.

## Consequences

- Two different disambiguation mechanisms coexist on purpose: raw-byte-shared +
  `track = false` + explicit counting (for `<C-w>`/`<C-n>`, where the insert-mode
  meaning is the only one that needed its own registry entry) vs. composite-key
  (for `<C-o>`, where *both* meanings already have independent registry entries and
  need to stay independently addressable).
- Any future key with a mode-dependent dual meaning needs to pick between these two
  shapes based on whether the non-composite meaning already occupies the raw string
  with `track = true`. If it does, use the composite-key approach; if the raw string
  is otherwise free, share it with `track = false` + explicit counting instead.
- Forgetting `commands.display_key()` in a new UI surface would leak the internal
  `i_` prefix to the user.
