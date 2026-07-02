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

-- ── lifecycle ──────────────────────────────────────────────────────────────

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

-- ── keys on non-skill rows ────────────────────────────────────────────────

describe('when x is pressed on a non-skill row (e.g., the header)', function()
  before_each(setup)
  after_each(teardown)

  it('does not crash', function()
    progress.open()
    -- Move cursor to row 1 (the blank header line, no skill item).
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

-- ── q / Esc to close ─────────────────────────────────────────────────────

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

-- ── next suggestion shown when available ─────────────────────────────────

describe('when a suitable next suggestion exists', function()
  before_each(setup)
  after_each(teardown)

  it('opens without error and the window is present', function()
    local usage = logger.get_all()
    usage['f'] = { count = 5, sessions = {}, shown = 0, suppressed = false, pinned = false }
    assert.has_no_error(function()
      progress.open()
    end)
    assert.is_true(progress.is_open())
  end)
end)

describe('when no suggestion is available', function()
  before_each(setup)
  after_each(teardown)

  it('opens without error (Next section is simply absent)', function()
    assert.has_no_error(function()
      progress.open()
    end)
    assert.is_true(progress.is_open())
  end)
end)

-- ── mastery symbol rendering ─────────────────────────────────────────────────
-- Auto motion items (;, , etc.) sit in row 6 of the window and have adopted=cmd.
-- Setting their logger count drives mastery_sym() into the relevant branch.

local function open_with_semicolon(count, suppressed, pinned)
  local usage = logger.get_all()
  usage[';'] = { count = count, sessions = {}, shown = 0, suppressed = suppressed or false, pinned = pinned or false }
  progress.open()
  local buf = vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function lines_contain(lines, text)
  for _, line in ipairs(lines) do
    if line:find(text, 1, true) then
      return true
    end
  end
  return false
end

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

describe('when an adopted motion skill is pinned', function()
  before_each(setup)
  after_each(teardown)

  it('renders the pin marker on the skill row', function()
    local lines = open_with_semicolon(5, false, true)
    assert.is_true(lines_contain(lines, ';*'))
  end)
end)

-- ── x / p key on adopted skill row (refresh path) ───────────────────────────
-- The progress window layout for the motion category:
--   row 1: blank
--   row 2: Level: ...
--   row 3: blank
--   row 4: Motion header
--   row 5: composite items (hjkl, w/b, gg/G, f/t) — no adopted field
--   row 6: auto items 1-4 ($, %, (, ))
--   row 7: auto items 5-8 (,, ;, <C-]>, <C-^>)
--
-- ';' is the 2nd cell in row 7.  Col 18 → cell_idx = floor((18-2)/14)+1 = 2.
-- Col 0 on row 7 → cell_idx = 0 (< 1) → item_at_cursor returns nil.

describe('when x is pressed on an adopted skill row at a valid column', function()
  before_each(setup)
  after_each(teardown)

  it('suppresses the skill and refreshes the window (still open)', function()
    progress.open()
    assert.is_false(logger.get(';').suppressed)
    vim.api.nvim_win_set_cursor(0, { 7, 18 })
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
    progress.open()
    vim.api.nvim_win_set_cursor(0, { 7, 0 })
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
    progress.open()
    assert.is_false(logger.get(';').pinned)
    vim.api.nvim_win_set_cursor(0, { 7, 18 })
    vim.fn.feedkeys('p', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(progress.is_open())
    assert.is_true(logger.get(';').pinned)
  end)
end)
