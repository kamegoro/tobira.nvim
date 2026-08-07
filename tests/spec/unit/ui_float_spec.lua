local float = require('tobira.ui.float')
local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

local function suggestion(cmd, extra)
  local sug = { cmd = cmd }
  if extra then
    for k, v in pairs(extra) do
      sug[k] = v
    end
  end
  return sug
end

-- Captures every vim.defer_fn call made during fn() (there is exactly one per
-- float.show/celebrate call: the auto-close timer). Avoids hardcoding a
-- specific delay value, since duration now scales with content length.
local function capture_defer(fn)
  local captured = {}
  local orig_defer = vim.defer_fn
  vim.defer_fn = function(cb, delay)
    table.insert(captured, { fn = cb, delay = delay })
  end
  local ok, err = pcall(fn)
  vim.defer_fn = orig_defer
  assert.is_true(ok, err)
  return captured
end

local function get_open_buf_lines()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].bufhidden == 'wipe' then
      return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end
  end
  return {}
end

local function get_open_buf()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].bufhidden == 'wipe' then
      return buf
    end
  end
  return nil
end

local _data_file = vim.fn.stdpath('data') .. '/tobira/usage.json'
local function wipe_disk()
  pcall(os.remove, _data_file)
end

local function setup()
  wipe_disk()
  logger.reset()
  logger.setup()
  float.close()
  vim.cmd('enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
end

local function teardown()
  float.close()
  logger.reset()
end

-- show / close

describe('when a suggestion float is shown', function()
  before_each(setup)
  after_each(teardown)

  it('opens a window', function()
    float.show(suggestion(';'), true)
    assert.is_true(float.is_open())
  end)

  it('does not crash when the command has no locale string', function()
    assert.has_no_error(function()
      float.show(suggestion('__no_such_cmd__'), true)
    end)
    assert.is_false(float.is_open(), 'expected no window for unknown command')
  end)

  it('replaces an existing float when called twice', function()
    float.show(suggestion(';'), true)
    float.show(suggestion('cw'), true)
    assert.is_true(float.is_open())
  end)
end)

describe('when M.close() is called', function()
  before_each(setup)
  after_each(teardown)

  it('removes the float window', function()
    float.show(suggestion(';'), true)
    float.close()
    assert.is_false(float.is_open())
  end)

  it('is idempotent when no float is open', function()
    assert.has_no_error(function()
      float.close()
      float.close()
    end)
  end)
end)

-- non-focused (auto suggestion)

describe('when the float is shown without focus (auto suggestion)', function()
  before_each(setup)
  after_each(teardown)

  it('opens a window without stealing the cursor', function()
    local prev = vim.api.nvim_get_current_win()
    float.show(suggestion(';'), false)
    assert.is_true(float.is_open())
    assert.equals(prev, vim.api.nvim_get_current_win())
  end)

  it('does not suppress the command when the timer fires', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), false)
    end)
    captured[1].fn()
    assert.is_false(float.is_open())
    assert.is_false(logger.get(';').suppressed)
  end)
end)

-- q key: dismiss without suppressing (focused float only)

describe('when the user presses q on the suggestion float', function()
  before_each(setup)
  after_each(teardown)

  it('closes the float', function()
    float.show(suggestion(';'), true)
    vim.fn.feedkeys('q', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(float.is_open())
  end)

  it('does not suppress the command', function()
    float.show(suggestion(';'), true)
    vim.fn.feedkeys('q', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(logger.get(';').suppressed)
  end)
end)

-- <C-c>: dismiss without suppressing (focused float only)

describe('when <C-c> is pressed on the suggestion float', function()
  before_each(setup)
  after_each(teardown)

  it('closes the float', function()
    local ctrl_c = vim.api.nvim_replace_termcodes('<C-c>', true, false, true)
    float.show(suggestion(';'), true)
    vim.fn.feedkeys(ctrl_c, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(float.is_open())
  end)

  it('does not suppress the command', function()
    local ctrl_c = vim.api.nvim_replace_termcodes('<C-c>', true, false, true)
    float.show(suggestion(';'), true)
    vim.fn.feedkeys(ctrl_c, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(logger.get(';').suppressed)
  end)
end)

-- auto-close timer

describe('when the auto-close timer fires', function()
  before_each(setup)
  after_each(teardown)

  it('closes the float when the token still matches', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
    end)

    assert.is_true(float.is_open())
    assert.equals(1, #captured)
    captured[1].fn()
    assert.is_false(float.is_open())
  end)

  it('is a no-op when the float was already dismissed', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
    end)
    float.close()

    assert.has_no_error(function()
      captured[1].fn()
    end)
    assert.is_false(float.is_open())
  end)
end)

describe('auto-close duration', function()
  before_each(setup)
  after_each(teardown)

  it('stays within the 6s–9s toast convention regardless of content length', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
    end)
    assert.is_true(captured[1].delay >= 6000, 'duration should be at least 6000ms')
    assert.is_true(captured[1].delay <= 9000, 'duration should be at most 9000ms')
  end)

  it('grows when the suggestion has a reason line', function()
    local without = capture_defer(function()
      float.show(suggestion(';'), true)
    end)
    float.close()
    local with_reason = capture_defer(function()
      float.show(suggestion(';'), true, 'f_repeat')
    end)
    assert.is_true(with_reason[1].delay > without[1].delay)
  end)
end)

-- terminal_esc_repeat's audience is still mid-struggle, not idle;
-- see docs/adr/0081-terminal-category-auto-dismiss-duration.md for why
describe('auto-close duration for the terminal category (#166)', function()
  before_each(setup)
  after_each(teardown)

  it('outlasts the standard 9s ceiling used by every other category', function()
    local captured = capture_defer(function()
      float.show(suggestion(';', { category = 'terminal' }), false)
    end)
    assert.is_true(captured[1].delay > 9000, 'terminal-category suggestions should outlast the standard ceiling')
  end)

  it('does not change the duration for any other category', function()
    local captured = capture_defer(function()
      float.show(suggestion(';', { category = 'motion' }), true)
    end)
    assert.is_true(captured[1].delay <= 9000, 'non-terminal categories must keep the standard 6-9s ceiling')
  end)

  it('does not change the duration when there is no category at all', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
    end)
    assert.is_true(captured[1].delay <= 9000, 'uncategorized suggestions must keep the standard 6-9s ceiling')
  end)
end)

-- brand icon

describe('the suggestion title', function()
  before_each(setup)
  after_each(teardown)

  it('always includes the door brand icon', function()
    float.show(suggestion(';'), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    local title_str = ''
    if type(cfg.title) == 'string' then
      title_str = cfg.title
    else
      for _, chunk in ipairs(cfg.title) do
        title_str = title_str .. chunk[1]
      end
    end
    assert.is_true(title_str:find('🚪', 1, true) ~= nil, 'expected the door icon in the float title')
  end)
end)

-- "why now" reason line

describe('when a pattern name is passed to show', function()
  before_each(setup)
  after_each(teardown)

  it('renders the matching reason text from locale float.reasons', function()
    float.show(suggestion(';'), true, 'f_repeat')
    local lines = get_open_buf_lines()
    local found = false
    for _, line in ipairs(lines) do
      if line:find('repeated the same f/t search', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected the f_repeat reason text in the buffer')
  end)
end)

describe('when no pattern is passed but the suggestion has a trigger', function()
  before_each(setup)
  after_each(teardown)

  it('renders the generic ambient_reason template with the trigger substituted', function()
    float.show(suggestion(';', { trigger = 'f' }), true)
    local lines = get_open_buf_lines()
    local found = false
    for _, line in ipairs(lines) do
      if line:find('You often use f', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected the ambient reason text in the buffer')
  end)
end)

describe('when neither a pattern nor a trigger is available', function()
  before_each(setup)
  after_each(teardown)

  it('shows no reason line without erroring', function()
    assert.has_no_error(function()
      float.show(suggestion(';'), true)
    end)
    assert.is_true(float.is_open())
  end)
end)

-- extmark-based highlighting (nvim_buf_add_highlight migration)
-- Every highlight this module applies is a full-line highlight (old
-- col_end == -1). Confirms the new nvim_buf_set_extmark()-based call
-- actually reaches the real end of each line's text, not just column 0.

describe('extmark rendering after the nvim_buf_add_highlight migration (#151)', function()
  before_each(setup)
  after_each(teardown)

  local function full_line_extmark(buf, lnum)
    local ns = vim.api.nvim_create_namespace('tobira_float')
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { lnum, 0 }, { lnum, -1 }, { details = true })
    return marks[1]
  end

  it('highlights the reason line through its real end column, not just column 0', function()
    float.show(suggestion(';'), true, 'f_repeat')
    local buf = get_open_buf()
    assert.is_not_nil(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local reason_lnum
    for i, line in ipairs(lines) do
      if line:find('repeated the same f/t search', 1, true) then
        reason_lnum = i - 1
      end
    end
    assert.is_not_nil(reason_lnum, 'expected to find the reason line')

    local mark = full_line_extmark(buf, reason_lnum)
    assert.is_not_nil(mark, 'expected an extmark on the reason line')
    local details = mark[4]
    assert.equals('TobiraSuggestReason', details.hl_group)
    assert.equals(reason_lnum, details.end_row)
    assert.equals(#lines[reason_lnum + 1], details.end_col)
  end)

  it('highlights the footer hint line through its real end column', function()
    float.show(suggestion(';'), true)
    local buf = get_open_buf()
    assert.is_not_nil(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local hint_lnum = #lines - 2 -- footer line is second-to-last (a blank line follows it)

    local mark = full_line_extmark(buf, hint_lnum)
    assert.is_not_nil(mark, 'expected an extmark on the footer hint line')
    local details = mark[4]
    assert.equals('TobiraGuideHint', details.hl_group)
    assert.equals(hint_lnum, details.end_row)
    assert.equals(#lines[hint_lnum + 1], details.end_col)
  end)

  it('highlights the celebrate line through its real end column', function()
    float.celebrate(';')
    local buf = get_open_buf()
    assert.is_not_nil(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local mark = full_line_extmark(buf, 1)
    assert.is_not_nil(mark, 'expected an extmark on the celebrate line')
    local details = mark[4]
    assert.equals('TobiraCelebrate', details.hl_group)
    assert.equals(1, details.end_row)
    assert.equals(#lines[2], details.end_col)
  end)
end)

-- persistent mute hint

describe('the mute hint', function()
  before_each(setup)
  after_each(teardown)

  it('is shown even for an unfocused (ambient) suggestion', function()
    float.show(suggestion(';'), false)
    local lines = get_open_buf_lines()
    local found = false
    for _, line in ipairs(lines) do
      if line:find('TobiraProgress', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected the mute hint even without focus')
  end)

  it('also shows the close hint when focused', function()
    float.show(suggestion(';'), true)
    local lines = get_open_buf_lines()
    local found = false
    for _, line in ipairs(lines) do
      if line:find('TobiraProgress', 1, true) and line:find('close', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected both hints combined on the focused footer line')
  end)
end)

-- category border color

describe('when the suggestion has a category', function()
  before_each(setup)
  after_each(teardown)

  it('colors the border with the matching TobiraSuggest* highlight group', function()
    float.show(suggestion(';', { category = 'motion' }), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    local border_hl = cfg.border[1][2]
    assert.equals('TobiraSuggestMotion', border_hl)
  end)

  it('colors the border with TobiraSuggestEx for the ex category (#57)', function()
    float.show(suggestion(';', { category = 'ex' }), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    local border_hl = cfg.border[1][2]
    assert.equals('TobiraSuggestEx', border_hl)
  end)
end)

describe('when the suggestion has no category', function()
  before_each(setup)
  after_each(teardown)

  it('falls back to the default float border', function()
    float.show(suggestion(';'), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    local border_hl = cfg.border[1][2]
    assert.equals('FloatBorder', border_hl)
  end)
end)

-- border chars must stay single-cell;
-- see docs/adr/0080-suggestion-float-border-ambiwidth-double-fallback.md for why

describe('when ambiwidth is double', function()
  before_each(setup)
  after_each(teardown)

  it('does not error opening the suggestion float', function()
    local orig = vim.o.ambiwidth
    vim.o.ambiwidth = 'double'
    local ok, err = pcall(function()
      float.show(suggestion(';'), true)
    end)
    vim.o.ambiwidth = orig
    assert.is_true(ok, err)
  end)

  it('uses single-cell characters for every border segment', function()
    local orig = vim.o.ambiwidth
    vim.o.ambiwidth = 'double'
    local ok, cfg_or_err = pcall(function()
      float.show(suggestion(';'), true)
      local win = vim.fn.win_getid()
      return vim.api.nvim_win_get_config(win)
    end)
    vim.o.ambiwidth = orig
    assert.is_true(ok, cfg_or_err)
    for _, segment in ipairs(cfg_or_err.border) do
      assert.equals(1, vim.fn.strdisplaywidth(segment[1]), 'border char ' .. segment[1] .. ' must be single-cell')
    end
  end)
end)

describe('when ambiwidth is the default (single)', function()
  before_each(setup)
  after_each(teardown)

  it('keeps the rounded unicode border', function()
    float.show(suggestion(';'), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    assert.equals('╭', cfg.border[1][1])
  end)
end)

-- celebrate()

describe('when a command is celebrated for the first time', function()
  before_each(setup)
  after_each(teardown)

  it('opens a window without stealing focus', function()
    local prev = vim.api.nvim_get_current_win()
    float.celebrate(';')
    assert.is_true(float.is_open())
    assert.equals(prev, vim.api.nvim_get_current_win())
  end)

  it('shows the celebrate template with the command substituted', function()
    float.celebrate(';')
    local lines = get_open_buf_lines()
    local found = false
    for _, line in ipairs(lines) do
      if line:find(';', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected the celebrated command name in the buffer')
  end)

  it('auto-closes on its own shorter timer', function()
    local captured = capture_defer(function()
      float.celebrate(';')
    end)
    assert.equals(1, #captured)
    assert.is_true(captured[1].delay <= 4000, 'celebration should be brief')
    captured[1].fn()
    assert.is_false(float.is_open())
  end)

  it('replaces an open suggestion float instead of stacking', function()
    float.show(suggestion(';'), true)
    float.celebrate('cw')
    assert.is_true(float.is_open())
  end)
end)

-- Long suggestion bodies wrap instead of clipping. fr's 'g<C-a>' body is the
-- widest across all 6 locales (180 display cells) -- comfortably wider than
-- a realistic 100-120 column terminal, the sharpest repro for silent clipping.

describe('when a suggestion body renders wider than any realistic terminal (#261)', function()
  local orig_columns

  before_each(function()
    setup()
    -- Headless test Neovim defaults &columns to 80 with no UI attached, which
    -- is narrower than float.lua's own screen_w fallback (120) used when
    -- nvim_list_uis() is empty -- Neovim would silently clamp the float to
    -- the real (narrower) screen, decoupling win_h's row math from what
    -- actually renders. A real terminal session always has a UI attached
    -- (uis[1].width matches &columns exactly), so this is a test-environment
    -- adjustment, not a production behavior change.
    orig_columns = vim.o.columns
    vim.o.columns = 200
  end)
  after_each(function()
    vim.o.columns = orig_columns
    config.reset()
    teardown()
  end)

  it('turns line wrap on instead of clipping the text', function()
    config.setup({ lang = 'fr' })
    float.show(suggestion('g<C-a>'), true)
    local win = vim.fn.win_getid()
    assert.is_true(vim.wo[win].wrap, 'expected the suggestion float to wrap long lines instead of clipping them')
  end)

  it('caps the window width at a sane reading width instead of growing to fit the longest line', function()
    config.setup({ lang = 'fr' })
    float.show(suggestion('g<C-a>'), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    -- the widest unwrapped fr line is 180 cells; a capped width must stay
    -- far below that, or the "cap" isn't doing anything
    assert.is_true(cfg.width < 150, 'expected the float width to be capped well below the widest unwrapped line')
  end)

  it('grows the window height so every wrapped row is visible, not clipped off the bottom', function()
    config.setup({ lang = 'fr' })
    float.show(suggestion('g<C-a>'), true)
    local win = vim.fn.win_getid()
    local buf = vim.api.nvim_win_get_buf(win)
    local line_count = #vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local rendered_rows = vim.api.nvim_win_text_height(win, {}).all
    local cfg = vim.api.nvim_win_get_config(win)
    assert.is_true(rendered_rows > line_count, 'expected the fr locale g<C-a> body to actually wrap onto extra rows')
    assert.equals(
      rendered_rows,
      cfg.height,
      'window height must match the wrapped row count exactly, or the bottom gets clipped'
    )
  end)

  it('does not widen short, normal-length suggestions to fill the wrap cap', function()
    float.show(suggestion(';'), true)
    local win = vim.fn.win_getid()
    local cfg = vim.api.nvim_win_get_config(win)
    -- 100 is the documented wrap-width cap itself; a short suggestion should
    -- stay sized to its own content well below it, not be force-widened up
    -- to the cap.
    assert.is_true(cfg.width < 100, 'expected a short suggestion to stay sized to its own content, not the wrap cap')
  end)
end)

-- :vsplit leaking a stray, unclosable real window.
-- Splitting from inside the focused float duplicates the scratch buffer into
-- a second, non-floating window while the original floating window is still
-- open, so the buffer-scoped WinLeave autocmd's deferred close() runs after
-- both windows already exist.

describe('when :vsplit duplicates the focused float into a second window (#268)', function()
  before_each(setup)
  after_each(teardown)

  it('shows the scratch buffer in 2 windows immediately after :vsplit', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
      vim.cmd('vsplit')
    end)

    local buf = get_open_buf()
    assert.is_not_nil(buf, 'expected the scratch buffer to still exist right after :vsplit')
    assert.equals(2, #vim.fn.win_findbuf(buf), 'expected :vsplit to duplicate the scratch buffer into a 2nd window')

    -- drain the deferred callbacks so nothing leaks into the next test
    for _, c in ipairs(captured) do
      pcall(c.fn)
    end
  end)

  it('closes every window showing the scratch buffer once the deferred WinLeave-close runs', function()
    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
      vim.cmd('vsplit')
    end)
    assert.equals(2, #captured, 'expected exactly the auto-close timer and the WinLeave-triggered close to be deferred')

    local buf = get_open_buf()

    -- run the deferred close the WinLeave autocmd scheduled (captured[2])
    captured[2].fn()

    assert.equals(0, #vim.fn.win_findbuf(buf), 'expected no window to still show the scratch buffer')
  end)

  it('leaves exactly the windows that existed before :Tobira was invoked', function()
    local before_wins = #vim.api.nvim_list_wins()

    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
      vim.cmd('vsplit')
    end)
    captured[2].fn()

    assert.equals(before_wins, #vim.api.nvim_list_wins(), 'expected :vsplit + close to leave no stray real window behind')
  end)

  it('returns focus to the window the user was in before :Tobira was invoked', function()
    local original_win = vim.api.nvim_get_current_win()

    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
      vim.cmd('vsplit')
    end)
    captured[2].fn()

    assert.equals(original_win, vim.api.nvim_get_current_win())
  end)
end)

-- non-regression: the ordinary single-window WinLeave close path

describe('when the user switches to another window without pressing a close key', function()
  before_each(setup)
  after_each(teardown)

  it('still auto-closes via the WinLeave autocmd', function()
    local original_win = vim.api.nvim_get_current_win()

    local captured = capture_defer(function()
      float.show(suggestion(';'), true)
      vim.api.nvim_set_current_win(original_win)
    end)
    assert.equals(2, #captured, 'expected the auto-close timer and the WinLeave-triggered close to be deferred')

    captured[2].fn()

    assert.is_false(float.is_open())
  end)
end)
