# lua/tobira/ — CLAUDE.md

## Module dependency rules

Dependencies flow strictly downward. Upward or circular dependencies are prohibited.

```
commands.lua        — data only; no vim.* calls; requires nothing
                      ↓
core/config.lua     — single source of truth for all settings
core/patterns.lua   — pure Lua; no vim.*; requires nothing (normal-mode operator grammar)
core/patterns_insert.lua — pure Lua; no vim.*; requires nothing (insert-mode key streaks,
                       #99 — shares no state with patterns.lua, split out on purpose)
core/patterns_cmdline.lua — pure Lua; no vim.*; requires nothing (Ex-command tokenizer,
                       #57 — takes one complete cmdline string at <CR> time, shares no
                       per-keystroke state with patterns.lua/patterns_insert.lua, split
                       out on purpose)
core/patterns_terminal.lua — pure Lua; no vim.*; requires nothing (terminal-mode <Esc>
                       streak, #110 — shares no state with patterns.lua or
                       patterns_insert.lua, same split-out precedent as #99)
core/graph.lua      — pure Lua; no vim.*; requires commands.lua only. Never requires
                       core/integrations.lua (see below) — find_best() only ever
                       receives its output as plain `overrides`/`promotions` table
                       parameters, so graph.lua stays pure and integrations-agnostic.
core/skills.lua     — pure Lua; requires commands.lua only
core/level.lua      — requires graph only
core/integrations.lua — requires commands + config (#63). Detects the user's own
                       keymap overrides (`nvim_get_keymap`) and installed helper
                       plugins (`nvim_get_runtime_file` presence check, never
                       require() — would force a lazy-loaded plugin to load). Shares
                       no state with graph.lua's scoring loop and is impure
                       (vim.on_key is NOT used here — this is autocmd-driven, not
                       hot-path — see its own header comment), which is why it is a
                       sibling of graph.lua rather than code inside it, per the
                       module-splitting policy below.
core/logger.lua     — requires patterns + patterns_insert + patterns_cmdline + patterns_terminal + commands
                      does NOT require suggest — notifies via on_pattern callback
core/suggest.lua    — requires config / logger / graph / integrations
                      ↓
i18n.lua            — requires config + locales
health.lua          — requires config / logger / locales (checkhealth entry point, not
                       required by anything else)
ui/hls.lua          — requires nothing (highlight group definitions, plus a small
                       set_range() extmark helper shared by all 4 panels — see
                       nvim_buf_add_highlight() migration, #151)
ui/float.lua        — requires i18n (display strings) / hls (setup_hls + set_range)
ui/stats.lua        — requires graph / logger / i18n / integrations / hls (setup_hls
                       + set_range, #151)
                       (#164: "Try these next" — graph.efficiency_gaps() — is this
                       panel's own headline actionable section, so it passes
                       integrations.get_overrides() through to efficiency_gaps() the
                       same way find_best() already receives it, instead of bypassing
                       the override check the way it used to.)
ui/guide.lua        — requires commands / graph / logger / i18n / hls (setup_hls +
                       set_range, #151) / integrations
                       (#63: the one surface bypassing find_best entirely, so it is
                       also the one place that reads integrations.lua's
                       equivalent/different distinction directly — see graph.lua's
                       find_best doc comment for why find_best itself doesn't. #164:
                       the Pinned section reads this same distinction, but unlike the
                       auto section never omits a row outright — see format_pinned_row's
                       header comment for why.)
ui/progress.lua     — requires graph / level / logger / skills / i18n / hls (setup_hls
                       + set_range, #151)
                      ↓
init.lua            — wiring layer: connects core and ui modules
plugin/tobira.lua   — registers commands and autocmds; require() inside callbacks only
```

`commands.lua` is the root of the graph. Any `require()` added to it will create a
circular dependency.

## Module splitting policy

Decide whether new code belongs in an existing file or a new sibling file **before**
writing it — don't wait until a file "feels long." This is not a line-count rule; it's a
state-sharing test (researched against snacks.nvim / gitsigns.nvim / telescope.nvim, all of
which split by independent concern rather than by size — see #99):

- **Shares module-local state, or is ever called from the same code path** as what's
  already in the file (e.g. a new getter that reads `usage`, a new branch in `handle_key`
  that still touches `seq`) → same file, no matter how large it gets. Splitting here
  scatters one conceptual flow (keystroke → pattern → increment → persist) across files
  and *increases* how many files a single change touches, for no benefit. This is why
  `core/logger.lua` is not split further despite being one of the larger files — its
  persistence, tracking, and public-API code all read or write the same `usage` table.
- **Shares nothing — no common state, never on the same call path** (e.g.
  `core/patterns.lua`'s normal-mode `seq`/`feed` vs. the insert-mode
  `new_insert_seq`/`feed_insert` split out in #99) → new sibling file. Splitting here
  makes each half *more* self-contained: touching one never requires reading the other.

Why this matters specifically for AI-assisted work: reading many small fragmented files
costs more tool calls and tokens than one cohesive file (["The AI-Legible
Codebase"](https://tianpan.co/blog/2026-04-13-the-ai-legible-codebase)). Splitting only
pays off when it lets a task-specific read skip content that's genuinely irrelevant to
that task — not whenever a number looks big.

## ADR pointer convention

Some modules carry a one-line `-- see docs/adr/NNNN-slug.md` pointer comment instead of
inline "why" prose. If you're about to touch a module with one of these, **read that
ADR first** — it has the rationale/history. Don't re-derive or re-explain it inline;
if the decision changes, update the ADR. See `docs/adr/README.md` for the format.

## Tracking design principle

**tobira uses only `vim.on_key()`. No TextYankPost, no vim.keymap.set.**

tobira is a passive observer — it never modifies the user's key mappings or intercepts
input. `vim.keymap.set` risks conflicting with user mappings. Hybrid approaches
(e.g., TextYankPost + vim.on_key) add complexity without covering more cases.

Ex-command tracking (#57) follows the same rule: no `CmdlineLeave`/`CmdlineChanged`
autocmd. `vim.on_key` already sees every cmdline keystroke; `logger.lua`'s
`handle_cmdline_key` calls `vim.fn.getcmdtype()`/`vim.fn.getcmdline()` from inside that
same callback instead of adding a second entry point. See `core/patterns_cmdline.lua`'s
header for why the tokenizer takes one complete string at `<CR>` time rather than
accumulating keystrokes itself (short version: `<Up>`/`<Down>` history recall replaces
the whole buffer non-incrementally, so a manual per-keystroke accumulator cannot
represent it — `vim.fn.getcmdline()` at the terminating keystroke always can).

## vim.on_key() performance

The callback fires on **every keystroke**. Keep it minimal.

**Never do inside the callback:**
- File I/O
- Heavy computation
- Uncached `require()` calls — cache module references in local variables at module load time

**Current optimizations in logger.lua:**
- Mode is cached via `ModeChanged` autocmd — `vim.fn.mode()` is never called in the hot path
- `suggest.queue()` debounces via `vim.defer_fn(fn, 1500)` — UI is never called directly

## patterns.lua — state machine

`inner_feed()` reconstructs Neovim's operator grammar from raw keystrokes so that
`dw`, `d3w`, `diw`, `daw`, `di"`, and `da(` all normalize to the same `last_op = 'dw'`.

**Operator-pending state (`pending_op`):**

```
d or c arrives → pending_op = 'd' | 'c'

While pending_op is set:
  [1-9]            → count digit; keep pending_op (handles d3w)
  same operator    → linewise; last_op = op .. op ('dd' or 'cc'); dd_streak/cc_streak
                     tracked separately per operator (#118 — a hardcoded 'dd' literal
                     here used to misattribute every cc as dd)
  j / k            → linewise; last_op = op .. op (dj/dk / cj/ck = line delete/change)
  i / a            → text-object prefix; set pending_text_obj, wait for next key
  w / b / e / $ …  → charwise motion; last_op = op .. 'w'
  <Esc>            → cancel; clear pending_op
```

**Handler ordering in `inner_feed`:**
`pending_g` / `pending_z` handlers must appear **before** the `f/F/t/T` handlers, otherwise
`gf` and `zt` are incorrectly captured as f/t searches. Apply the same rule to any new
two-character command prefix.

## How to add a command

1. Add one entry to `commands.lua`
   - If `requires` is multi-char, add a `compound = true` entry for it first
   - `requires`, `category` (motion|edit|search|window|fold|mark|macro|diff|ex|terminal),
     and `level` (beginner|intermediate|advanced) are required fields
   - Optional `ambient = false` (#110): excludes the entry from
     `graph.find_best()`'s candidate pool (both the idle picker and `:Tobira`
     manual). Reserved for reactive-only suggestions whose own usage count can
     never be incremented by any tracking path — see the `<C-\><C-n>` entry's
     comment in `commands.lua` and `commands_spec.lua`'s "reactive-only ambient
     exclusion" tests for the full reasoning and the narrow scope of this flag.
   - The `terminal` category also gets two other carve-outs keyed off
     `suggestion.category` rather than a per-entry flag: `ui/float.lua`'s
     `auto_close_duration()` gives it a longer on-screen window (#166), and
     `core/suggest.lua`'s `bypasses_cooldown()` exempts it from
     `suggestion_cooldown` entirely (#166 follow-up) — both because this
     category's trigger condition means the user is, by definition, still
     actively stuck at the exact moment it fires, unlike every other
     category's idle/paused audience. A future category sharing that same
     "fires only while the user is genuinely mid-struggle" property is a
     candidate for the same two carve-outs; anything else should not reach
     for either.
2. **Write tests first** (see `tests/CLAUDE.md`)
   - `track = true` → add a tracking smoke test to `logger_spec.lua`
   - New normal-mode pattern → add a unit test to `patterns_spec.lua`
   - New insert-mode pattern → add a unit test to `patterns_insert_spec.lua` (#99)
   - New cmdline (Ex-command) pattern → add a unit test to `patterns_cmdline_spec.lua` (#57)
   - New terminal-mode pattern → add a unit test to `patterns_terminal_spec.lua` (#110)
3. Add display strings to both `locales/en.lua` and `locales/ja.lua` if needed
4. Pass CI — `graph.lua`, `skills.lua`, and `logger.lua` update themselves automatically

## Existing data protection

tobira accumulates `usage.json` over months. Data loss resets suggestion accuracy to zero.
Never write code that silently destroys existing entries.

**When changing the data format**, implement migration inside `logger.lua`'s `load()`:

```lua
-- ✅ idempotent migration on load
local function migrate_entry(entry)
  if not entry.sessions then
    entry.sessions = entry.adopted == true and { 10 } or {}
  end
  entry.adopted = nil  -- remove obsolete field after reading it
  return entry
end

-- ❌ assumes new format; crashes on old data
usage[cmd].sessions[1]  -- sessions may be nil for users upgrading
```

**Extension checklist:**
- [ ] Does this change `usage.json`'s key structure? → add migration to `migrate_entry()`
- [ ] Does this add a new field? → update every site that creates a default entry
- [ ] Does this change `reset()`? → confirm `reset()` → `setup()` → `get()` still works
- [ ] Does this rename a command key string? → old counts are lost; add a migration path

**Patterns that corrupt data (prohibited):**

```lua
-- ❌ nil indexing when usage[cmd] has never been written
usage[cmd].count = usage[cmd].count + 1

-- ❌ nil inserted into sessions array
table.insert(usage[cmd].sessions, nil)

-- ❌ reset() writes to disk — destroys real data during tests
function M.reset()
  usage = {}
  save()  -- never call save() inside reset()
end
```

## Coding conventions

- **Formatter:** stylua — `indent_type = Spaces`, `indent_width = 2`, `column_width = 120`,
  `quote_style = AutoPreferSingle`
- **Linter:** selene with `std = "vim"`
- **Commits:** Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`)
- Module state is always module-local. No global variables.
- `plugin/tobira.lua` must `require()` inside callbacks, never at the top of the file.
- `augroup` calls always use `clear = true` to prevent duplicate registration.
