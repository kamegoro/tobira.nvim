local progress = require('tobira.ui.progress')
local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

local function setup()
  logger.reset()
  config.reset()
  config.setup({})
  progress.close()
  vim.cmd('enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
end

local function teardown()
  progress.close()
  logger.reset()
end

local function entry(overrides)
  local base = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false }
  for k, v in pairs(overrides or {}) do
    base[k] = v
  end
  return base
end

local function lines_contain(lines, text)
  for _, line in ipairs(lines) do
    if line:find(text, 1, true) then
      return true
    end
  end
  return false
end

-- 1-indexed row, 0-indexed col of the first occurrence of `needle`, or nil.
local function find_pos(lines, needle)
  for i, line in ipairs(lines) do
    local s = line:find(needle, 1, true)
    if s then
      return i, s - 1
    end
  end
  return nil, nil
end

local function open_with_semicolon(count, suppressed, pinned)
  local usage = logger.get_all()
  usage[';'] = entry({ count = count, suppressed = suppressed or false, pinned = pinned or false })
  progress.open()
  local buf = vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- ── lifecycle (regression) ────────────────────────────────────────────────────

describe('when the progress window has never been opened', function()
  before_each(setup)
  after_each(teardown)

  it('is_open() returns false', function()
    assert.is_false(progress.is_open())
  end)
end)

describe('when the progress window is opened', function()
  before_each(setup)
  after_each(teardown)

  it('is_open() returns true', function()
    progress.open()
    assert.is_true(progress.is_open())
  end)

  it('opens without error', function()
    assert.has_no_error(function()
      progress.open()
    end)
  end)

  it('restores the previous window when closed', function()
    local prev = vim.api.nvim_get_current_win()
    progress.open()
    progress.close()
    assert.equals(prev, vim.api.nvim_get_current_win())
  end)
end)

describe('when the progress window is opened twice (toggle)', function()
  before_each(setup)
  after_each(teardown)

  it('closes the window', function()
    progress.open()
    progress.open()
    assert.is_false(progress.is_open())
  end)
end)

describe('when the progress window is closed', function()
  before_each(setup)
  after_each(teardown)

  it('is_open() returns false', function()
    progress.open()
    progress.close()
    assert.is_false(progress.is_open())
  end)

  it('close() is idempotent when no window is open', function()
    assert.has_no_error(function()
      progress.close()
      progress.close()
    end)
  end)
end)

-- ── keys on non-skill rows (regression) ──────────────────────────────────────

describe('when x is pressed on a non-skill row (e.g., the header)', function()
  before_each(setup)
  after_each(teardown)

  it('does not crash', function()
    progress.open()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    assert.has_no_error(function()
      vim.fn.feedkeys('x', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    assert.is_true(progress.is_open())
  end)
end)

describe('when p is pressed on a non-skill row (e.g., the header)', function()
  before_each(setup)
  after_each(teardown)

  it('does not crash', function()
    progress.open()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    assert.has_no_error(function()
      vim.fn.feedkeys('p', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    assert.is_true(progress.is_open())
  end)
end)

-- ── q / Esc to close (regression) ────────────────────────────────────────────

describe('when q is pressed in the progress window', function()
  before_each(setup)
  after_each(teardown)

  it('closes the window', function()
    progress.open()
    vim.fn.feedkeys('q', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(progress.is_open())
  end)
end)

describe('when Esc is pressed in the progress window', function()
  before_each(setup)
  after_each(teardown)

  it('closes the window', function()
    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    progress.open()
    vim.fn.feedkeys(esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(progress.is_open())
  end)
end)

-- ── mastery symbol rendering (regression) ────────────────────────────────────

describe('when an adopted motion skill has been used once (mastery level 1)', function()
  before_each(setup)
  after_each(teardown)

  it('renders the open-star glyph on the skill row', function()
    local lines = open_with_semicolon(1, false, false)
    assert.is_true(lines_contain(lines, '☆'))
  end)
end)

describe('when an adopted motion skill has count >= 100 (mastery level 2)', function()
  before_each(setup)
  after_each(teardown)

  it('renders one filled star on the skill row', function()
    local lines = open_with_semicolon(100, false, false)
    assert.is_true(lines_contain(lines, '★'))
  end)
end)

describe('when an adopted motion skill has count >= 1000 (mastery level 3)', function()
  before_each(setup)
  after_each(teardown)

  it('renders two filled stars on the skill row', function()
    local lines = open_with_semicolon(1000, false, false)
    assert.is_true(lines_contain(lines, '★★'))
  end)
end)

describe('when an adopted motion skill has count >= 5000 (mastery level 4, mastered)', function()
  before_each(setup)
  after_each(teardown)

  it('renders three filled stars on the skill row', function()
    local lines = open_with_semicolon(5000, false, false)
    assert.is_true(lines_contain(lines, '★★★'))
  end)
end)

describe('when an adopted motion skill is suppressed', function()
  before_each(setup)
  after_each(teardown)

  it('renders the suppressed glyph on the skill row', function()
    local lines = open_with_semicolon(5, true, false)
    assert.is_true(lines_contain(lines, '✗'))
  end)
end)

-- ── pin marker upgrade (#67: * -> ●) ─────────────────────────────────────────

describe('when an adopted motion skill is pinned', function()
  before_each(setup)
  after_each(teardown)

  it('renders the ● pin marker on the skill row, not *', function()
    local lines = open_with_semicolon(5, false, true)
    assert.is_true(lines_contain(lines, ';●'))
    assert.is_false(lines_contain(lines, ';*'))
  end)
end)

-- ── x / p key on adopted skill row (regression, robust row lookup) ──────────

describe('when x is pressed on an adopted skill row at a valid column', function()
  before_each(setup)
  after_each(teardown)

  it('suppresses the skill and refreshes the window (still open)', function()
    local usage = logger.get_all()
    usage[';'] = entry({ count = 5 })
    progress.open()
    assert.is_false(logger.get(';').suppressed)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row, col = find_pos(lines, ';')
    assert.is_not_nil(row, 'expected to find ; in the rendered grid')
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.fn.feedkeys('x', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(progress.is_open())
    assert.is_true(logger.get(';').suppressed)
  end)
end)

describe('when x is pressed on a skill row at column 0 (before sym area)', function()
  before_each(setup)
  after_each(teardown)

  it('does nothing (cell_idx < 1) and the window stays open', function()
    local usage = logger.get_all()
    usage[';'] = entry({ count = 5 })
    progress.open()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row = select(1, find_pos(lines, ';'))
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    assert.has_no_error(function()
      vim.fn.feedkeys('x', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    assert.is_true(progress.is_open())
  end)
end)

describe('when p is pressed on an adopted skill row at a valid column', function()
  before_each(setup)
  after_each(teardown)

  it('pins the skill and refreshes the window (still open)', function()
    local usage = logger.get_all()
    usage[';'] = entry({ count = 5 })
    progress.open()
    assert.is_false(logger.get(';').pinned)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row, col = find_pos(lines, ';')
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.fn.feedkeys('p', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(progress.is_open())
    assert.is_true(logger.get(';').pinned)
  end)
end)

-- ── cursor-to-command mapping under byte/display-width drift (#124) ─────────

describe('when p is pressed over a cell preceded by multiple mastered+pinned cells in the same row', function()
  before_each(setup)
  after_each(teardown)

  it('pins the command visually under the cursor, not a neighboring one', function()
    local usage = logger.get_all()
    -- '$' and '%' are mastered (level 4, three ★ = 9 bytes for 3 display cols)
    -- and pinned (● = 3 bytes for 1 display col) — each cell is +8 bytes wider
    -- than its 14-column display budget. '(' is the cursor target; ')' is the
    -- neighboring cell the byte-offset bug used to resolve to instead.
    usage['$'] = entry({ count = 5000, pinned = true })
    usage['%'] = entry({ count = 5000, pinned = true })
    usage['('] = entry({ count = 0 })
    usage[')'] = entry({ count = 0 })
    progress.open()
    assert.is_false(logger.get('(').pinned)
    assert.is_false(logger.get(')').pinned)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row, col = find_pos(lines, '(')
    assert.is_not_nil(row, 'expected to find ( in the rendered grid')
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.fn.feedkeys('p', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(progress.is_open())
    assert.is_true(logger.get('(').pinned, 'expected ( to be pinned (the cell visually under the cursor)')
    assert.is_false(logger.get(')').pinned, 'did not expect ) to be pinned (cursor was not over it)')
  end)
end)

-- ── H1 status line (#67) ──────────────────────────────────────────────────────

describe('the H1 line', function()
  before_each(setup)
  after_each(teardown)

  it('renders both the level label and the mastered ratio', function()
    local lines = progress.build(logger.get_all())
    local loc = require('tobira.i18n').load()
    local h1 = lines[2]
    assert.is_not_nil(h1:find(loc.progress.level_label, 1, true))
    assert.is_not_nil(h1:find('mastered', 1, true))
  end)

  it('right-aligns the mastered ratio at the end of the line', function()
    local lines = progress.build(logger.get_all())
    local loc = require('tobira.i18n').load()
    local skills = require('tobira.core.skills')
    local total = 0
    for _, cat in ipairs(skills.tree) do
      total = total + #cat.items
    end
    local expected_suffix = loc.progress.mastered_total:format(0, total)
    local h1 = lines[2]
    assert.equals(expected_suffix, h1:sub(-#expected_suffix))
  end)

  it('increases the mastered count as commands are mastered', function()
    local before = progress.build(logger.get_all())
    local usage = logger.get_all()
    usage[';'] = entry({ count = 200 })
    local after = progress.build(usage)
    assert.not_equals(before[2], after[2])
  end)
end)

-- ── section heading done/total (#67) ─────────────────────────────────────────

describe('a category section heading', function()
  before_each(setup)
  after_each(teardown)

  it('shows 0 / total when nothing in that category is mastered', function()
    local skills = require('tobira.core.skills')
    local motion_total = 0
    for _, cat in ipairs(skills.tree) do
      if cat.id == 'motion' then
        motion_total = #cat.items
      end
    end
    local lines = progress.build(logger.get_all())
    assert.is_true(lines_contain(lines, '0 / ' .. motion_total))
  end)

  it('increments done when a command in that category reaches mastery level 2', function()
    local usage = logger.get_all()
    usage[';'] = entry({ count = 200 })
    local lines = progress.build(usage)
    assert.is_true(lines_contain(lines, '1 / '))
  end)
end)

-- ── level-0 dim styling (#67) ─────────────────────────────────────────────────

describe('when a skill has never been tried (mastery level 0)', function()
  before_each(setup)
  after_each(teardown)

  it('the cell is highlighted with TobiraDim, not a mastery group', function()
    local lines, hls = progress.build(logger.get_all())
    local row = select(1, find_pos(lines, ';')) - 1 -- 0-indexed lnum
    local found_dim = false
    for _, h in ipairs(hls) do
      if h.lnum == row and h.group == 'TobiraDim' then
        found_dim = true
      end
      assert.not_equals('TobiraGuideMastered', h.group)
    end
    assert.is_true(found_dim, 'expected a TobiraDim highlight on the never-tried row')
  end)
end)

-- ── preview strip: M.preview_lines (#67) ─────────────────────────────────────

describe('M.preview_lines when no item is under the cursor', function()
  it('returns two blank lines', function()
    local l1, l2 = progress.preview_lines(nil, {})
    assert.equals('', l1)
    assert.equals('', l2)
  end)
end)

describe('M.preview_lines for a never-tried item', function()
  it('shows the never_tried status tag', function()
    local skills = require('tobira.core.skills')
    local item = { id = ';', keys = ';', adopted = ';' }
    local loc = require('tobira.i18n').load()
    local _, l2 = progress.preview_lines(item, {})
    assert.is_not_nil(l2:find(loc.progress.preview.never_tried, 1, true))
    assert.same(skills.tree[1] ~= nil, true) -- sanity: skills module loaded
  end)
end)

describe('M.preview_lines for a learning item (used, not mastered)', function()
  it('shows the learning status tag and distance to the next milestone', function()
    local loc = require('tobira.i18n').load()
    local item = { id = ';', keys = ';', adopted = ';' }
    local usage = { [';'] = entry({ count = 50 }) }
    local _, l2 = progress.preview_lines(item, usage)
    assert.is_not_nil(l2:find(loc.progress.preview.learning, 1, true))
    assert.is_not_nil(l2:find('50', 1, true))
    -- 50 more to reach the level-2 threshold (100)
    assert.is_not_nil(l2:find(loc.progress.preview.to_next:format(50, '★'), 1, true))
  end)
end)

describe('M.preview_lines for a mastered item', function()
  it('shows the mastered status tag and no distance text', function()
    local loc = require('tobira.i18n').load()
    local item = { id = ';', keys = ';', adopted = ';' }
    local usage = { [';'] = entry({ count = 5000 }) }
    local _, l2 = progress.preview_lines(item, usage)
    assert.is_not_nil(l2:find(loc.progress.preview.mastered, 1, true))
    assert.is_nil(l2:find('more to reach', 1, true))
  end)
end)

describe('M.preview_lines for a forgotten item', function()
  it('shows the forgotten status tag', function()
    local loc = require('tobira.i18n').load()
    local item = { id = ';', keys = ';', adopted = ';' }
    local usage = { [';'] = entry({ count = 200, sessions = { 8, 9, 0, 0 } }) }
    local _, l2 = progress.preview_lines(item, usage)
    assert.is_not_nil(l2:find(loc.progress.preview.forgotten, 1, true))
  end)

  it('shows no distance text once count is already past every threshold', function()
    -- is_mastered() is false here (forgotten overrides it), so the distance
    -- block runs, but count=5000 is past every entry in THRESHOLDS — covers
    -- next_milestone()'s "no more milestones" return.
    local item = { id = ';', keys = ';', adopted = ';' }
    local usage = { [';'] = entry({ count = 5000, sessions = { 8, 9, 0, 0 } }) }
    local _, l2 = progress.preview_lines(item, usage)
    assert.is_nil(l2:find('more to reach', 1, true))
  end)
end)

describe('M.preview_lines for a composite item', function()
  it('does not error and shows the composite label', function()
    local item = { id = 'hjkl', keys = 'hjkl', track = { 'h', 'j', 'k', 'l' } }
    local ok, l1 = pcall(progress.preview_lines, item, {})
    assert.is_true(ok)
    assert.is_not_nil(l1:find('hjkl', 1, true))
  end)
end)

describe('M.preview_lines for an item with a title in the locale', function()
  it('shows the description part of the title, not the raw title', function()
    local loc = require('tobira.i18n').load()
    local item = { id = 'cw', keys = 'cw', adopted = 'cw' }
    local l1 = progress.preview_lines(item, {})
    local desc = loc.suggestions.cw.title:match(' — (.+)$')
    assert.is_not_nil(l1:find(desc, 1, true))
  end)
end)

-- ── preview strip: live update on cursor move (#67) ──────────────────────────

describe('when the cursor moves onto a skill cell in the open window', function()
  before_each(setup)
  after_each(teardown)

  it('updates the preview strip to describe that item', function()
    local usage = logger.get_all()
    usage[';'] = entry({ count = 50 })
    progress.open()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row, col = find_pos(lines, ';')
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.api.nvim_exec_autocmds('CursorMoved', { buffer = buf })

    local updated = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_true(lines_contain(updated, '50'))
  end)

  it('reverts to blank preview lines when the cursor leaves every cell', function()
    local usage = logger.get_all()
    usage[';'] = entry({ count = 50 })
    progress.open()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row, col = find_pos(lines, ';')
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.api.nvim_exec_autocmds('CursorMoved', { buffer = buf })

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_exec_autocmds('CursorMoved', { buffer = buf })
    local reverted = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_false(lines_contain(reverted, '50'))
  end)
end)

-- ── footer nav hint (#67) ─────────────────────────────────────────────────────

local function win_footer_str(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if type(cfg.footer) == 'string' then
    return cfg.footer
  end
  local s = ''
  if type(cfg.footer) == 'table' then
    for _, chunk in ipairs(cfg.footer) do
      s = s .. chunk[1]
    end
  end
  return s
end

describe('the footer', function()
  before_each(setup)
  after_each(teardown)

  it('pins the keybindings to the window footer so they stay visible while scrolling', function()
    progress.open()
    local footer = win_footer_str(vim.fn.win_getid())
    assert.is_true(#footer > 0, 'expected a non-empty window footer')
  end)

  it('renders each key in the accent highlight, next to its localized label', function()
    local loc = require('tobira.i18n').load()
    progress.open()
    local chunks = vim.api.nvim_win_get_config(vim.fn.win_getid()).footer
    assert.is_table(chunks)
    local accent_keys = {}
    for _, chunk in ipairs(chunks) do
      if chunk[2] == 'TobiraGuideKey' then
        accent_keys[chunk[1]] = true
      end
    end
    for _, key in ipairs({ 'x', 'p', 'g', 's', 'q' }) do
      assert.is_true(accent_keys[key] == true, 'expected key ' .. key .. ' as an accent chunk in the footer')
    end
    local footer = win_footer_str(vim.fn.win_getid())
    assert.is_true(
      footer:find(loc.progress.footer.suppress, 1, true) ~= nil,
      'expected the suppress label in the footer'
    )
    assert.is_true(footer:find(loc.progress.footer.close, 1, true) ~= nil, 'expected the close label in the footer')
  end)

  it('does not also render the footer labels inside the scrollable buffer', function()
    local loc = require('tobira.i18n').load()
    local lines = progress.build(logger.get_all())
    assert.is_false(
      lines_contain(lines, loc.progress.footer.suppress),
      'footer labels should be a fixed footer, not buffer content'
    )
  end)
end)

-- ── g / s navigation keymaps (#67) ────────────────────────────────────────────

describe('when g is pressed in the progress window', function()
  before_each(setup)
  after_each(teardown)

  it('closes progress and opens the guide panel', function()
    local called = false
    package.loaded['tobira.ui.guide'] = {
      open = function()
        called = true
      end,
    }
    progress.open()
    local ok, err = pcall(function()
      vim.fn.feedkeys('g', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    package.loaded['tobira.ui.guide'] = nil
    assert.is_true(ok, err)
    assert.is_true(called, 'expected guide.open() to be called')
    assert.is_false(progress.is_open())
  end)
end)

describe('when s is pressed in the progress window', function()
  before_each(setup)
  after_each(teardown)

  it('closes progress and opens the stats panel', function()
    local called = false
    package.loaded['tobira.ui.stats'] = {
      open = function()
        called = true
      end,
    }
    progress.open()
    local ok, err = pcall(function()
      vim.fn.feedkeys('s', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
    package.loaded['tobira.ui.stats'] = nil
    assert.is_true(ok, err)
    assert.is_true(called, 'expected stats.open() to be called')
    assert.is_false(progress.is_open())
  end)
end)
