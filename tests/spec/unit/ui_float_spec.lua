local float = require('tobira.ui.float')
local logger = require('tobira.core.logger')

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
