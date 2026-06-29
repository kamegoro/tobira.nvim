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
  [';'] = { requires = 'f', track = true, category = 'motion', level = 'beginner' },
  [','] = { requires = ';', track = true, category = 'motion', level = 'intermediate' },

  -- ── dw → insert ───────────────────────────────────────────────────────────
  ['cw'] = { requires = 'dw', track = false, category = 'edit', level = 'beginner' },
  ['ciw'] = { requires = 'dw', track = false, category = 'edit', level = 'intermediate' },

  -- ── u repeat → redo ───────────────────────────────────────────────────────
  ['<C-r>'] = { requires = 'u', track = false, category = 'edit', level = 'beginner' },

  -- ── dd then p → swap lines ────────────────────────────────────────────────
  ['ddp'] = { requires = 'dd', track = false, category = 'edit', level = 'intermediate' },

  -- ── j repeat → count prefix ───────────────────────────────────────────────
  ['{n}j'] = { requires = 'j', track = false, category = 'motion', level = 'intermediate' },

  -- ── 0 then w → ^ ──────────────────────────────────────────────────────────
  ['^'] = { requires = '0', track = false, category = 'motion', level = 'beginner' },

  -- ── n repeat after search → cgn ───────────────────────────────────────────
  ['cgn'] = { requires = 'n', track = false, category = 'search', level = 'advanced' },

  -- ── cw → . (dot repeat) ───────────────────────────────────────────────────
  ['.'] = { requires = 'cw', track = true, category = 'edit', level = 'intermediate' },

  -- ── a → A, o → O (insert continuations) ──────────────────────────────────
  ['A'] = { requires = 'a', track = true, category = 'edit', level = 'beginner' },
  ['O'] = { requires = 'o', track = true, category = 'edit', level = 'beginner' },

  -- ── x → D → C deletion chain ──────────────────────────────────────────────
  ['D'] = { requires = 'x', track = true, category = 'edit', level = 'beginner' },
  ['C'] = { requires = 'D', track = true, category = 'edit', level = 'intermediate' },

  -- ── * → gn → cgn search-and-change chain ─────────────────────────────────
  ['gn'] = { requires = '*', track = false, category = 'search', level = 'intermediate' },

  -- ── w → e word-end ────────────────────────────────────────────────────────
  ['e'] = { requires = 'w', track = true, category = 'motion', level = 'beginner' },

  -- ── i → I / a → A line-edge insert ───────────────────────────────────────
  ['I'] = { requires = 'i', track = true, category = 'edit', level = 'intermediate' },

  -- ── G → H → M → L screen navigation ──────────────────────────────────────
  ['H'] = { requires = 'G', track = true, category = 'motion', level = 'intermediate' },
  ['M'] = { requires = 'H', track = true, category = 'motion', level = 'intermediate' },
  ['L'] = { requires = 'M', track = true, category = 'motion', level = 'intermediate' },

  -- ── x repeat → {n}x count prefix ─────────────────────────────────────────
  -- Detected via x_repeat pattern; needs a registry entry so suggest.show
  -- can look it up in graph.suggestions (without this entry it silently no-ops).
  ['{n}x'] = { requires = 'x', track = false, category = 'edit', level = 'intermediate' },

  -- ── j → <C-d> → <C-u> half-page scroll ───────────────────────────────────
  ['<C-d>'] = { requires = 'j', track = false, category = 'motion', level = 'beginner' },
  ['<C-u>'] = { requires = '<C-d>', track = false, category = 'motion', level = 'beginner' },

  -- ── k repeat → count prefix ───────────────────────────────────────────────
  ['{n}k'] = { requires = 'k', track = false, category = 'motion', level = 'intermediate' },

  -- ── n → * search word under cursor ───────────────────────────────────────
  ['*'] = { requires = 'n', track = true, category = 'search', level = 'beginner' },

  -- ── * → <C-o> jump back in jumplist ──────────────────────────────────────
  ['<C-o>'] = { requires = '*', track = false, category = 'motion', level = 'intermediate' },

  -- ── p → P paste above ────────────────────────────────────────────────────
  ['P'] = { requires = 'p', track = true, category = 'edit', level = 'intermediate' },

  -- ── f → t stop-before-char chain ─────────────────────────────────────────
  ['t'] = { requires = 'f', track = true, category = 'motion', level = 'beginner' },
  ['T'] = { requires = 't', track = false, category = 'motion', level = 'intermediate' },

  -- ── <C-o> / <C-i> jumplist navigation ────────────────────────────────────
  ['<C-i>'] = { requires = '<C-o>', track = false, category = 'motion', level = 'beginner' },

  -- ── full-page scroll chain ────────────────────────────────────────────────
  ['<C-f>'] = { requires = '<C-d>', track = false, category = 'motion', level = 'intermediate' },
  ['<C-b>'] = { requires = '<C-u>', track = false, category = 'motion', level = 'intermediate' },

  -- ── j → } / { paragraph motions ──────────────────────────────────────────
  ['}'] = { requires = 'j', track = false, category = 'motion', level = 'intermediate' },
  ['{'] = { requires = '}', track = false, category = 'motion', level = 'intermediate' },

  -- ── j → zz / zt / zb screen centering ────────────────────────────────────
  ['zz'] = { requires = 'j', track = false, category = 'motion', level = 'beginner' },
  ['zt'] = { requires = 'zz', track = false, category = 'motion', level = 'intermediate' },
  ['zb'] = { requires = 'zz', track = false, category = 'motion', level = 'intermediate' },

  -- ── w / b → W / B WORD motions ───────────────────────────────────────────
  ['W'] = { requires = 'w', track = false, category = 'motion', level = 'intermediate' },
  ['B'] = { requires = 'b', track = false, category = 'motion', level = 'intermediate' },

  -- ── e → ge word-end backward ─────────────────────────────────────────────
  ['ge'] = { requires = 'e', track = false, category = 'motion', level = 'intermediate' },

  -- ── 0 → % bracket matching ───────────────────────────────────────────────
  ['%'] = { requires = '0', track = false, category = 'motion', level = 'intermediate' },

  -- ── x → r / s single-char edit shortcuts ─────────────────────────────────
  ['r'] = { requires = 'x', track = true, category = 'edit', level = 'beginner' },
  ['s'] = { requires = 'x', track = true, category = 'edit', level = 'beginner' },

  -- ── dd → cc change-line / J join-lines ───────────────────────────────────
  ['cc'] = { requires = 'dd', track = false, category = 'edit', level = 'beginner' },
  ['J'] = { requires = 'dd', track = true, category = 'edit', level = 'intermediate' },

  -- ── x → ~ case toggle ────────────────────────────────────────────────────
  ['~'] = { requires = 'x', track = true, category = 'edit', level = 'intermediate' },

  -- ── x → <C-a> / <C-x> number increment / decrement ──────────────────────
  ['<C-a>'] = { requires = 'x', track = false, category = 'edit', level = 'intermediate' },
  ['<C-x>'] = { requires = '<C-a>', track = false, category = 'edit', level = 'intermediate' },

  -- ── v → V → <C-v> visual mode chain ─────────────────────────────────────
  ['V'] = { requires = 'v', track = true, category = 'edit', level = 'beginner' },
  ['<C-v>'] = { requires = 'V', track = false, category = 'edit', level = 'intermediate' },

  -- ── cw → yiw yank text object ────────────────────────────────────────────
  ['yiw'] = { requires = 'cw', track = false, category = 'edit', level = 'intermediate' },

  -- ── . → q macros ─────────────────────────────────────────────────────────
  ['q'] = { requires = '.', track = false, category = 'edit', level = 'advanced' },

  -- ── n → N backward search / * → # backward word search ──────────────────
  ['N'] = { requires = 'n', track = true, category = 'search', level = 'beginner' },
  ['#'] = { requires = '*', track = true, category = 'search', level = 'beginner' },
}

return M
