local float = require('tobira.ui.float')
local logger = require('tobira.core.logger')

local function suggestion(cmd)
  return { cmd = cmd }
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
    local captured = {}
    local orig_defer = vim.defer_fn
    vim.defer_fn = function(fn, delay)
      if delay == 10000 then
        table.insert(captured, fn)
      else
        orig_defer(fn, delay)
      end
    end
    float.show(suggestion(';'), false)
    vim.defer_fn = orig_defer
    captured[1]()
    assert.is_false(float.is_open())
    assert.is_false(logger.get(';').suppressed)
  end)
end)

-- x key: suppress (focused float only)

describe('when the user presses x on the suggestion float', function()
  before_each(setup)
  after_each(teardown)

  it('suppresses the suggested command', function()
    float.show(suggestion(';'), true)
    vim.fn.feedkeys('x', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get(';').suppressed)
  end)

  it('closes the float', function()
    float.show(suggestion(';'), true)
    vim.fn.feedkeys('x', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(float.is_open())
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

describe('when the 10-second auto-close timer fires', function()
  before_each(setup)
  after_each(teardown)

  it('closes the float when the token still matches', function()
    local captured = {}
    local orig_defer = vim.defer_fn
    vim.defer_fn = function(fn, delay)
      if delay == 10000 then
        table.insert(captured, fn)
      else
        orig_defer(fn, delay)
      end
    end
    float.show(suggestion(';'), true)
    vim.defer_fn = orig_defer

    assert.is_true(float.is_open())
    assert.equals(1, #captured)
    captured[1]()
    assert.is_false(float.is_open())
  end)

  it('is a no-op when the float was already dismissed', function()
    local captured = {}
    local orig_defer = vim.defer_fn
    vim.defer_fn = function(fn, delay)
      if delay == 10000 then
        table.insert(captured, fn)
      else
        orig_defer(fn, delay)
      end
    end
    float.show(suggestion(';'), true)
    vim.defer_fn = orig_defer
    float.close()

    assert.has_no_error(function()
      captured[1]()
    end)
    assert.is_false(float.is_open())
  end)
end)
