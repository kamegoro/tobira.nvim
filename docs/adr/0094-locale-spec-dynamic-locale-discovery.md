# locale_spec discovers locale files by directory listing instead of a hardcoded name list

## Context

Early versions of the sync guard hand-picked specific keys to check per locale, and
would have needed a hardcoded `{'ja'}` (or similar) list extended by hand every time
a new locale file landed — an easy thing to forget, and one that had already caused
a locale to silently drift out of sync mid-refactor (#73's French-locale review).
A hardcoded list also means the check only ever covers whatever keys someone
remembered to add a test for, not the whole locale table.

## Decision

`discover_locale_names()` reads `lua/tobira/locales/` directly (`vim.fn.readdir`)
and treats every `*.lua` file other than `en.lua` as a locale to check, with a
sanity test asserting discovery itself still finds `ja.lua`. Each discovered locale
is then diffed against `en.lua` **recursively and completely** (including
`suggestions` and `float.reasons`, not just the older hand-picked sections below),
via `assert_strings_match`.

## Consequences

- A new locale file needs zero changes to this spec to be covered — dropping in
  `fr.lua` is enough for the sync guard to start checking it on the very next run.
- The recursive check only catches missing or empty strings, not
  wrong/mistranslated text — a locale can pass this guard while still reading badly
  in-context, so it's a structural guard, not a translation-quality one.
