-- Master registry of teachable commands.
-- Adding a command here automatically wires it into:
--   graph.lua   → suggestions table (from requires)
--   logger.lua  → compound-operator tracking (compound = true entries)
--
-- Display strings (title / body / example) live in locales/en.lua and
-- locales/ja.lua under the 'suggestions' key, keyed by the same command name.
--
-- To add a new suggestion:
--   1. Add a compound entry here if the trigger is multi-char (e.g. 'dw', 'dd')
--   2. Add the suggestion entry with requires (and track = true if single-char)
--   3. Add matching strings to locales/en.lua and locales/ja.lua .suggestions
--   4. Run tests — CI will catch missing locale entries or broken requires chains

local M = {}

M.registry = {
  -- ── Compound operators ────────────────────────────────────────────────────
  -- Multi-char sequences (operator + motion) that act as prerequisites.
  -- Tracked via seq.last_op change detection in logger.lua.
  ['dw'] = { compound = true },
  ['dd'] = { compound = true },

  -- ── f / F repeat ──────────────────────────────────────────────────────────
  [';'] = { requires = 'f', track = true },
  [','] = { requires = ';', track = true },

  -- ── dw → insert ───────────────────────────────────────────────────────────
  ['cw'] = { requires = 'dw', track = false },
  ['ciw'] = { requires = 'dw', track = false },

  -- ── u repeat → redo ───────────────────────────────────────────────────────
  ['<C-r>'] = { requires = 'u', track = false },

  -- ── dd then p → swap lines ────────────────────────────────────────────────
  ['ddp'] = { requires = 'dd', track = false },

  -- ── j repeat → count prefix ───────────────────────────────────────────────
  ['{n}j'] = { requires = 'j', track = false },

  -- ── 0 then w → ^ ──────────────────────────────────────────────────────────
  ['^'] = { requires = '0', track = false },

  -- ── n repeat after search → cgn ───────────────────────────────────────────
  ['cgn'] = { requires = 'n', track = false },

  -- ── cw → . (dot repeat) ───────────────────────────────────────────────────
  ['.'] = { requires = 'cw', track = true },

  -- ── a → A, o → O (insert continuations) ──────────────────────────────────
  ['A'] = { requires = 'a', track = true },
  ['O'] = { requires = 'o', track = true },

  -- ── x → D → C deletion chain ──────────────────────────────────────────────
  ['D'] = { requires = 'x', track = true },
  ['C'] = { requires = 'D', track = true },

  -- ── * → gn → cgn search-and-change chain ─────────────────────────────────
  ['gn'] = { requires = '*', track = false },

  -- ── w → e word-end ────────────────────────────────────────────────────────
  ['e'] = { requires = 'w', track = true },

  -- ── i → I / a → A line-edge insert ───────────────────────────────────────
  ['I'] = { requires = 'i', track = true },

  -- ── G → H → M → L screen navigation ──────────────────────────────────────
  ['H'] = { requires = 'G', track = true },
  ['M'] = { requires = 'H', track = true },
  ['L'] = { requires = 'M', track = true },

  -- ── x repeat → {n}x count prefix ─────────────────────────────────────────
  -- Detected via x_repeat pattern; needs a registry entry so suggest.show
  -- can look it up in graph.suggestions (without this entry it silently no-ops).
  ['{n}x'] = { requires = 'x', track = false },

  -- ── j → <C-d> → <C-u> half-page scroll ───────────────────────────────────
  ['<C-d>'] = { requires = 'j', track = false },
  ['<C-u>'] = { requires = '<C-d>', track = false },
}

return M
