local commands = require('tobira.commands')

-- The registry is the single source of truth for all teachable commands.
-- These tests act as a schema guard: a malformed entry fails CI before reaching users.

describe('the command registry', function()
  it('is not empty', function()
    local count = 0
    for _ in pairs(commands.registry) do
      count = count + 1
    end
    assert.is_true(count > 0)
  end)
end)

describe('every suggestion entry in the registry', function()
  it('declares a requires field', function()
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound then
        assert.is_string(entry.requires, cmd .. ': missing requires')
        assert.is_true(#entry.requires > 0, cmd .. ': empty requires')
      end
    end
  end)

  it('requires field points to a single char or another registry entry', function()
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.requires then
        local req = entry.requires
        local is_single_char = #req == 1
        local is_in_registry = commands.registry[req] ~= nil
        assert.is_true(
          is_single_char or is_in_registry,
          cmd .. ': requires "' .. req .. '" is neither a single char nor in the registry'
        )
      end
    end
  end)
end)

-- Display strings belong in locale files, not in commands.lua.
-- These tests act as a sync guard: adding a registry entry without locale strings fails CI.
describe('locale coverage', function()
  local en = require('tobira.locales.en')
  local ja = require('tobira.locales.ja')

  it('every suggestion in the registry has title / body / example in en.lua', function()
    local sug_loc = en.suggestions or {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound then
        local str = sug_loc[cmd]
        assert.is_not_nil(str, cmd .. ': missing entry in en.lua .suggestions')
        assert.is_string(str.title, cmd .. ': en.lua missing title')
        assert.is_true(#str.title > 0, cmd .. ': en.lua title is empty')
        assert.is_string(str.body, cmd .. ': en.lua missing body')
        assert.is_true(#str.body > 0, cmd .. ': en.lua body is empty')
        assert.is_string(str.example, cmd .. ': en.lua missing example')
        assert.is_true(#str.example > 0, cmd .. ': en.lua example is empty')
      end
    end
  end)

  it('every en.lua suggestion also has title and body in ja.lua', function()
    local en_sug = en.suggestions or {}
    local ja_sug = ja.suggestions or {}
    for cmd in pairs(en_sug) do
      local str = ja_sug[cmd]
      assert.is_not_nil(str, cmd .. ': missing entry in ja.lua .suggestions')
      assert.is_string(str.title, cmd .. ': ja.lua missing title')
      assert.is_true(#str.title > 0, cmd .. ': ja.lua title is empty')
      assert.is_string(str.body, cmd .. ': ja.lua missing body')
      assert.is_true(#str.body > 0, cmd .. ': ja.lua body is empty')
    end
  end)
end)

describe('every non-compound entry in the registry', function()
  it('has a category field (motion | edit | search | window | fold | mark | macro)', function()
    local valid = { motion = true, edit = true, search = true, window = true, fold = true, mark = true, macro = true }
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound then
        assert.is_not_nil(
          valid[entry.category],
          cmd .. ': missing or invalid category (got ' .. tostring(entry.category) .. ')'
        )
      end
    end
  end)

  it('has a level field (beginner | intermediate | advanced) on every suggestable entry', function()
    local valid_levels = { beginner = true, intermediate = true, advanced = true }
    for cmd, entry in pairs(commands.registry) do
      if entry.requires then
        assert.is_not_nil(entry.level, cmd .. ': missing level field')
        assert.is_true(valid_levels[entry.level] == true, cmd .. ': invalid level "' .. tostring(entry.level) .. '"')
      end
    end
  end)
end)

-- ── compound operators ────────────────────────────────────────────────────────

describe('compound operators', function()
  for _, cmd in ipairs({ 'dw', 'dd' }) do
    it(cmd .. ' is registered as a compound operator', function()
      assert.is_not_nil(commands.registry[cmd])
      assert.is_true(commands.registry[cmd].compound)
    end)
  end
end)

-- ── teaching chains: requires fields ─────────────────────────────────────────
-- One row per directed edge in the learning graph.
-- Format: { cmd, requires, description }

local chain_cases = {
  -- f/F search repetition
  { ';', 'f', 'f → ;: repeat last f-search' },
  { ',', ';', '; → ,: reverse f-repeat' },
  -- dw teaching chain
  { 'cw', 'dw', 'dw → cw: change word in one motion' },
  { 'ciw', 'dw', 'dw → ciw: change inner word' },
  -- u → redo
  { '<C-r>', 'u', 'u → <C-r>: redo last undone change' },
  -- dd → swap lines
  { 'ddp', 'dd', 'dd → ddp: swap current line with next' },
  -- j/k count prefix pair
  { '{n}j', 'j', 'j → {n}j: count-prefix line movement down' },
  { '{n}k', 'k', 'k → {n}k: count-prefix line movement up' },
  -- 0 → ^
  { '^', '0', '0 → ^: jump to first non-blank character' },
  -- cgn search-and-change
  { 'cgn', 'n', 'n → cgn: change next search match' },
  -- dot repeat
  { '.', 'cw', 'cw → .: repeat last change' },
  -- insert continuations
  { 'A', 'a', 'a → A: append at end of line' },
  { 'O', 'o', 'o → O: open new line above' },
  -- deletion chain
  { 'D', 'x', 'x → D: delete to end of line' },
  { 'C', 'D', 'D → C: change to end of line' },
  -- search chain
  { 'gn', '*', '* → gn: select next search match in visual' },
  { '*', 'n', 'n → *: search word under cursor' },
  { '<C-o>', '*', '* → <C-o>: jump back to previous position' },
  -- word end
  { 'e', 'w', 'w → e: move to end of word' },
  -- line-edge insert
  { 'I', 'i', 'i → I: insert at start of line' },
  -- screen navigation chain
  { 'H', 'G', 'G → H: jump to top of screen' },
  { 'M', 'H', 'H → M: jump to middle of screen' },
  { 'L', 'M', 'M → L: jump to bottom of screen' },
  -- x count prefix
  { '{n}x', 'x', 'x → {n}x: delete multiple chars at once' },
  -- scroll chain
  { '<C-d>', 'j', 'j → <C-d>: scroll half page down' },
  { '<C-u>', '<C-d>', '<C-d> → <C-u>: scroll half page up' },
  -- paste pair
  { 'P', 'p', 'p → P: paste above current line' },
  -- t / T stop-before-char
  { 't', 'f', 'f → t: stop before character (for operators)' },
  { 'T', 't', 't → T: stop before character backward' },
  -- jumplist bidirectional
  { '<C-i>', '<C-o>', '<C-o> → <C-i>: jump forward in jump list' },
  -- full-page scroll
  { '<C-f>', '<C-d>', '<C-d> → <C-f>: scroll full page down' },
  { '<C-b>', '<C-u>', '<C-u> → <C-b>: scroll full page up' },
  -- paragraph motions
  { '}', 'j', 'j → }: jump to end of paragraph' },
  { '{', '}', '} → {: jump to start of paragraph' },
  -- scroll-lock  zz / zt / zb
  { 'zz', 'j', 'j → zz: center cursor on screen' },
  { 'zt', 'zz', 'zz → zt: scroll cursor to top of screen' },
  { 'zb', 'zz', 'zz → zb: scroll cursor to bottom of screen' },
  -- WORD motions
  { 'W', 'w', 'w → W: move forward by WORD' },
  { 'B', 'b', 'b → B: move backward by WORD' },
  -- word-end backward
  { 'ge', 'e', 'e → ge: move to end of previous word' },
  -- bracket matching
  { '%', '0', '0 → %: jump to matching bracket' },
  -- single-char edit shortcuts
  { 'r', 'x', 'x → r: replace character without insert mode' },
  { 's', 'x', 'x → s: substitute character and insert' },
  { 'cc', 'dd', 'dd → cc: change entire current line' },
  -- join lines
  { 'J', 'dd', 'dd → J: join next line onto current' },
  -- case toggle
  { '~', 'x', 'x → ~: toggle case of character' },
  -- number increment / decrement
  { '<C-a>', 'x', 'x → <C-a>: increment number under cursor' },
  { '<C-x>', '<C-a>', '<C-a> → <C-x>: decrement number under cursor' },
  -- manual sequential increment → visual-block g<C-a> (#108)
  { 'g<C-a>', '<C-a>', '<C-a> → g<C-a>: increment a sequence in visual-block mode' },
  -- visual mode chain
  { 'V', 'v', 'v → V: line-wise visual selection' },
  { '<C-v>', 'V', 'V → <C-v>: block visual selection' },
  -- yank text object
  { 'yiw', 'cw', 'cw → yiw: yank inner word' },
  -- macros
  { 'q', '.', '. → q: record a macro' },
  -- search backward pair
  { 'N', 'n', 'n → N: search backward to previous match' },
  { '#', '*', '* → #: search backward for word under cursor' },
  -- G → gg first line
  { 'gg', 'G', 'G → gg: jump to first line of file' },
  -- wrapped-line visual movement
  { 'gj', 'j', 'j → gj: move down one visual line' },
  { 'gk', 'k', 'k → gk: move up one visual line' },
  -- line-by-line scrolling
  { '<C-e>', 'zz', 'zz → <C-e>: scroll up one line without moving cursor' },
  { '<C-y>', '<C-e>', '<C-e> → <C-y>: scroll down one line without moving cursor' },
  -- change list navigation
  { 'g;', '<C-o>', '<C-o> → g;: jump to older position in change list' },
  { 'g,', 'g;', 'g; → g,: jump to newer position in change list' },
  -- return to last insert / jump positions
  { 'gi', 'i', 'i → gi: go to last insert position and re-enter insert mode' },
  { '<C-^>', '<C-o>', '<C-o> → <C-^>: switch to the alternate file' },
  { "''", '<C-o>', "<C-o> → '': jump back to position before last jump" },
  -- definition / file navigation
  { 'gd', '*', '* → gd: go to local definition' },
  { 'gf', 'gd', 'gd → gf: edit file whose name is under cursor' },
  -- reselect last visual
  { 'gv', 'V', 'V → gv: reselect last visual selection' },
  -- WORD-end backward
  { 'gE', 'ge', 'ge → gE: move to end of previous WORD' },
  -- fold commands
  { 'za', 'zz', 'zz → za: toggle fold at cursor' },
  { 'zo', 'za', 'za → zo: open fold at cursor' },
  { 'zc', 'za', 'za → zc: close fold at cursor' },
  { 'zM', 'za', 'za → zM: close all folds in buffer' },
  { 'zR', 'zM', 'zM → zR: open all folds in buffer' },
  -- delete before / replace mode / yank to EOL
  { 'X', 'x', 'x → X: delete character before cursor' },
  { 'R', 'r', 'r → R: enter replace mode' },
  { 'Y', 'p', 'p → Y: yank to end of line' },
  -- indent / unindent / auto-indent
  { '>>', 'cc', 'cc → >>: indent current line' },
  { '<<', '>>', '>> → <<: unindent current line' },
  { '==', '>>', '>> → ==: auto-indent current line' },
  -- case operators
  { 'gu', '~', '~ → gu: lowercase a region' },
  { 'gU', 'gu', 'gu → gU: uppercase a region' },
  { 'g~', '~', '~ → g~: swap case of a region' },
  -- format text / join without space
  { 'gq', '.', '. → gq: reflow / format text' },
  { 'gJ', 'J', 'J → gJ: join lines without inserting a space' },
  -- repeat last macro
  { '@@', 'q', 'q → @@: repeat the last played macro' },
  -- text object chain
  { 'ci"', 'ciw', 'ciw → ci": change inner double-quoted string' },
  { "ci'", 'ci"', 'ci" → ci\': change inner single-quoted string' },
  { 'cib', 'ci"', 'ci" → cib: change inner parentheses block' },
  { 'ciB', 'cib', 'cib → ciB: change inner braces block' },
  { 'cit', 'cib', 'cib → cit: change inner tag content' },
  { 'cip', 'ciw', 'ciw → cip: change inner paragraph' },
  -- partial word search
  { 'g*', '*', '* → g*: partial word search forward' },
  { 'g#', '#', '# → g#: partial word search backward' },
  -- window management
  { '<C-w>s', '<C-o>', '<C-o> → <C-w>s: horizontal split' },
  { '<C-w>v', '<C-w>s', '<C-w>s → <C-w>v: vertical split' },
  { '<C-w>w', '<C-w>s', '<C-w>s → <C-w>w: cycle to next window' },
  { '<C-w>h', '<C-w>w', '<C-w>w → <C-w>h: move to left window' },
  { '<C-w>j', '<C-w>w', '<C-w>w → <C-w>j: move to window below' },
  { '<C-w>k', '<C-w>w', '<C-w>w → <C-w>k: move to window above' },
  { '<C-w>l', '<C-w>w', '<C-w>w → <C-w>l: move to right window' },
  { '<C-w>q', '<C-w>w', '<C-w>w → <C-w>q: close current window' },
  { '<C-w>=', '<C-w>w', '<C-w>w → <C-w>=: equalize all window sizes' },
  { '<C-w>o', '<C-w>q', '<C-w>q → <C-w>o: close all other windows' },
  -- line-edge motions
  { '$', '^', '^ → $: jump to end of line' },
  { 'g_', '$', '$ → g_: last non-blank character of line' },
  -- backward find char
  { 'F', 'f', 'f → F: find character backward on line' },
  -- sentence motions
  { '(', '{', '{ → (: jump to start of sentence' },
  { ')', '(', '( → ): jump to end of sentence' },
  -- section / function navigation
  { '[[', 'gg', 'gg → [[: jump to previous function / section' },
  { ']]', 'G', 'G → ]]: jump to next function / section' },
  -- unmatched bracket navigation
  { '[{', '%', '% → [{: jump to enclosing { start' },
  { ']}', '%', '% → ]}: jump to enclosing } end' },
  { '[(', '[{', '[{ → [(: jump to enclosing ( start' },
  { '])', ']}', ']} → ]): jump to enclosing ) end' },
  -- screen-line first char
  { 'g0', 'gj', 'gj → g0: first character of wrapped screen line' },
  -- code navigation
  { 'gx', 'gf', 'gf → gx: open file or URL under cursor' },
  { '<C-]>', 'gf', 'gf → <C-]>: jump to tag definition' },
  { 'K', 'gd', 'gd → K: look up keyword under cursor' },
  -- paste without cursor jump
  { 'gp', 'P', 'P → gp: paste and leave cursor after pasted text' },
  { 'gP', 'gp', 'gp → gP: paste before and leave cursor after pasted text' },
  -- repeat last ex command
  { '@:', '@@', '@@ → @:: repeat last command-line command' },
  -- fold navigation
  { 'zj', 'za', 'za → zj: move to start of next fold' },
  { 'zk', 'zj', 'zj → zk: move to end of previous fold' },
  { 'zd', 'zc', 'zc → zd: delete fold at cursor' },
  -- WORD-level motion
  { 'E', 'e', 'e → E: forward to end of WORD' },
  -- undo full line
  { 'U', 'u', 'u → U: undo all changes on current line' },
  -- quit shortcuts
  { 'ZZ', 'q', 'q → ZZ: write if changed and quit' },
  { 'ZQ', 'ZZ', 'ZZ → ZQ: quit without writing' },
  -- command-line window
  { 'q:', 'q', 'q → q:: open command-line window' },
  -- column motion
  { '|', '0', '0 → |: move to column N' },
  -- first non-blank (current line)
  { '_', '^', '^ → _: first non-blank (N-1 lines lower)' },
}

describe('teaching chains', function()
  for _, tc in ipairs(chain_cases) do
    local cmd, requires, desc = tc[1], tc[2], tc[3]
    it(desc, function()
      assert.equals(requires, commands.registry[cmd].requires)
    end)
  end
end)

-- ── track integrity ──────────────────────────────────────────────────────────
-- Rule: any command whose key appears in another entry's `requires` field MUST
-- have track=true.  If track=false, count stays 0 and the dependent can never
-- clear the count>=50 threshold — silently breaking the suggestion chain.
-- Similarly, any single-char key (bare keystroke) must have track=true.

describe('tracking integrity', function()
  it('every single-char command has track=true', function()
    local violations = {}
    for cmd, entry in pairs(commands.registry) do
      if #cmd == 1 and not entry.track then
        table.insert(violations, cmd)
      end
    end
    table.sort(violations)
    assert.are.same({}, violations, 'single-char commands with track=false: ' .. table.concat(violations, ' '))
  end)

  -- Rule from lua/tobira/CLAUDE.md: any key referenced by another entry's
  -- `requires` field must actually be trackable, or its usage count is
  -- structurally stuck at 0 forever and graph.find_best() (which requires
  -- trigger_count > 0) can never surface the dependent entry as a suggestion.
  -- The narrower "single-char track=true" test above did not catch this —
  -- see #120, where 31 multi-char entries went unnoticed this way.
  --
  -- A `requires` target is trackable when:
  --   1. it is a single character (guaranteed track=true by the test above,
  --      or one of the base motion keys logger.lua's build_track_table()
  --      hardcodes regardless of the registry — f/F/n/0/h/j/k/l/w/b/x/p/u/
  --      i/a/o/G/v/*), or
  --   2. entry.track == true, or
  --   3. entry.compound == true (dw / dd — tracked via seq.last_op change
  --      detection in logger.lua's handle_key), or
  --   4. it is in PATTERN_TRACKED below: a multi-char key that patterns.lua
  --      records via the same seq.last_op change-detection mechanism even
  --      though its registry entry has track=false — either through the
  --      generic operator-normalization branches (cw / >> — see patterns.lua
  --      inner_feed's pending_op handling) or through an explicit two-key
  --      dispatch table (pending_g / pending_z / pending_ctrl_w).
  local PATTERN_TRACKED = {
    -- generic operator normalization (pending_op in patterns.lua)
    cw = true,
    ['>>'] = true,
    ['<<'] = true,
    -- pending_g dispatch table
    gg = true,
    gj = true,
    gk = true,
    ge = true,
    gd = true,
    gf = true,
    gn = true,
    gx = true,
    ['g0'] = true,
    ['g;'] = true,
    gp = true,
    gu = true,
    -- pending_z dispatch table
    zz = true,
    zt = true,
    zb = true,
    za = true,
    zc = true,
    zo = true,
    zj = true,
    zk = true,
    zM = true,
    zR = true,
    zd = true,
    -- pending_ctrl_w dispatch table (#120)
    ['<C-w>s'] = true,
    ['<C-w>v'] = true,
    ['<C-w>w'] = true,
    ['<C-w>h'] = true,
    ['<C-w>j'] = true,
    ['<C-w>k'] = true,
    ['<C-w>l'] = true,
    ['<C-w>q'] = true,
    ['<C-w>='] = true,
  }

  -- Entries left untrackable on purpose as of #120. Fixing this PR's minimum
  -- scope (the window category) plus g;/gp/gu leaves these deferred to
  -- follow-up issues — see the #120 PR description for the reasoning behind
  -- each group. This list must only ever shrink: a fix must remove the
  -- entry here, never add to it without also adding a detection path above.
  local KNOWN_DEFERRED = {
    -- mark chain: '. / '^ / 'a are never recorded as such — the pending_mark
    -- prefix in patterns.lua consumes the mark-name key without recording
    -- which mark command it was (m/'/` all just consume-and-discard).
    ["'."] = true,
    ["'^"] = true,
    ["'a"] = true,
    -- text-object chain: ciw / ci" / cib all collapse into the generic 'cw'
    -- bucket (pending_text_obj always sets last_op = op .. 'w', discarding
    -- which specific text object was used), so none of the specific
    -- variants are ever individually counted.
    ['ci"'] = true,
    ["ci'"] = true,
    ['cib'] = true,
    ['ciB'] = true,
    ['cit'] = true,
    ['cip'] = true,
    ['diw'] = true,
    -- macro chain: @@ / ZZ are never recorded — patterns.lua has no pending
    -- handler for @ (pending_register just consumes-and-discards the
    -- register/macro name) or for the doubled Z Z sequence.
    ['@:'] = true,
    ['@q'] = true,
    ['ZQ'] = true,
    -- bracket pairs: [{ / ]} are never recorded — pending_bracket consumes
    -- the bracket-pair character without recording which pair it was.
    ['[('] = true,
    ['])'] = true,
    -- indent chain: >> itself is trackable, but it requires 'cc', and cc is
    -- never recorded due to a separate bug (last_op is hardcoded to 'dd' for
    -- any doubled operator, not op .. op) — tracked separately as #118.
    ['>>'] = true,
  }

  it('every requires target is track=true, compound=true, or pattern-tracked (or explicitly deferred)', function()
    local violations = {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.requires and #entry.requires > 1 then
        local req = entry.requires
        local req_entry = commands.registry[req]
        local trackable = (req_entry and req_entry.track) or (req_entry and req_entry.compound) or PATTERN_TRACKED[req]
        if not trackable and not KNOWN_DEFERRED[cmd] then
          table.insert(violations, cmd .. ' (requires "' .. req .. '")')
        end
      end
    end
    table.sort(violations)
    assert.are.same(
      {},
      violations,
      'requires targets with no tracking path and not in KNOWN_DEFERRED: ' .. table.concat(violations, ', ')
    )
  end)

  it('KNOWN_DEFERRED contains no stale entries that are now actually trackable', function()
    local stale = {}
    for cmd in pairs(KNOWN_DEFERRED) do
      local entry = commands.registry[cmd]
      if entry and entry.requires then
        local req_entry = commands.registry[entry.requires]
        local trackable = #entry.requires == 1
          or (req_entry and req_entry.track)
          or (req_entry and req_entry.compound)
          or PATTERN_TRACKED[entry.requires]
        if trackable then
          table.insert(stale, cmd)
        end
      end
    end
    table.sort(stale)
    assert.are.same({}, stale, 'entries fixed but still listed in KNOWN_DEFERRED: ' .. table.concat(stale, ', '))
  end)
end)
