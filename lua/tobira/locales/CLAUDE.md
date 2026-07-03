# locales/ — CLAUDE.md

## All display strings belong in locale files

Hard-coding user-visible strings in UI modules is prohibited. Every string must be defined
in `en.lua` and `ja.lua`, then accessed through `load_strings()` in the UI module.

```lua
-- ✅ correct
local str = load_strings()
push(str.progress.mastered_total:format(n, total))

-- ❌ prohibited
push('Next: ' .. cmd_name)
local label = lang == 'ja' and '次へ' or 'Next'  -- inline branching also prohibited
```

## Adding a new key

1. Add the key to **both** `en.lua` and `ja.lua` before writing any UI code that uses it.
2. Place it in the appropriate section (`guide`, `progress`, `notifications`, `stats`, `float`),
   or create a new top-level key for a new module.
3. Run the test suite — `locale_spec.lua` fails if the two files fall out of sync.

## Adding a new locale (e.g., `ko.lua`, `fr.lua`)

1. Copy `en.lua` as a starting point.
2. Translate all string **values**. Never translate key names.
3. Register the new locale in `lua/tobira/i18n.lua`.
4. `locale_spec.lua` currently guards only `en` / `ja` sync. If you want the new locale
   covered, add a parallel `describe` block in that file.

## Standard load_strings() pattern

```lua
local function load_strings()
  local lang = require('tobira.core.config').values.lang
  local ok, loc = pcall(require, 'tobira.locales.' .. lang)
  if not ok then loc = require('tobira.locales.en') end
  return loc  -- or loc.progress, loc.stats, etc.
end
```

## File structure

Each locale file returns a single table. Top-level keys are grouped by the module that uses them:

```
guide.title / guide.hint / guide.all_mastered / guide.pinned
progress.*
notifications.*
stats.*
float.*
```

Arrays with numeric keys are intentional and not checked by `locale_spec.lua`.
