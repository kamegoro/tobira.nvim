-- Pure render tests for the :TobiraStats UI.
-- ui/stats.lua must expose M.render(usage) as a pure function returning
-- { title = string, body = string } so the layout can be asserted without
-- touching vim.notify.

local stats = require('tobira.ui.stats')

local function entry(count)
  return { count = count, sessions = {}, shown = 0, suppressed = false, pinned = false }
end

-- Split body into lines for line-oriented assertions.
local function lines_of(rendered)
  local out = {}
  for line in (rendered.body .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(out, line)
  end
  return out
end

local function find_line(rendered, needle)
  for _, line in ipairs(lines_of(rendered)) do
    if line:find(needle, 1, true) then
      return line
    end
  end
  return nil
end

-- ── layout basics ─────────────────────────────────────────────────────────────

describe('when nothing has been recorded yet', function()
  it('renders zero keystrokes and zero discovered commands', function()
    local r = stats.render({})
    assert.is_not_nil(find_line(r, '0'), 'expected a 0-count line in the summary')
    assert.is_not_nil(r.title, 'render() must return a title string')
  end)

  it('renders a 16-character mastery bar even when empty', function()
    local r = stats.render({})
    local bar_line = find_line(r, '░')
    assert.is_not_nil(bar_line, 'expected an empty-portion bar segment')
    -- Bar is exactly 16 segments made of █ and ░.
    local bar = bar_line:match('([█░]+)')
    assert.is_not_nil(bar, 'expected a █/░ bar in the mastery line')
    assert.equals(16, vim.fn.strdisplaywidth(bar))
  end)

  it('does not render a Top commands section', function()
    local r = stats.render({})
    -- No usage → no top commands header should appear.
    -- Body should not contain any command listing rows (indented with 4 spaces + star/blank).
    for _, line in ipairs(lines_of(r)) do
      assert.is_nil(line:match('^%s%s%s%s[☆★ ]+%s+%S+%s+%d+×$'), 'unexpected top-commands row: ' .. line)
    end
  end)
end)

-- ── totals ───────────────────────────────────────────────────────────────────

describe('when several commands have been used', function()
  it('formats the total keystrokes with thousands separators', function()
    local r = stats.render({
      j = entry(1520),
      k = entry(892),
    })
    assert.is_not_nil(find_line(r, '2,412'), 'expected total = 2,412 formatted with comma')
  end)

  it('shows the discovered / total commands ratio', function()
    -- cw is a registered command, so it counts toward Discovered.
    local r = stats.render({ cw = entry(50) })
    -- The ratio line has the shape "1 / <registry_size>".
    assert.is_not_nil(find_line(r, '1 /'), 'expected "1 / <total>" line for discovered ratio')
  end)
end)

-- ── top commands ──────────────────────────────────────────────────────────────

describe('when many commands have been recorded', function()
  it('lists at most the top 8 commands by count', function()
    -- Use registry commands only (basic keys like j/k are excluded from Top).
    local r = stats.render({
      cw = entry(1000),
      ciw = entry(900),
      dw = entry(800),
      diw = entry(700),
      [';'] = entry(600),
      [','] = entry(500),
      gj = entry(400),
      gg = entry(300),
      ['G'] = entry(200),
      dap = entry(100),
    })
    -- Count rows between the Top commands header and the next blank line.
    local lines = lines_of(r)
    local top_header_idx = nil
    for i, line in ipairs(lines) do
      if line:find('Top', 1, true) then
        top_header_idx = i
        break
      end
    end
    assert.is_not_nil(top_header_idx, 'expected a Top commands header')
    local rows = 0
    for i = top_header_idx + 1, #lines do
      if lines[i] == '' then
        break
      end
      rows = rows + 1
    end
    assert.equals(8, rows)
  end)

  it('sorts top commands by count descending', function()
    local r = stats.render({
      cw = entry(1000),
      dw = entry(500),
    })
    local body = r.body
    local top_start = body:find('Top', 1, true)
    assert.is_not_nil(top_start, 'expected a Top commands section header')
    local cw_pos = body:find('cw', top_start, true)
    local dw_pos = body:find('dw', top_start, true)
    assert.is_not_nil(cw_pos)
    assert.is_not_nil(dw_pos)
    assert.is_true(cw_pos < dw_pos, 'expected higher-count cw to appear before dw')
  end)

  it('tie-breaks alphabetically on equal counts', function()
    local r = stats.render({
      cw = entry(3),
      [';'] = entry(3),
    })
    local body = r.body
    local top_start = body:find('Top', 1, true) or 1
    -- ';' < 'cw' alphabetically → ';' first
    assert.is_true(body:find(';', top_start, true) < body:find('cw', top_start, true))
  end)

  it('includes basic keys and compound operators in the Top list', function()
    -- j (basic key, not in registry) and dd (compound) should still appear
    -- in the Top commands leaderboard so users see their real usage.
    local r = stats.render({
      j = entry(1520),
      dd = entry(234),
    })
    assert.is_not_nil(find_line(r, 'j'), 'expected j in Top list')
    assert.is_not_nil(find_line(r, 'dd'), 'expected dd in Top list')
  end)

  -- ── forgotten state ────────────────────────────────────────────────────────
  -- Regression test -- see docs/adr/0076-stats-forgotten-overrides-mastery-star.md.

  it('renders the ⟳ glyph instead of a mastery star for a forgotten command', function()
    -- cw is also the trigger for '.' and 'yiw', so it additionally spawns
    -- "Try these next" efficiency-gap rows containing the same "cw" text —
    -- search only the lines from the Top commands header onward so those
    -- earlier gap rows can't be mistaken for the Top commands row.
    local r = stats.render({
      cw = { count = 200, sessions = { 8, 9, 0, 0 }, shown = 0, suppressed = false, pinned = false },
    })
    local lines = lines_of(r)
    local top_header_idx = nil
    for i, line in ipairs(lines) do
      if line:find('Top', 1, true) then
        top_header_idx = i
        break
      end
    end
    assert.is_not_nil(top_header_idx, 'expected a Top commands section header')
    local row = nil
    for i = top_header_idx + 1, #lines do
      if lines[i]:find('cw', 1, true) then
        row = lines[i]
        break
      end
    end
    assert.is_not_nil(row, 'expected a row for cw in the Top commands section')
    assert.is_not_nil(row:find('⟳', 1, true))
    assert.is_nil(row:find('★', 1, true))
  end)
end)

-- ── efficiency gaps ───────────────────────────────────────────────────────────

describe('when the user overuses a trigger without adopting its successor', function()
  it('renders an efficiency gap row with an arrow', function()
    local r = stats.render({ f = entry(200) })
    assert.is_not_nil(find_line(r, '→'), 'expected an arrow in the efficiency gap section')
  end)
end)

describe('when an efficiency gap involves a 6-character command key (#125)', function()
  it('aligns the count/arrow column with rows using a shorter key', function()
    -- f (1 char) triggers ;/F/t gaps; <C-w>w (6 chars, commands.lua:344-350)
    -- triggers <C-w>=/<C-w>h/... gaps. Rendering both together reproduces the
    -- misalignment a fixed 5-wide column produced once a 6-char key overflowed it.
    local r = stats.render({ f = entry(200), ['<C-w>w'] = entry(100) })
    local rows = {}
    for _, line in ipairs(lines_of(r)) do
      if line:find('→', 1, true) then
        table.insert(rows, line)
      end
    end
    assert.is_true(#rows >= 2, 'expected gap rows from both f and <C-w>w')

    local has_six_char_key = false
    for _, row in ipairs(rows) do
      if row:find('<C-w>', 1, true) then
        has_six_char_key = true
      end
    end
    assert.is_true(has_six_char_key, 'expected a 6-character <C-w>X key among the gap rows')

    local arrow_col = rows[1]:find('→', 1, true)
    for _, row in ipairs(rows) do
      assert.equals(arrow_col, row:find('→', 1, true), 'arrow column misaligned: ' .. row)
    end
    -- The trailing child-count column must also land on the same width —
    -- checking only the arrow (which sits before the child key) would miss a
    -- child-column-only misalignment.
    local row_w = vim.fn.strdisplaywidth(rows[1])
    for _, row in ipairs(rows) do
      assert.equals(row_w, vim.fn.strdisplaywidth(row), 'row width misaligned: ' .. row)
    end
  end)
end)

-- Hardening test: the column width must adapt beyond the first specific case
-- found -- see docs/adr/0074-stats-dynamic-key-column-width.md. Sharing one
-- parent ('i') isolates the child-column width difference without depending
-- on which candidates win the top-N ratio sort.
describe('when a gap child key is longer than 6 characters (#125 hardening)', function()
  it('still aligns the child-count column against a shorter child key', function()
    local r = stats.render({ i = entry(100) })
    local rows = {}
    for _, line in ipairs(lines_of(r)) do
      if line:find('→', 1, true) then
        table.insert(rows, line)
      end
    end
    assert.is_true(#rows >= 2, 'expected gap rows from both <C-n> and <C-\\><C-n>')

    local has_long_key = false
    for _, row in ipairs(rows) do
      if row:find('<C-\\><C-n>', 1, true) then
        has_long_key = true
      end
    end
    assert.is_true(has_long_key, 'expected the 10-character <C-\\><C-n> key among the gap rows')

    -- Both rows share the same parent ('i'), so the arrow column is already
    -- identical either way — the row's total width is what actually exposes
    -- a child-column-only misalignment (the 10-char key overflowing a
    -- fixed-width child column shifts its own trailing count rightward).
    local row_w = vim.fn.strdisplaywidth(rows[1])
    for _, row in ipairs(rows) do
      assert.equals(row_w, vim.fn.strdisplaywidth(row), 'row width misaligned: ' .. row)
    end
  end)
end)

describe('when there are no efficiency gaps', function()
  it('omits the try-next section entirely', function()
    local r = stats.render({})
    assert.is_nil(find_line(r, '→'), 'try-next arrows should be hidden when no gaps exist')
  end)
end)

-- ── keymap overrides ─────────────────────────────────────────────────────────
-- Regression test -- see docs/adr/0030-keymap-override-exclusion-contract.md.

describe('when a "Try these next" candidate has been remapped by the user', function()
  local integrations = require('tobira.core.integrations')

  local function fake_keymap(entries)
    return function(_mode)
      return entries
    end
  end

  before_each(function()
    integrations.reset()
  end)
  after_each(function()
    integrations.reset()
  end)

  it('excludes the gap row for a remapped-away child command', function()
    -- 'f' triggers several gap candidates (';', 't', 'F'), so this asserts on
    -- the specific remapped child rather than the mere absence of any '→' —
    -- the other f-triggered gaps are expected to keep rendering normally.
    integrations.refresh(fake_keymap({ { lhs = ';', rhs = '<Plug>(something)', noremap = 0 } }))
    local r = stats.render({ f = entry(200) })
    local semicolon_gap = nil
    for _, line in ipairs(lines_of(r)) do
      if line:match('→%s+;%s') then
        semicolon_gap = line
      end
    end
    assert.is_nil(semicolon_gap, 'a remapped-away child (;) must not appear as a "Try these next" gap')
  end)

  it('still shows the gap row normally when nothing has been remapped', function()
    integrations.refresh(fake_keymap({}))
    local r = stats.render({ f = entry(200) })
    assert.is_not_nil(find_line(r, '→'), 'the gap should render normally with no overrides in place')
  end)
end)

-- ── section order: actionable info first, vanity metric last ────────────────

describe('section order', function()
  it('renders "Try these next" before "Mastery" when a gap exists', function()
    local loc = require('tobira.i18n').load()
    local r = stats.render({ f = entry(200) })
    local try_pos = r.body:find(loc.stats.try_next, 1, true)
    local mastery_pos = r.body:find(loc.stats.mastery, 1, true)
    assert.is_not_nil(try_pos)
    assert.is_not_nil(mastery_pos)
    assert.is_true(try_pos < mastery_pos, '"Try these next" should come before "Mastery"')
  end)

  it('renders "Mastery" before "Top commands"', function()
    local loc = require('tobira.i18n').load()
    local r = stats.render({ cw = entry(50) })
    local mastery_pos = r.body:find(loc.stats.mastery, 1, true)
    local top_pos = r.body:find(loc.stats.top_commands, 1, true)
    assert.is_not_nil(mastery_pos)
    assert.is_not_nil(top_pos)
    assert.is_true(mastery_pos < top_pos, '"Mastery" should come before "Top commands"')
  end)

  it('renders the keystroke/discovered summary as the last line of the body', function()
    local r = stats.render({ cw = entry(50) })
    local lines = lines_of(r)
    -- Trailing blank-line-splitting artifact aside, the last non-empty line
    -- should be the footer summary, not a Top-commands row or gap row.
    local last = lines[#lines] ~= '' and lines[#lines] or lines[#lines - 1]
    assert.is_not_nil(last:find('keystrokes', 1, true))
  end)
end)

-- ── TobiraH1 section headings ─────────────────────────────────────────────────

describe('section heading highlights', function()
  it('applies TobiraH1 to the Mastery, Top commands, and Try these next headings', function()
    local r = stats.render({ f = entry(200), cw = entry(50) })
    local lines = lines_of(r)
    local h1_lnums = {}
    for _, h in ipairs(r.hls) do
      if h.group == 'TobiraH1' then
        h1_lnums[h.lnum] = true
      end
    end
    local loc = require('tobira.i18n').load()
    local headings = { loc.stats.try_next, loc.stats.mastery, loc.stats.top_commands }
    for _, heading in ipairs(headings) do
      local found = false
      for lnum, line in ipairs(lines) do
        if line:find(heading, 1, true) and h1_lnums[lnum - 1] then
          found = true
        end
      end
      assert.is_true(found, 'expected TobiraH1 on the "' .. heading .. '" heading line')
    end
  end)
end)

-- ── footer summary ───────────────────────────────────────────────────────────

describe('the footer summary line', function()
  it('is styled with TobiraDim', function()
    local r = stats.render({ cw = entry(50) })
    local lines = lines_of(r)
    local summary_lnum = nil
    for i, line in ipairs(lines) do
      if line:find('keystrokes', 1, true) then
        summary_lnum = i - 1
      end
    end
    assert.is_not_nil(summary_lnum)
    local found = false
    for _, h in ipairs(r.hls) do
      if h.lnum == summary_lnum and h.group == 'TobiraDim' then
        found = true
      end
    end
    assert.is_true(found, 'expected TobiraDim on the footer summary line')
  end)

  it('uses comma-formatted keystrokes and the discovered ratio', function()
    local r = stats.render({ j = entry(1520), k = entry(892), cw = entry(50) })
    assert.is_not_nil(find_line(r, '2,462')) -- 1520 + 892 + 50
    assert.is_not_nil(find_line(r, '1 /'))
  end)
end)

-- ── keybinding footer with g/p ───────────────────────────────────────────────

describe('when the stats window is open', function()
  after_each(function()
    stats.close()
  end)

  it('pins the keybindings to the window footer with accent-coloured keys', function()
    local loc = require('tobira.i18n').load()
    stats.open()
    local cfg = vim.api.nvim_win_get_config(vim.fn.win_getid())
    assert.is_table(cfg.footer)
    local footer, accent_keys = '', {}
    for _, chunk in ipairs(cfg.footer) do
      footer = footer .. chunk[1]
      if chunk[2] == 'TobiraGuideKey' then
        accent_keys[chunk[1]] = true
      end
    end
    for _, key in ipairs({ 'g', 'p', 'q' }) do
      assert.is_true(accent_keys[key] == true, 'expected key ' .. key .. ' as an accent chunk in the footer')
    end
    assert.is_true(footer:find(loc.stats.footer.guide, 1, true) ~= nil, 'expected the guide label in the footer')
    assert.is_true(footer:find(loc.stats.footer.close, 1, true) ~= nil, 'expected the close label in the footer')
  end)

  it('pressing g closes stats and opens guide', function()
    local called = false
    package.loaded['tobira.ui.guide'] = {
      open = function()
        called = true
      end,
    }
    local ok, err = pcall(function()
      stats.open()
      vim.fn.feedkeys('g', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    package.loaded['tobira.ui.guide'] = nil
    assert.is_true(ok, err)
    assert.is_true(called)
    assert.is_false(stats.is_open())
  end)

  it('pressing p closes stats and opens progress', function()
    local called = false
    package.loaded['tobira.ui.progress'] = {
      open = function()
        called = true
      end,
    }
    local ok, err = pcall(function()
      stats.open()
      vim.fn.feedkeys('p', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    package.loaded['tobira.ui.progress'] = nil
    assert.is_true(ok, err)
    assert.is_true(called)
    assert.is_false(stats.is_open())
  end)
end)

-- ── <C-c> to close ────────────────────────────────────────────────────────────

describe('when <C-c> is pressed in the stats window', function()
  after_each(function()
    stats.close()
  end)

  it('closes the window', function()
    local ctrl_c = vim.api.nvim_replace_termcodes('<C-c>', true, false, true)
    stats.open()
    vim.fn.feedkeys(ctrl_c, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(stats.is_open())
  end)
end)

-- ── M.show() / M.toggle() ────────────────────────────────────────────────────

describe('when show() is called', function()
  after_each(function()
    stats.close()
  end)

  it('opens a stats window', function()
    local ok, err = pcall(stats.show)
    assert.is_true(ok, tostring(err))
    assert.is_true(stats.is_open(), 'expected a stats window to be open')
  end)

  it('closes the window when called a second time (toggle)', function()
    stats.show()
    stats.show()
    assert.is_false(stats.is_open(), 'expected the stats window to close on second call')
  end)

  it('is a no-op when open() is called while already open', function()
    stats.open()
    stats.open()
    assert.is_true(stats.is_open(), 'expected window to remain open')
  end)
end)

-- ── highlight placement in the open window ────────────────────────────────────
-- Regression test: M.open() applied every highlight at hl.lnum + 1 instead of
-- hl.lnum, one row below where M.render()'s own hls table says it belongs —
-- header highlights landed on the row under the header, and the footer
-- highlight could land past the buffer's last line and be silently dropped.
describe('highlight placement in the open stats window (#214)', function()
  local logger = require('tobira.core.logger')

  before_each(function()
    logger.reset()
  end)

  after_each(function()
    stats.close()
    logger.reset()
  end)

  local function seeded_usage()
    local usage = logger.get_all()
    -- 'f' seeds a "Try these next" efficiency-gap row.
    usage['f'] = { count = 200, sessions = {}, shown = 0, suppressed = false, pinned = false }
    -- 'cw' seeds a "Top commands" row.
    usage['cw'] = { count = 50, sessions = {}, shown = 0, suppressed = false, pinned = false }
    return usage
  end

  it('places every highlight on the exact row M.render() assigned it, not one row below', function()
    local usage = seeded_usage()
    local rendered = stats.render(usage)

    -- Sanity: this seed produces every section the bug affected.
    local loc = require('tobira.i18n').load()
    assert.is_not_nil(rendered.body:find(loc.stats.try_next, 1, true), 'expected a Try these next section')
    assert.is_not_nil(rendered.body:find(loc.stats.mastery, 1, true), 'expected a Mastery section')
    assert.is_not_nil(rendered.body:find(loc.stats.top_commands, 1, true), 'expected a Top commands section')
    assert.is_true(#rendered.hls >= 4, 'expected the 3 TobiraH1 headers plus the footer highlight')

    stats.open()
    local buf = vim.api.nvim_win_get_buf(vim.fn.win_getid())
    local ns = vim.api.nvim_create_namespace('tobira_stats')

    for _, h in ipairs(rendered.hls) do
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { h.lnum, 0 }, { h.lnum, -1 }, { details = true })
      local found = false
      for _, m in ipairs(marks) do
        if m[4].hl_group == h.group then
          found = true
        end
      end
      assert.is_true(
        found,
        string.format('expected a %s extmark on row %d (M.render() said it belongs there), got none', h.group, h.lnum)
      )
    end
  end)

  it('does not drop the footer summary highlight off the end of the buffer', function()
    local usage = seeded_usage()
    local rendered = stats.render(usage)
    local footer_hl
    for _, h in ipairs(rendered.hls) do
      if h.group == 'TobiraDim' then
        footer_hl = h
      end
    end
    assert.is_not_nil(footer_hl, 'expected a TobiraDim footer highlight in the pure render output')

    stats.open()
    local buf = vim.api.nvim_win_get_buf(vim.fn.win_getid())
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- The row it belongs to must actually exist in the buffer.
    assert.is_not_nil(buf_lines[footer_hl.lnum + 1], 'expected the footer row to exist in the buffer')

    local ns = vim.api.nvim_create_namespace('tobira_stats')
    local marks =
      vim.api.nvim_buf_get_extmarks(buf, ns, { footer_hl.lnum, 0 }, { footer_hl.lnum, -1 }, { details = true })
    local found = false
    for _, m in ipairs(marks) do
      if m[4].hl_group == 'TobiraDim' then
        found = true
      end
    end
    assert.is_true(found, 'expected the footer TobiraDim highlight to actually apply, not be silently dropped')
  end)
end)

-- 'i_<C-o>' is an internal composite registry key (see commands.lua's
-- registry comment) — the Top-commands leaderboard must show the real
-- keystroke the user pressed (<C-o>), never the raw internal key.
describe("the 'i_<C-o>' composite registry key in Top commands (#105)", function()
  it('renders as <C-o>, not the raw i_<C-o> registry key', function()
    local r = stats.render({ ['i_<C-o>'] = entry(50) })
    local row = find_line(r, '<C-o>')
    assert.is_not_nil(row, 'expected a Top-commands row containing <C-o>')
    assert.is_nil(row:find('i_<C-o>', 1, true), 'row must not contain the raw internal key: ' .. row)
  end)
end)

-- ── extmark rendering (nvim_buf_add_highlight migration) ───────────────────────
-- Every highlight this module applies is a full-line highlight (M.render()
-- defaults every entry to the old col_end == -1 case); confirms the new
-- nvim_buf_set_extmark()-based call still reaches the real end of the line.
-- Targets hl.lnum directly -- see the "highlight placement in the open
-- window" describe block above for the off-by-one row bug this guards against.
describe('extmark rendering after the nvim_buf_add_highlight migration (#151)', function()
  local logger = require('tobira.core.logger')

  before_each(function()
    logger.reset()
  end)

  after_each(function()
    stats.close()
    logger.reset()
  end)

  it("highlights the row it actually targets (hl.lnum) through that row's real end of line", function()
    local usage = logger.get_all()
    usage['j'] = { count = 1520, sessions = {}, shown = 0, suppressed = false, pinned = false }
    usage['k'] = { count = 892, sessions = {}, shown = 0, suppressed = false, pinned = false }

    local rendered = stats.render(usage)
    local expected
    for _, h in ipairs(rendered.hls) do
      if h.group == 'TobiraH1' then
        expected = h
      end
    end
    assert.is_not_nil(expected, 'expected a TobiraH1 header range in the pure render output')
    assert.equals(-1, expected.ce, 'sanity check: this must be the legacy col_end == -1 case')

    stats.open()
    local buf = vim.api.nvim_win_get_buf(vim.fn.win_getid())
    local target_lnum = expected.lnum
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_not_nil(buf_lines[target_lnum + 1], 'expected the targeted row to exist in the buffer')

    local ns = vim.api.nvim_create_namespace('tobira_stats')
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { target_lnum, 0 }, { target_lnum, -1 }, { details = true })
    local mark
    for _, m in ipairs(marks) do
      if m[4].hl_group == 'TobiraH1' then
        mark = m
      end
    end
    assert.is_not_nil(mark, 'expected a real TobiraH1 extmark on the targeted row')
    local details = mark[4]
    assert.equals(target_lnum, details.end_row, 'a full-line range must resolve on its own line, not roll onto the next')
    assert.equals(#buf_lines[target_lnum + 1], details.end_col, 'must reach the real end of the line, not column 0')
  end)
end)
