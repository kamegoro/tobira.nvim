-- Master registry of teachable commands: adding an entry here wires it into
-- graph.lua (suggestions), skills.lua (progress tree), and logger.lua (compound
-- tracking). Display strings live in locales/en.lua and locales/ja.lua under
-- 'suggestions', keyed by the same command name.
-- See lua/tobira/CLAUDE.md's "How to add a command" checklist for the full steps.

local M = {}

M.registry = {
  -- ── Compound operators ────────────────────────────────────────────────────
  -- Multi-char operator+motion prerequisites. Tracked via seq.op_completed
  -- (patterns.lua), set the moment seq.last_op is freshly assigned.
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
  -- Insert-mode <C-w> (delete word before cursor) shares its raw byte with the
  -- normal-mode <C-w> window-command prefix. track = false; counted explicitly
  -- from handle_insert_key() instead (logger.lua's INSERT_SPECIAL) — see
  -- docs/adr/0008-composite-keys-for-dual-meaning-bytes.md for why.
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
  -- Reactive-only (x_repeat fires this directly) — see
  -- docs/adr/0012-reactive-only-direct-fire-entries.md.
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
  -- Reactive-only (ca_run fires this directly) — see
  -- docs/adr/0012-reactive-only-direct-fire-entries.md.
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
  -- Also reactive-only (v_repeat fires this directly, #55) — see
  -- docs/adr/0012-reactive-only-direct-fire-entries.md.
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

  -- ── ~ streak (word/line span) → g~iw / g~$ text-object-scoped toggle ──────
  -- Refines tilde_repeat once the streak plausibly spans a whole word/line —
  -- g~ (toggle) is used rather than gu/gU (fixed direction) because
  -- patterns.lua has no buffer-content visibility to know whether the
  -- original characters were upper- or lowercase. See
  -- docs/adr/0101-tilde-repeat-text-object-refinement.md.
  ['g~iw'] = { requires = 'g~', track = false, category = 'edit', level = 'advanced' },
  ['g~$'] = { requires = 'g~iw', track = false, category = 'edit', level = 'advanced' },

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

  -- ── ci" / ci' × 3 (direct, non-visual) → ya" / ya' (#53) ─────────────────
  -- Reactive-only (ci_dquote_repeat / ci_squote_repeat fire this directly) —
  -- see docs/adr/0012-reactive-only-direct-fire-entries.md.
  ['ya"'] = { requires = 'ci"', track = false, category = 'edit', level = 'intermediate' },
  ["ya'"] = { requires = "ci'", track = false, category = 'edit', level = 'intermediate' },

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
  -- Composite key: the '<C-o>' entry above already owns that raw keystroke for
  -- its normal-mode meaning. The user never types 'i_<C-o>' literally; UI code
  -- must render it via commands.display_key(cmd) below. Counted explicitly
  -- from handle_insert_key() (logger.lua's INSERT_SPECIAL), track = false —
  -- see docs/adr/0008-composite-keys-for-dual-meaning-bytes.md for why.
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
  -- retyped identifier of 6+ characters. category = 'edit': insert-mode
  -- patterns reuse existing categories rather than adding an "insert" one
  -- (same precedent as insert_bs_repeat/insert_bounce → <C-w>/A). <C-n>
  -- shares its raw byte with the normal-mode down-motion; track = false,
  -- counted explicitly from handle_insert_key() (logger.lua's
  -- INSERT_SPECIAL) — see docs/adr/0008-composite-keys-for-dual-meaning-bytes.md.
  ['<C-n>'] = { requires = 'i', track = false, category = 'edit', level = 'beginner' },

  -- ── y → "+y system clipboard register ────────────────────────────────────
  -- track = false: tracked as its own 3-key compound by patterns.lua's
  -- pending_clipboard_yank state. Promotion bypasses the generic trigger-count
  -- rule (graph.is_register_underused() applies its own threshold instead) —
  -- see docs/adr/0009-register-underuse-bypasses-trigger-count.md.
  ['"+y'] = { requires = 'y', track = false, category = 'mark', level = 'advanced' },
  -- ── diff mode: manual hunk navigation → ]c / [c ───────────────────────────────
  -- While &diff is set, gates the existing j_many/k_many thresholds to
  -- suggest ]c/[c instead of }/{ — see
  -- docs/adr/0011-diff-mode-reuses-existing-thresholds.md.
  [']c'] = { requires = 'j', track = false, category = 'diff', level = 'beginner' },
  ['[c'] = { requires = 'k', track = false, category = 'diff', level = 'beginner' },
  -- ── diff mode: manual retyping after a hunk jump → do / dp ─────────────────
  -- Reactive-only: fires when insert-mode editing immediately follows a
  -- ]c/[c jump while &diff is set — see
  -- docs/adr/0099-diff-obtain-put-after-hunk-jump.md.
  ['do'] = { requires = ']c', track = false, category = 'diff', level = 'intermediate' },
  ['dp'] = { requires = '[c', track = false, category = 'diff', level = 'intermediate' },

  -- ── Ex commands ───────────────────────────────────────────────────────────
  -- Tracked via logger.lua's cmdline handler (patterns_cmdline.lua), not a
  -- keystroke — track = false. ex_command = true applies a stricter
  -- "never tried" gate instead of the generic mastery-level gate — see
  -- docs/adr/0010-ex-command-never-tried-gate.md.
  ['ex:g'] = { requires = 'n', track = false, category = 'ex', level = 'advanced', ex_command = true },
  ['ex:norm'] = { requires = 'q', track = false, category = 'ex', level = 'advanced', ex_command = true },

  -- ── terminal mode: ineffective <Esc> → exit terminal mode ────────────────
  -- Detected reactively by patterns_terminal.lua while mode() == 't'.
  -- `requires = 'i'` is a nominal anchor only (satisfies the schema guard).
  -- `ambient = false` excludes this entry from graph.find_best()'s candidate
  -- pool — see docs/adr/0007-reactive-only-ambient-exclusion.md for why.
  ['<C-\\><C-n>'] = { requires = 'i', track = false, category = 'terminal', level = 'beginner', ambient = false },

  -- ── repeated :substitute detection → & / g& ───────────────────────────────
  -- Detected reactively by patterns_cmdline.lua's track_substitute() — see
  -- docs/adr/0013-substitute-repeat-ampersand-escalation.md for the escalation
  -- rationale and why 'g&' is deliberately not ambient = false.
  ['&'] = { requires = 'n', track = true, category = 'edit', level = 'intermediate' },
  ['g&'] = { requires = '&', track = false, category = 'edit', level = 'advanced' },
}

-- Strips the 'i_' composite-key prefix (see the 'i_<C-o>' entry above) so the
-- user always sees the real keystroke, never the internal disambiguation
-- string. Any UI rendering a registry key as "the key to press" (ui/guide.lua,
-- ui/stats.lua, core/skills.lua) must go through this function. Ordinary and
-- non-registry keys pass through unchanged. See
-- docs/adr/0008-composite-keys-for-dual-meaning-bytes.md for why this exists.
function M.display_key(cmd)
  return cmd:match('^i_(.+)$') or cmd
end

return M
