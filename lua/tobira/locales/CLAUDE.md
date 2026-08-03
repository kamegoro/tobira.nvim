# locales/ — CLAUDE.md

## All display strings belong in locale files

Hard-coding user-visible strings in UI modules is prohibited. Every string must be defined
in `en.lua` and every other locale file in this directory, then accessed through
`require('tobira.i18n').load()` in the UI module.

```lua
-- ✅ correct
local str = require('tobira.i18n').load()
push(str.progress.mastered_total:format(n, total))

-- ❌ prohibited
push('Next: ' .. cmd_name)
local label = lang == 'ja' and '次へ' or 'Next'  -- inline branching also prohibited
```

## Adding a new key

1. Add the key to `en.lua` **and every other locale file in this directory**
   (`ja.lua`, `de.lua`, `es.lua`, `fr.lua`, `zh.lua`) before writing any UI code that uses it.
2. Place it in the appropriate section (`guide`, `progress`, `notifications`, `stats`, `float`,
   `suggestions`), or create a new top-level key for a new module.
3. Run the test suite — `locale_spec.lua` fails if any locale file falls out of sync with
   `en.lua` (missing keys or orphaned keys, checked recursively and bidirectionally).

## Adding a new locale (e.g., `ko.lua`, `pt.lua`)

1. Copy `en.lua` as a starting point.
2. Translate all string **values**. Never translate key names.
3. No registration step needed — `i18n.lua` loads locales dynamically via
   `pcall(require, 'tobira.locales.' .. lang)`, so dropping the file in this directory is
   enough. (This file used to say "register the new locale in `i18n.lua`" — that hasn't been
   true since `i18n.lua` switched to the dynamic `pcall` lookup; don't go looking for a list
   to add your locale to.)
4. **Before opening a PR, diff your locale's keys against the current `en.lua`** — not
   whatever `en.lua` looked like when you started. This project's suggestion-notification and
   panel UIs have grown substantially since launch, and a locale branch left open for even a
   few days can drift dozens of keys behind `en.lua` (missing new keys entirely breaks
   whatever UI reads them; stale keys `en.lua` no longer has are just dead weight). A quick
   way to check:
   ```lua
   -- inside a headless nvim, or adapt into a one-off script
   local function collect_keys(tbl, prefix, out)
     for k, v in pairs(tbl) do
       local path = prefix == '' and tostring(k) or (prefix .. '.' .. tostring(k))
       if type(v) == 'table' then collect_keys(v, path, out) else out[path] = true end
     end
   end
   local en, other = dofile('lua/tobira/locales/en.lua'), dofile('lua/tobira/locales/<code>.lua')
   local en_keys, other_keys = {}, {}
   collect_keys(en, '', en_keys)
   collect_keys(other, '', other_keys)
   for k in pairs(en_keys) do if not other_keys[k] then print('missing: ' .. k) end end
   for k in pairs(other_keys) do if not en_keys[k] then print('stale: ' .. k) end end
   ```
5. No test-file changes needed. `locale_spec.lua` discovers every `*.lua` file in this
   directory (other than `en.lua`) at run time via `discover_locale_names()`
   (`vim.fn.readdir('lua/tobira/locales')`) and automatically checks each one recursively
   and bidirectionally against `en.lua` — both missing keys (`assert_strings_match`) and
   orphaned keys (`assert_no_orphan_keys`). Dropping a new locale file in this directory is
   enough for CI to start covering it on the very next run; no parallel `describe` block or
   any other registration step is required. See
   `docs/adr/0094-locale-spec-dynamic-locale-discovery.md` for why this replaced an earlier
   hardcoded-locale-list approach.
6. Update `README.md`'s `lang` config example comment to list the new locale.

## Standard locale-loading pattern

Locale loading is centralized in `lua/tobira/i18n.lua` — UI modules call it directly rather
than defining their own loader:

```lua
-- lua/tobira/i18n.lua
local M = {}

function M.load()
  local lang = require('tobira.core.config').values.lang
  local ok, loc = pcall(require, 'tobira.locales.' .. lang)
  return ok and loc or require('tobira.locales.en')
end

return M
```

```lua
-- in a UI module (e.g. ui/float.lua, ui/guide.lua, ui/progress.lua, ui/stats.lua)
local str = require('tobira.i18n').load()
-- or drill into a section directly, e.g. require('tobira.i18n').load().stats
```

## File structure

Each locale file returns a single table. Top-level keys are grouped by the module that uses them:

```
guide.title / guide.hint / guide.all_mastered / guide.pinned
progress.*
notifications.*
stats.*
float.*
suggestions.*  -- keyed by command name (e.g. suggestions['cw']), each entry holding
                -- title/body/example strings for that command's suggestion popup
```

Arrays with numeric keys are intentional and not checked by `locale_spec.lua`.
