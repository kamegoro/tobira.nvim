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
  -- Tracked in logger.lua via seq.op_completed, set by patterns.lua the
  -- moment seq.last_op is freshly assigned (see patterns.lua for why this
  -- is not a before/after value comparison on seq.last_op).
  ['dw'] = { compound = true },
  ['dd'] = { compound = true },

  -- ── f / F repeat ──────────────────────────────────────────────────────────
  [';'] = { requires = 'f', track = true, category = 'motion', level = 'beginner' },
  [','] = { requires = ';', track = true, category = 'motion', level = 'intermediate' },

  -- ── dw → insert ───────────────────────────────────────────────────────────
  ['cw'] = { requires = 'dw', track = false, category = 'edit', level = 'beginner' },
  ['ciw'] = { requires = 'dw', track = false, category = 'edit', level = 'intermediate' },

  -- ── u repeat → redo ───────────────────────────────────────────────────────
  ['<C-r>'] = { requires = 'u', track = true, category = 'edit', level = 'beginner' },

  -- ── dd then p → swap lines ────────────────────────────────────────────────
  ['ddp'] = { requires = 'dd', track = false, category = 'edit', level = 'intermediate' },

  -- ── j repeat → count prefix ───────────────────────────────────────────────
  ['{n}j'] = { requires = 'j', track = false, category = 'motion', level = 'intermediate' },

  -- ── 0 then w → ^ ──────────────────────────────────────────────────────────
  ['^'] = { requires = '0', track = true, category = 'motion', level = 'beginner' },

  -- ── n repeat after search → cgn ───────────────────────────────────────────
  ['cgn'] = { requires = 'n', track = false, category = 'search', level = 'advanced' },

  -- ── cw → . (dot repeat) ───────────────────────────────────────────────────
  ['.'] = { requires = 'cw', track = true, category = 'edit', level = 'intermediate' },

  -- ── a → A, o → O (insert continuations) ──────────────────────────────────
  ['A'] = { requires = 'a', track = true, category = 'edit', level = 'beginner' },
  ['O'] = { requires = 'o', track = true, category = 'edit', level = 'beginner' },

  -- ── insert-mode inefficiency ─────────────────────────────────────────────
  -- Insert-mode <C-w> (delete word before cursor) — distinct from the
  -- normal-mode <C-w> window-command prefix, which is the exact same raw
  -- byte. track = false here on purpose: build_track_table() in logger.lua
  -- would otherwise add this byte to the generic, mode-unaware TRACK table
  -- and count the normal-mode window prefix as if it were this command.
  -- Counted explicitly instead, only from inside handle_insert_key() (mode
  -- cache confirms insert mode first) — see logger.lua's INSERT_SPECIAL.
  ['<C-w>'] = { requires = 'i', track = false, category = 'edit', level = 'beginner' },

  -- ── x → D → C deletion chain ──────────────────────────────────────────────
  ['D'] = { requires = 'x', track = true, category = 'edit', level = 'beginner' },
  ['C'] = { requires = 'D', track = true, category = 'edit', level = 'intermediate' },

  -- ── * → gn → cgn search-and-change chain ─────────────────────────────────
  ['gn'] = { requires = '*', track = false, category = 'search', level = 'intermediate' },

  -- ── w → e word-end ────────────────────────────────────────────────────────
  ['e'] = { requires = 'w', track = true, category = 'motion', level = 'beginner' },

  -- ── i → I / a → A line-edge insert ───────────────────────────────────────
  ['I'] = { requires = 'i', track = true, category = 'edit', level = 'intermediate' },

  -- ── 0 → i → gI: true column 1, ignoring indentation ──────────────────────
  ['gI'] = { requires = 'I', track = false, category = 'edit', level = 'intermediate' },

  -- ── G → H → M → L screen navigation ──────────────────────────────────────
  ['H'] = { requires = 'G', track = true, category = 'motion', level = 'intermediate' },
  ['M'] = { requires = 'H', track = true, category = 'motion', level = 'intermediate' },
  ['L'] = { requires = 'M', track = true, category = 'motion', level = 'intermediate' },

  -- ── x repeat → {n}x count prefix ─────────────────────────────────────────
  -- Detected via x_repeat pattern; needs a registry entry so suggest.show
  -- can look it up in graph.suggestions (without this entry it silently no-ops).
  ['{n}x'] = { requires = 'x', track = false, category = 'edit', level = 'intermediate' },

  -- ── j → <C-d> → <C-u> half-page scroll ───────────────────────────────────
  ['<C-d>'] = { requires = 'j', track = true, category = 'motion', level = 'beginner' },
  ['<C-u>'] = { requires = '<C-d>', track = true, category = 'motion', level = 'beginner' },

  -- ── k repeat → count prefix ───────────────────────────────────────────────
  ['{n}k'] = { requires = 'k', track = false, category = 'motion', level = 'intermediate' },

  -- ── n → * search word under cursor ───────────────────────────────────────
  ['*'] = { requires = 'n', track = true, category = 'search', level = 'beginner' },

  -- ── * → <C-o> jump back in jumplist ──────────────────────────────────────
  ['<C-o>'] = { requires = '*', track = true, category = 'motion', level = 'intermediate' },

  -- ── p → P paste above ────────────────────────────────────────────────────
  ['P'] = { requires = 'p', track = true, category = 'edit', level = 'intermediate' },

  -- ── f → t stop-before-char chain ─────────────────────────────────────────
  ['t'] = { requires = 'f', track = true, category = 'motion', level = 'beginner' },
  ['T'] = { requires = 't', track = true, category = 'motion', level = 'intermediate' },

  -- ── <C-o> / <C-i> jumplist navigation ────────────────────────────────────
  ['<C-i>'] = { requires = '<C-o>', track = true, category = 'motion', level = 'beginner' },

  -- ── full-page scroll chain ────────────────────────────────────────────────
  ['<C-f>'] = { requires = '<C-d>', track = true, category = 'motion', level = 'intermediate' },
  ['<C-b>'] = { requires = '<C-u>', track = true, category = 'motion', level = 'intermediate' },

  -- ── j → } / { paragraph motions ──────────────────────────────────────────
  ['}'] = { requires = 'j', track = true, category = 'motion', level = 'intermediate' },
  ['{'] = { requires = '}', track = true, category = 'motion', level = 'intermediate' },

  -- ── j → zz / zt / zb screen centering ────────────────────────────────────
  ['zz'] = { requires = 'j', track = false, category = 'motion', level = 'beginner' },
  ['zt'] = { requires = 'zz', track = false, category = 'motion', level = 'intermediate' },
  ['zb'] = { requires = 'zz', track = false, category = 'motion', level = 'intermediate' },

  -- ── w / b → W / B WORD motions ───────────────────────────────────────────
  ['W'] = { requires = 'w', track = true, category = 'motion', level = 'intermediate' },
  ['B'] = { requires = 'b', track = true, category = 'motion', level = 'intermediate' },

  -- ── e → ge word-end backward ─────────────────────────────────────────────
  ['ge'] = { requires = 'e', track = false, category = 'motion', level = 'intermediate' },

  -- ── 0 → % bracket matching ───────────────────────────────────────────────
  ['%'] = { requires = '0', track = true, category = 'motion', level = 'intermediate' },

  -- ── x → r / s single-char edit shortcuts ─────────────────────────────────
  ['r'] = { requires = 'x', track = true, category = 'edit', level = 'beginner' },
  ['s'] = { requires = 'x', track = true, category = 'edit', level = 'beginner' },

  -- ── dd → cc change-line / J join-lines ───────────────────────────────────
  ['cc'] = { requires = 'dd', track = false, category = 'edit', level = 'beginner' },
  ['J'] = { requires = 'dd', track = true, category = 'edit', level = 'intermediate' },

  -- ── x → ~ case toggle ────────────────────────────────────────────────────
  ['~'] = { requires = 'x', track = true, category = 'edit', level = 'intermediate' },

  -- ── x → <C-a> / <C-x> number increment / decrement ──────────────────────
  ['<C-a>'] = { requires = 'x', track = true, category = 'edit', level = 'intermediate' },
  ['<C-x>'] = { requires = '<C-a>', track = true, category = 'edit', level = 'intermediate' },

  -- ── <C-a> streak → g<C-a> visual-block sequential increment ─────────────
  -- Detected via ca_run (patterns.lua): <C-a> → j/k → <C-a> repeated 3+
  -- times. track = false: like the other g-prefixed compounds (gg, gu, …),
  -- there is no pending_g dispatch entry recording literal g<C-a> keypresses.
  ['g<C-a>'] = { requires = '<C-a>', track = false, category = 'edit', level = 'advanced' },

  -- ── v → V → <C-v> visual mode chain ─────────────────────────────────────
  ['V'] = { requires = 'v', track = true, category = 'edit', level = 'beginner' },
  ['<C-v>'] = { requires = 'V', track = true, category = 'edit', level = 'intermediate' },

  -- ── cw → yiw yank text object ────────────────────────────────────────────
  ['yiw'] = { requires = 'cw', track = false, category = 'edit', level = 'intermediate' },

  -- ── . → q macros ─────────────────────────────────────────────────────────
  ['q'] = { requires = '.', track = true, category = 'macro', level = 'beginner' },

  -- ── n → N backward search / * → # backward word search ──────────────────
  ['N'] = { requires = 'n', track = true, category = 'search', level = 'beginner' },
  ['#'] = { requires = '*', track = true, category = 'search', level = 'beginner' },

  -- ── G → gg first line ─────────────────────────────────────────────────────
  ['gg'] = { requires = 'G', track = false, category = 'motion', level = 'beginner' },

  -- ── wrapped-line visual movement ──────────────────────────────────────────
  ['gj'] = { requires = 'j', track = false, category = 'motion', level = 'intermediate' },
  ['gk'] = { requires = 'k', track = false, category = 'motion', level = 'intermediate' },

  -- ── line-by-line scrolling ────────────────────────────────────────────────
  ['<C-e>'] = { requires = 'zz', track = true, category = 'motion', level = 'intermediate' },
  ['<C-y>'] = { requires = '<C-e>', track = true, category = 'motion', level = 'intermediate' },

  -- ── change list navigation ────────────────────────────────────────────────
  ['g;'] = { requires = '<C-o>', track = false, category = 'motion', level = 'intermediate' },
  ['g,'] = { requires = 'g;', track = false, category = 'motion', level = 'intermediate' },

  -- ── return to last insert / jump positions ────────────────────────────────
  ['gi'] = { requires = 'i', track = false, category = 'motion', level = 'intermediate' },
  ['<C-^>'] = { requires = '<C-o>', track = true, category = 'motion', level = 'intermediate' },

  -- ── marks ─────────────────────────────────────────────────────────────────
  ["''"] = { requires = '<C-o>', track = false, category = 'mark', level = 'beginner' },
  ["'."] = { requires = "''", track = false, category = 'mark', level = 'beginner' },
  ["'^"] = { requires = "'.", track = false, category = 'mark', level = 'intermediate' },
  ['ma'] = { requires = 'gd', track = false, category = 'mark', level = 'intermediate' },
  ["'a"] = { requires = 'ma', track = false, category = 'mark', level = 'intermediate' },

  -- ── definition / file navigation ─────────────────────────────────────────
  ['gd'] = { requires = '*', track = false, category = 'motion', level = 'intermediate' },
  ['gf'] = { requires = 'gd', track = false, category = 'motion', level = 'intermediate' },

  -- ── gv reselect last visual ───────────────────────────────────────────────
  -- Also fired directly by v_repeat (patterns.lua, #55): v tapped and
  -- immediately escaped 3 times in a row, independent of this entry's
  -- `requires` graph promotion path.
  ['gv'] = { requires = 'V', track = false, category = 'motion', level = 'intermediate' },

  -- ── ge → gE WORD-end backward ─────────────────────────────────────────────
  ['gE'] = { requires = 'ge', track = false, category = 'motion', level = 'intermediate' },

  -- ── fold commands ─────────────────────────────────────────────────────────
  ['za'] = { requires = 'zz', track = false, category = 'fold', level = 'beginner' },
  ['zo'] = { requires = 'za', track = false, category = 'fold', level = 'intermediate' },
  ['zc'] = { requires = 'za', track = false, category = 'fold', level = 'intermediate' },
  ['zM'] = { requires = 'za', track = false, category = 'fold', level = 'intermediate' },
  ['zR'] = { requires = 'zM', track = false, category = 'fold', level = 'intermediate' },
  ['zf'] = { requires = 'zc', track = false, category = 'fold', level = 'advanced' },

  -- ── x → X delete before cursor ───────────────────────────────────────────
  ['X'] = { requires = 'x', track = true, category = 'edit', level = 'intermediate' },

  -- ── r → R replace mode ───────────────────────────────────────────────────
  ['R'] = { requires = 'r', track = true, category = 'edit', level = 'advanced' },

  -- ── p → Y yank to end of line ─────────────────────────────────────────────
  ['Y'] = { requires = 'p', track = true, category = 'edit', level = 'beginner' },

  -- ── cc → >> / << / == indent operators ────────────────────────────────────
  ['>>'] = { requires = 'cc', track = false, category = 'edit', level = 'intermediate' },
  ['<<'] = { requires = '>>', track = false, category = 'edit', level = 'intermediate' },
  ['=='] = { requires = '>>', track = false, category = 'edit', level = 'intermediate' },

  -- ── ~ → gu / gU / g~ case operators ──────────────────────────────────────
  ['gu'] = { requires = '~', track = false, category = 'edit', level = 'intermediate' },
  ['gU'] = { requires = 'gu', track = false, category = 'edit', level = 'intermediate' },
  ['g~'] = { requires = '~', track = false, category = 'edit', level = 'intermediate' },

  -- ── . → gq format text ────────────────────────────────────────────────────
  ['gq'] = { requires = '.', track = false, category = 'edit', level = 'advanced' },

  -- ── gq → gw format without moving cursor ─────────────────────────────────
  ['gw'] = { requires = 'gq', track = false, category = 'edit', level = 'advanced' },

  -- ── J → gJ join without space ─────────────────────────────────────────────
  ['gJ'] = { requires = 'J', track = false, category = 'edit', level = 'advanced' },

  -- ── q → @@ repeat last macro ──────────────────────────────────────────────
  ['@@'] = { requires = 'q', track = false, category = 'macro', level = 'beginner' },
  ['@q'] = { requires = '@@', track = false, category = 'macro', level = 'intermediate' },

  -- ── ciw → text object chain ───────────────────────────────────────────────
  ['ci"'] = { requires = 'ciw', track = false, category = 'edit', level = 'intermediate' },
  ["ci'"] = { requires = 'ci"', track = false, category = 'edit', level = 'intermediate' },
  ['cib'] = { requires = 'ci"', track = false, category = 'edit', level = 'intermediate' },
  ['ciB'] = { requires = 'cib', track = false, category = 'edit', level = 'intermediate' },
  ['cit'] = { requires = 'cib', track = false, category = 'edit', level = 'advanced' },
  ['cip'] = { requires = 'ciw', track = false, category = 'edit', level = 'intermediate' },

  -- ── * → g* / # → g# partial word search ─────────────────────────────────
  ['g*'] = { requires = '*', track = false, category = 'search', level = 'intermediate' },
  ['g#'] = { requires = '#', track = false, category = 'search', level = 'intermediate' },

  -- ── $ end of line / g_ last non-blank ────────────────────────────────────────
  ['$'] = { requires = '^', track = true, category = 'motion', level = 'beginner' },
  ['g_'] = { requires = '$', track = false, category = 'motion', level = 'intermediate' },

  -- ── f → F backward find ───────────────────────────────────────────────────────
  ['F'] = { requires = 'f', track = true, category = 'motion', level = 'intermediate' },

  -- ── sentence motions ──────────────────────────────────────────────────────────
  ['('] = { requires = '{', track = true, category = 'motion', level = 'intermediate' },
  [')'] = { requires = '(', track = true, category = 'motion', level = 'intermediate' },

  -- ── section / function jumps ──────────────────────────────────────────────────
  ['[['] = { requires = 'gg', track = false, category = 'motion', level = 'intermediate' },
  [']]'] = { requires = 'G', track = false, category = 'motion', level = 'intermediate' },

  -- ── unmatched bracket navigation ─────────────────────────────────────────────
  ['[{'] = { requires = '%', track = false, category = 'motion', level = 'intermediate' },
  [']}'] = { requires = '%', track = false, category = 'motion', level = 'intermediate' },
  ['[('] = { requires = '[{', track = false, category = 'motion', level = 'intermediate' },
  ['])'] = { requires = ']}', track = false, category = 'motion', level = 'intermediate' },

  -- ── screen-line first char ────────────────────────────────────────────────────
  ['g0'] = { requires = 'gj', track = false, category = 'motion', level = 'intermediate' },

  -- ── code navigation ───────────────────────────────────────────────────────────
  ['gx'] = { requires = 'gf', track = false, category = 'motion', level = 'intermediate' },
  ['<C-]>'] = { requires = 'gf', track = true, category = 'motion', level = 'intermediate' },
  ['K'] = { requires = 'gd', track = true, category = 'motion', level = 'intermediate' },

  -- ── paste without losing cursor ───────────────────────────────────────────────
  ['gp'] = { requires = 'P', track = false, category = 'edit', level = 'intermediate' },
  ['gP'] = { requires = 'gp', track = false, category = 'edit', level = 'advanced' },

  -- ── repeat last ex command ────────────────────────────────────────────────────
  ['@:'] = { requires = '@@', track = false, category = 'macro', level = 'intermediate' },

  -- ── fold navigation ───────────────────────────────────────────────────────────
  ['zj'] = { requires = 'za', track = false, category = 'fold', level = 'intermediate' },
  ['zk'] = { requires = 'zj', track = false, category = 'fold', level = 'intermediate' },
  ['zd'] = { requires = 'zc', track = false, category = 'fold', level = 'advanced' },

  -- ── e → E WORD-end forward ────────────────────────────────────────────────────
  ['E'] = { requires = 'e', track = true, category = 'motion', level = 'intermediate' },

  -- ── u → U undo whole line ─────────────────────────────────────────────────────
  ['U'] = { requires = 'u', track = true, category = 'edit', level = 'intermediate' },

  -- ── q → ZZ / ZQ quit shortcuts ───────────────────────────────────────────────
  ['ZZ'] = { requires = 'q', track = false, category = 'edit', level = 'beginner' },
  ['ZQ'] = { requires = 'ZZ', track = false, category = 'edit', level = 'beginner' },

  -- ── q → q: command-line window ───────────────────────────────────────────────
  ['q:'] = { requires = 'q', track = false, category = 'macro', level = 'advanced' },

  -- ── 0 → | go to column ───────────────────────────────────────────────────────
  ['|'] = { requires = '0', track = true, category = 'motion', level = 'intermediate' },

  -- ── ^ → _ first non-blank (relative) ─────────────────────────────────────────
  ['_'] = { requires = '^', track = true, category = 'motion', level = 'intermediate' },

  -- ── insert-mode <C-o>: one normal command without leaving insert ───────────
  -- The '<C-o>' entry above already owns that raw keystroke for its
  -- normal-mode meaning ("jump back"). Insert-mode <C-o> is a *different*
  -- command bound to the identical physical key (runs one normal command,
  -- then returns to insert automatically) — since a Lua table can only hold
  -- one entry per key string, this uses a composite key, 'i_<C-o>', mirroring
  -- the '<C-w>' precedent above for the same collision shape.
  --
  -- The user never types 'i_<C-o>' — they always press the real <C-o>. This
  -- key exists so graph.lua can derive a second, independent M.suggestions
  -- entry from it; any UI rendering a registry key as "the key to press"
  -- must go through commands.display_key(cmd) below, which strips the 'i_'
  -- prefix back off.
  --
  -- Usage is counted explicitly from handle_insert_key() (mode cache
  -- confirms insert mode first) — see logger.lua's INSERT_SPECIAL. track =
  -- false for the same reason: the generic TRACK table must not also claim
  -- the raw <C-o> byte the normal-mode '<C-o>' entry already claims.
  ['i_<C-o>'] = { requires = 'i', track = false, category = 'edit', level = 'intermediate' },

  -- ── window management ─────────────────────────────────────────────────────
  ['<C-w>s'] = { requires = '<C-o>', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>v'] = { requires = '<C-w>s', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>w'] = { requires = '<C-w>s', track = false, category = 'window', level = 'beginner' },
  ['<C-w>h'] = { requires = '<C-w>w', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>j'] = { requires = '<C-w>w', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>k'] = { requires = '<C-w>w', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>l'] = { requires = '<C-w>w', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>q'] = { requires = '<C-w>w', track = false, category = 'window', level = 'intermediate' },
  ['<C-w>='] = { requires = '<C-w>w', track = false, category = 'window', level = 'intermediate' },
  -- ── <C-w>q / <C-w>c repeated → <C-w>o: close all other windows ─────────────
  ['<C-w>o'] = { requires = '<C-w>q', track = false, category = 'window', level = 'intermediate' },

  -- ── l → w / h → b basic word motion (suggested by l_repeat / h_repeat) ───────
  ['w'] = { requires = 'l', track = true, category = 'motion', level = 'beginner' },
  ['b'] = { requires = 'h', track = true, category = 'motion', level = 'beginner' },

  -- ── count prefix variants (suggested by run patterns) ────────────────────────
  ['{n}dd'] = { requires = 'dd', track = false, category = 'edit', level = 'intermediate' },
  ['{n}p'] = { requires = 'p', track = false, category = 'edit', level = 'intermediate' },
  ['{n}P'] = { requires = 'P', track = false, category = 'edit', level = 'intermediate' },
  ['{n}~'] = { requires = '~', track = false, category = 'edit', level = 'intermediate' },

  -- ── diw (suggested by v i w d) ───────────────────────────────────────────────
  ['diw'] = { requires = 'ciw', track = false, category = 'edit', level = 'intermediate' },

  -- ── c$ → C / d$ → D (end-of-line shortcuts) ──────────────────────────────────
  -- C and D already exist in registry; these require entries are in the main list.
  -- (no new entries needed — C requires D, D requires x, both are already there)

  -- ── yy → p (duplicate line) ──────────────────────────────────────────────────
  ['yyp'] = { requires = 'p', track = false, category = 'edit', level = 'beginner' },

  -- ── . × 3 / J × 3 count prefix variants ─────────────────────────────────────
  ['{n}.'] = { requires = '.', track = false, category = 'edit', level = 'intermediate' },
  ['{n}J'] = { requires = 'J', track = false, category = 'edit', level = 'intermediate' },

  -- ── >> × 3 / << × 3 indent count prefix ─────────────────────────────────────
  ['{n}>>'] = { requires = '>>', track = false, category = 'edit', level = 'intermediate' },
  ['{n}<<'] = { requires = '<<', track = false, category = 'edit', level = 'intermediate' },

  -- ── insert-mode completion ───────────────────────────────────────────────
  -- Detected by insert_completion_repeat (patterns_insert.lua): a fully
  -- retyped identifier of 6+ characters. category = 'edit' rather than a new
  -- top-level category — see lua/tobira/CLAUDE.md's category checklist, which
  -- documents the field as a closed 7-value enum, and the existing precedent
  -- of reusing existing categories for insert-mode patterns instead of inventing
  -- an "insert" one (insert_bs_repeat/insert_bounce → <C-w>/A are both
  -- 'edit' too). track = false: same reasoning as insert-mode <C-w> just
  -- above — <C-n> already has a normal-mode meaning (Vim's built-in
  -- down-motion), and build_track_table() can't tell those two meanings of
  -- the same raw byte apart. Counted explicitly instead, only from inside
  -- handle_insert_key() — see logger.lua's INSERT_SPECIAL.
  ['<C-n>'] = { requires = 'i', track = false, category = 'edit', level = 'beginner' },

  -- ── y → "+y system clipboard register ────────────────────────────────────
  -- track = false: "+y is a 3-key literal sequence ("+y), tracked as its own
  -- compound by patterns.lua's pending_clipboard_yank state, not by the
  -- generic operator grammar or a bare keystroke. Promotion into the
  -- suggestion pool is NOT gated by the usual "trigger count > 0" rule —
  -- graph.is_register_underused() applies a much stricter, purpose-built
  -- threshold instead (see find_best()'s special case for this cmd). category
  -- = 'mark': no dedicated "register" category exists in the taxonomy, and
  -- this is the closest existing bucket (registers/marks are grouped together
  -- in the project's own design notes — see CLAUDE.md's "advanced" scenario).
  ['"+y'] = { requires = 'y', track = false, category = 'mark', level = 'advanced' },
  -- ── diff mode: manual hunk navigation → ]c / [c ───────────────────────────────
  -- vim.wo.diff (a read-only window-local option) is read in logger.lua's
  -- handle_key and threaded into patterns.feed() as a plain parameter —
  -- patterns.lua itself stays vim.*-free per the module dependency rules in
  -- lua/tobira/CLAUDE.md. This gates the *existing* j_many/k_many thresholds
  -- (10 presses in a row) rather than adding new detection: while &diff is
  -- set, the same j/k-hammering that would otherwise suggest }/{ suggests
  -- ]c/[c instead, since jumping straight to the next/previous changed hunk
  -- beats paragraph motion while diffing. track = false: like most other
  -- multi-char suggestion-only entries (ddp, {n}j, ...), nothing else in the
  -- registry references ]c/[c via `requires`, so there's no count>=N
  -- threshold depending on these being tracked.
  [']c'] = { requires = 'j', track = false, category = 'diff', level = 'beginner' },
  ['[c'] = { requires = 'k', track = false, category = 'diff', level = 'beginner' },

  -- ── Ex commands ───────────────────────────────────────────────────────────
  -- Tracked via logger.lua's cmdline handler (patterns_cmdline.lua tokenizes
  -- the completed command line), not a keystroke or operator grammar — track
  -- = false so build_track_table() doesn't also treat 'ex:g'/'ex:norm' as
  -- literal keys to watch for.
  --
  -- ex_command = true makes graph.lua apply a stricter "never tried" offer
  -- gate instead of the generic mastery-level gate (see graph.find_best): a
  -- single :g or :norm already does the work of many keystrokes, so
  -- continuing to suggest either after even one try would read as ignoring
  -- feedback, unlike e.g. cw (fine to keep nudging until count reaches 100).
  --
  -- requires = 'n' for :g (repeated search-repeat is already doing by hand
  -- what :g/pattern/cmd does over every match at once); 'q' for :norm (same
  -- "already doing this manually" relationship to macro recording).
  ['ex:g'] = { requires = 'n', track = false, category = 'ex', level = 'advanced', ex_command = true },
  ['ex:norm'] = { requires = 'q', track = false, category = 'ex', level = 'advanced', ex_command = true },

  -- ── terminal mode: ineffective <Esc> → exit terminal mode ────────────────
  -- Detected reactively by patterns_terminal.lua while mode() == 't', with no
  -- tracked "you opened :terminal" prerequisite to require. `requires = 'i'`
  -- is a nominal anchor only, to satisfy commands_spec.lua's schema guard —
  -- the reactive path this pattern fires through (on_pattern → suggest.queue
  -- → do_show) never consults `requires` at all.
  --
  -- `ambient = false`: excludes this entry from graph.find_best()'s
  -- candidate pool (idle picker + :Tobira manual). Without it, find_best
  -- could surface "exit terminal mode" purely from bare `i` usage with no
  -- :terminal ever opened — actively confusing, since the suggestion body
  -- presupposes real terminal usage. Worse, this command's own usage count
  -- can never be incremented by anything, so its find_best score
  -- (trigger_count - 0) is always the best possible for any 'i'-triggered
  -- candidate — it would dominate ambient suggestions from `i` alone. This
  -- only makes sense as a direct reaction to terminal_esc_repeat actually
  -- firing, never as a proactive idle-time nudge.
  --
  -- Scoped narrowly to this one entry, not generalized to every `requires =
  -- 'i'` nominal anchor: the insert-mode '<C-w>' entry above has the same
  -- nominal-anchor shape, but its own count IS genuinely incremented and its
  -- suggestion body doesn't presuppose a prior event, so ambient surfacing is
  -- legitimate for it. No other entry shares this specific combination (count
  -- stuck at 0 forever + a context-presupposing body) — see
  -- commands_spec.lua's "reactive-only ambient exclusion" tests, which pin
  -- this down as an explicit, reviewable list rather than a silent rule.
  ['<C-\\><C-n>'] = { requires = 'i', track = false, category = 'terminal', level = 'beginner', ambient = false },

  -- ── repeated :substitute detection → & / g& ───────────────────────────────
  -- Detected reactively by patterns_cmdline.lua's track_substitute(): the
  -- identical :s/{pattern}/{replacement}/ body manually re-run on a 2nd
  -- distinct line fires '&'; a 3rd distinct line escalates to 'g&' instead of
  -- firing '&' again. See that module's header for the full parsing scope
  -- and exact-count firing rationale.
  --
  -- requires = 'n' for '&': mirrors 'cgn' above it in spirit — repeated
  -- search-match navigation without editing is the same "doing this by hand"
  -- precursor search-and-replace features build on. track = true: '&' is a
  -- single literal keystroke with its own real Vim meaning, so
  -- build_track_table() must count it like any other single-char command.
  ['&'] = { requires = 'n', track = true, category = 'edit', level = 'intermediate' },

  -- requires = '&': g& is the natural next step once & is known. track =
  -- false: a 2-char literal sequence with no pending-g dispatch entry
  -- recording it (same shape as 'gu'/'g~'/'gg', all track=false). Not marked
  -- ambient=false like '<C-\><C-n>': 'g&''s body is a generic, standalone
  -- "did you know" tip (same shape as 'cgn'/'ex:g') that reads sensibly even
  -- surfaced ambiently from '&' usage alone, unlike '<C-\><C-n>''s
  -- context-presupposing body and structurally-stuck-at-0 count.
  ['g&'] = { requires = '&', track = false, category = 'edit', level = 'advanced' },
}

-- Some registry keys are an internal composite, not the literal keystroke
-- the user presses — see the 'i_<C-o>' entry above for the full story of why
-- (a Lua table can only hold one value per key string, so two distinct
-- commands bound to the same physical key need two different registry
-- strings). UI code that renders a registry key as "the key to press"
-- (ui/guide.lua, ui/stats.lua, core/skills.lua) must go through this function
-- so the user sees the real keystroke, never the internal disambiguation
-- prefix. Ordinary registry keys, and non-registry keys (basic tracked keys
-- like 'j', compound ops like 'dd') pass through unchanged.
function M.display_key(cmd)
  return cmd:match('^i_(.+)$') or cmd
end

return M
