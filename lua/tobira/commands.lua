-- Master registry of teachable commands.
-- Adding a command here automatically wires it into:
--   graph.lua   → suggestions table (from requires)
--   skills.lua  → progress tree (from category)
--   logger.lua  → compound-operator tracking (compound = true entries)
--
-- Display strings (title / body / example) live in locales/en.lua and
-- locales/ja.lua under the 'suggestions' key, keyed by the same command name.
--
-- To add a new suggestion:
--   1. Add a compound entry here if the trigger is multi-char (e.g. 'dw', 'dd')
--   2. Add the suggestion entry with requires, category, and track = true if single-char
--   3. Add matching strings to locales/en.lua and locales/ja.lua .suggestions
--   4. Run tests — CI will catch missing locale entries, broken requires chains,
--      or missing category fields

local M = {}

M.registry = {
  -- ── Compound operators ────────────────────────────────────────────────────
  -- Multi-char sequences (operator + motion) that act as prerequisites.
  -- Tracked via seq.last_op change detection in logger.lua.
  ['dw'] = { compound = true },
  ['dd'] = { compound = true },

  -- ── f / F repeat ──────────────────────────────────────────────────────────
  [';'] = { requires = 'f', track = true, category = 'motion' },
  [','] = { requires = ';', track = true, category = 'motion' },

  -- ── dw → insert ───────────────────────────────────────────────────────────
  ['cw'] = { requires = 'dw', track = false, category = 'edit' },
  ['ciw'] = { requires = 'dw', track = false, category = 'edit' },

  -- ── u repeat → redo ───────────────────────────────────────────────────────
  ['<C-r>'] = { requires = 'u', track = false, category = 'edit' },

  -- ── dd then p → swap lines ────────────────────────────────────────────────
  ['ddp'] = { requires = 'dd', track = false, category = 'edit' },

  -- ── j repeat → count prefix ───────────────────────────────────────────────
  ['{n}j'] = { requires = 'j', track = false, category = 'motion' },

  -- ── 0 then w → ^ ──────────────────────────────────────────────────────────
  ['^'] = { requires = '0', track = false, category = 'motion' },

  -- ── n repeat after search → cgn ───────────────────────────────────────────
  ['cgn'] = { requires = 'n', track = false, category = 'search' },

  -- ── cw → . (dot repeat) ───────────────────────────────────────────────────
  ['.'] = { requires = 'cw', track = true, category = 'edit' },

  -- ── a → A, o → O (insert continuations) ──────────────────────────────────
  ['A'] = { requires = 'a', track = true, category = 'edit' },
  ['O'] = { requires = 'o', track = true, category = 'edit' },

  -- ── x → D → C deletion chain ──────────────────────────────────────────────
  ['D'] = { requires = 'x', track = true, category = 'edit' },
  ['C'] = { requires = 'D', track = true, category = 'edit' },

  -- ── * → gn → cgn search-and-change chain ─────────────────────────────────
  ['gn'] = { requires = '*', track = false, category = 'search' },

  -- ── w → e word-end ────────────────────────────────────────────────────────
  ['e'] = { requires = 'w', track = true, category = 'motion' },

  -- ── i → I / a → A line-edge insert ───────────────────────────────────────
  ['I'] = { requires = 'i', track = true, category = 'edit' },

  -- ── G → H → M → L screen navigation ──────────────────────────────────────
  ['H'] = { requires = 'G', track = true, category = 'motion' },
  ['M'] = { requires = 'H', track = true, category = 'motion' },
  ['L'] = { requires = 'M', track = true, category = 'motion' },

  -- ── x repeat → {n}x count prefix ─────────────────────────────────────────
  -- Detected via x_repeat pattern; needs a registry entry so suggest.show
  -- can look it up in graph.suggestions (without this entry it silently no-ops).
  ['{n}x'] = { requires = 'x', track = false, category = 'edit' },

  -- ── j → <C-d> → <C-u> half-page scroll ───────────────────────────────────
  ['<C-d>'] = { requires = 'j', track = false, category = 'motion' },
  ['<C-u>'] = { requires = '<C-d>', track = false, category = 'motion' },
}

return M
