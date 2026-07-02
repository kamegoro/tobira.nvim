-- Pure render tests for :TobiraGuide. Mirrors ui/stats.lua's pattern:
-- M.build(usage) is pure (no logger.get_all() call inside it), so layout can
-- be asserted without opening a real window.
local guide = require('tobira.ui.guide')

local function entry(overrides)
  local base = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false }
  for k, v in pairs(overrides or {}) do
    base[k] = v
  end
  return base
end

local function lines_of(lines)
  return lines
end

local function find_line(lines, needle)
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) then
      return line
    end
  end
  return nil
end

local function find_hl(hls, lnum, group)
  for _, h in ipairs(hls) do
    if h.lnum == lnum and h.group == group then
      return h
    end
  end
  return nil
end

-- ── empty state ───────────────────────────────────────────────────────────────

describe('when there is nothing pinned and every command is mastered', function()
  it('renders the all_mastered message', function()
    local commands = require('tobira.commands')
    local usage = {}
    for cmd, e in pairs(commands.registry) do
      if not e.compound then
        usage[cmd] = entry({ count = 200 })
      end
    end
    local lines = guide.build(usage)
    assert.is_not_nil(find_line(lines, 'mastered'))
  end)
end)

-- ── pinned section ────────────────────────────────────────────────────────────

describe('when a command is pinned', function()
  it('renders it under the Pinned heading with a ● marker', function()
    local usage = { ['ciw'] = entry({ pinned = true }) }
    local lines, hls = guide.build(usage)
    assert.is_not_nil(find_line(lines, 'Pinned'))
    local row = find_line(lines, 'ciw')
    assert.is_not_nil(row, 'expected a row containing ciw')
    assert.is_not_nil(row:find('●', 1, true), 'expected a ● marker on the pinned row')
  end)

  it('is excluded from its category auto section (no duplication)', function()
    local usage = { ['ciw'] = entry({ pinned = true, count = 0 }) }
    local lines = guide.build(usage)
    local count = 0
    for _, line in ipairs(lines) do
      if line:find('ciw', 1, true) then
        count = count + 1
      end
    end
    assert.equals(1, count, 'ciw should appear exactly once, not once per section')
  end)

  it('renders even when the auto section has no items to show', function()
    local commands = require('tobira.commands')
    local usage = { ['ciw'] = entry({ pinned = true, count = 200 }) }
    for cmd, e in pairs(commands.registry) do
      if not e.compound and cmd ~= 'ciw' then
        usage[cmd] = entry({ count = 200 })
      end
    end
    local lines = guide.build(usage)
    assert.is_not_nil(find_line(lines, 'Pinned'))
    assert.is_not_nil(find_line(lines, 'ciw'))
  end)
end)

-- ── mastery-symbol column (#68) ──────────────────────────────────────────────

describe('when a command has never been tried (mastery level 0)', function()
  it('renders the row with TobiraDim and no glyph', function()
    local usage = { [';'] = entry({ count = 0 }) }
    local lines, hls = guide.build(usage)
    local row_lnum = nil
    for i, line in ipairs(lines) do
      if line:find(';', 1, true) then
        row_lnum = i - 1
      end
    end
    assert.is_not_nil(row_lnum, 'expected a row for ;')
    assert.is_not_nil(find_hl(hls, row_lnum, 'TobiraDim'))
    assert.is_nil(find_hl(hls, row_lnum, 'TobiraGuideMastered'))
    assert.is_nil(find_hl(hls, row_lnum, 'TobiraGuideForgotten'))
  end)
end)

describe('when a command has been tried but not mastered (level 1)', function()
  it('renders a ☆ glyph with TobiraGuideHint', function()
    local usage = { [';'] = entry({ count = 5 }) }
    local lines, hls = guide.build(usage)
    local row = find_line(lines, ';')
    assert.is_not_nil(row)
    assert.is_not_nil(row:find('☆', 1, true))
  end)
end)

-- A "level >= 2 and not forgotten" row never reaches the auto section at all:
-- guide_commands() only includes rows where is_mastered(data) == false, and
-- is_mastered is `mastery_level >= 2 and not is_forgotten`. So a mastery_level
-- >= 2 row that made it into the auto section is always forgotten, and the
-- forgotten test group below already covers that combination. Regression
-- guard for the exclusion itself lives in graph_spec.lua ("still excludes a
-- command that is mastered and not forgotten").

-- ── forgotten state (#68) ────────────────────────────────────────────────────

describe('when a command was mastered but is now forgotten', function()
  local forgotten_data = { count = 200, sessions = { 8, 9, 0, 0 }, shown = 0, suppressed = false, pinned = false }

  it('reappears in the auto section instead of staying excluded', function()
    local lines = guide.build({ [';'] = forgotten_data })
    assert.is_not_nil(find_line(lines, ';'))
  end)

  it('renders the ⟳ glyph with TobiraGuideForgotten, not ★', function()
    local lines, hls = guide.build({ [';'] = forgotten_data })
    local row_lnum, row
    for i, line in ipairs(lines) do
      if line:find(';', 1, true) then
        row_lnum, row = i - 1, line
      end
    end
    assert.is_not_nil(row:find('⟳', 1, true))
    assert.is_nil(row:find('★', 1, true))
    assert.is_not_nil(find_hl(hls, row_lnum, 'TobiraGuideForgotten'))
  end)

  it('appends the forgotten_suffix to the description', function()
    local loc = require('tobira.i18n').load()
    local lines = guide.build({ [';'] = forgotten_data })
    local row = find_line(lines, ';')
    assert.is_not_nil(row:find(loc.guide.forgotten_suffix, 1, true))
  end)

  it('still shows the count', function()
    local lines = guide.build({ [';'] = forgotten_data })
    local row = find_line(lines, ';')
    assert.is_not_nil(row:find('200×', 1, true))
  end)
end)

-- ── count column (#68) ───────────────────────────────────────────────────────

describe('when a command has a non-zero count', function()
  it('shows the count suffixed with ×', function()
    local lines = guide.build({ [';'] = entry({ count = 88 }) })
    local row = find_line(lines, ';')
    assert.is_not_nil(row:find('88×', 1, true))
  end)
end)

describe('when a command has never been used (count = 0)', function()
  it('shows no count text', function()
    local lines = guide.build({ [';'] = entry({ count = 0 }) })
    local row = find_line(lines, ';')
    assert.is_nil(row:find('0×', 1, true))
  end)
end)

describe('count column alignment', function()
  it('stays right-aligned across rows with different key lengths', function()
    -- ';' (1 char) and '<C-w>w' (6 chars) both have registry entries; force
    -- both to be visible (tried, not mastered) and compare the × column index.
    local usage = {
      [';'] = entry({ count = 12 }),
      ['<C-w>w'] = entry({ count = 34 }),
    }
    local lines = guide.build(usage)
    local row1 = find_line(lines, '12×')
    local row2 = find_line(lines, '34×')
    assert.is_not_nil(row1)
    assert.is_not_nil(row2)
    local _, pos1 = row1:find('×', 1, true)
    local _, pos2 = row2:find('×', 1, true)
    assert.equals(pos1, pos2, 'the × column should land at the same byte offset on both rows')
  end)
end)

-- ── footer (#68) ─────────────────────────────────────────────────────────────

describe('the footer', function()
  it('contains a separator line above the hint', function()
    local lines = guide.build({})
    local sep_lnum, hint_lnum
    for i, line in ipairs(lines) do
      if line:find('───', 1, true) then
        sep_lnum = i
      end
      if line:find('<C%-w>w', 1, false) then
        hint_lnum = i
      end
    end
    assert.is_not_nil(sep_lnum, 'expected a separator line')
    assert.is_not_nil(hint_lnum, 'expected the focus_hint line')
    assert.is_true(sep_lnum < hint_lnum, 'separator should come before the hint')
  end)

  it('uses the focus_hint locale string', function()
    local loc = require('tobira.i18n').load()
    local lines = guide.build({})
    assert.is_not_nil(find_line(lines, loc.guide.focus_hint))
  end)
end)

-- ── regression: existing behavior preserved ─────────────────────────────────

describe('category ordering (regression)', function()
  it('renders categories in the fixed CATEGORY_ORDER, skipping empty ones', function()
    local commands = require('tobira.commands')
    local usage = {}
    -- Master every category except motion and edit, so only those two show.
    for cmd, e in pairs(commands.registry) do
      if not e.compound and e.category ~= 'motion' and e.category ~= 'edit' then
        usage[cmd] = entry({ count = 200 })
      end
    end
    local lines = guide.build(usage)
    local motion_lnum, edit_lnum
    for i, line in ipairs(lines) do
      if line == '  Motion' then
        motion_lnum = i
      end
      if line == '  Edit' then
        edit_lnum = i
      end
    end
    assert.is_not_nil(motion_lnum)
    assert.is_not_nil(edit_lnum)
    assert.is_true(motion_lnum < edit_lnum, 'Motion should render before Edit')
  end)
end)

describe('auto-refresh when switching windows (regression)', function()
  it('schedules a refresh when a different window becomes current', function()
    guide.open()

    local called = false
    local orig_refresh = guide.refresh
    guide.refresh = function()
      called = true
      orig_refresh()
    end

    -- :new always switches into a brand-new window, guaranteed different from
    -- both whatever was current before and from guide's own window.
    local ok, err = pcall(function()
      vim.cmd('new')
      vim.wait(200, function()
        return called
      end, 10)
    end)
    local new_win = vim.api.nvim_get_current_win()

    guide.refresh = orig_refresh
    guide.close()
    pcall(vim.api.nvim_win_close, new_win, true)

    assert.is_true(ok, err)
    assert.is_true(called, 'expected switching to another window to schedule a refresh')
  end)

  it('does not error when the guide window itself becomes current (guard clause)', function()
    guide.open()
    local guide_win = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'tobira_guide' then
        guide_win = win
      end
    end
    assert.is_not_nil(guide_win, 'expected to find the open guide window')

    local ok = pcall(function()
      vim.api.nvim_set_current_win(guide_win)
      vim.wait(50, function()
        return false
      end, 10)
    end)

    guide.close()
    assert.is_true(ok)
  end)
end)

describe('M.open / M.close / M.toggle (regression)', function()
  after_each(function()
    guide.close()
  end)

  it('opens a non-focusable floating window', function()
    guide.open()
    assert.is_true(guide.is_open())
  end)

  it('opens when toggled while closed', function()
    assert.is_false(guide.is_open())
    guide.toggle()
    assert.is_true(guide.is_open())
  end)

  it('closes when toggled a second time', function()
    guide.open()
    guide.toggle()
    assert.is_false(guide.is_open())
  end)

  it('is a no-op when open() is called while already open', function()
    guide.open()
    assert.has_no_error(function()
      guide.open()
    end)
    assert.is_true(guide.is_open())
  end)

  it('does nothing when refresh() is called while closed', function()
    assert.has_no_error(function()
      guide.refresh()
    end)
  end)

  it('re-renders the buffer content when refresh() is called while open', function()
    local logger = require('tobira.core.logger')
    logger.reset()
    guide.open()
    logger.set_pinned(';', true)
    guide.refresh()

    local buf = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].filetype == 'tobira_guide' then
        buf = b
      end
    end
    assert.is_not_nil(buf, 'expected to find the open guide buffer')

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local found = false
    for _, line in ipairs(lines) do
      if line:find(';', 1, true) and line:find('●', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected the pinned ; row to appear after refresh')
    logger.reset()
  end)
end)
