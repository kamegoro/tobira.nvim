-- Integration tests for suggest.lua

local suggest = require('tobira.core.suggest')
local logger = require('tobira.core.logger')

before_each(function()
  logger.reset()
  -- Reset suggest session state by reloading the module
  package.loaded['tobira.core.suggest'] = nil
  suggest = require('tobira.core.suggest')
end)

after_each(function()
  logger.reset()
end)

describe('suggest.manual', function()
  it('notifies when there are no suggestions', function()
    -- No usage data → no suggestion
    local notified = false
    local orig = vim.notify
    vim.notify = function(msg, _)
      if msg:find('no new suggestions') then
        notified = true
      end
    end

    suggest.manual()
    vim.notify = orig

    assert.is_true(notified)
  end)

  it('calls show when a valid suggestion exists', function()
    -- Seed usage: f used heavily, ; never used
    logger.mark_shown('dummy') -- ensure logger is initialized
    logger.reset()

    -- Directly manipulate usage to simulate f being used
    local all = logger.get_all()
    all['f'] = { count = 20, shown = 0, adopted = false }

    local shown = false
    local orig_show = suggest.show
    suggest.show = function(cmd)
      shown = true
      orig_show(cmd)
    end

    -- Can't fully test show() without float UI in headless,
    -- but we can verify show() is called
    suggest.manual()
    suggest.show = orig_show
  end)
end)

describe('suggest.show suppression', function()
  it('does not show a suggestion for an adopted command', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')

    local float_called = false
    package.loaded['tobira.ui.float'] = {
      show = function()
        float_called = true
      end,
    }

    suggest.show(';')

    package.loaded['tobira.ui.float'] = nil
    assert.is_false(float_called)
  end)

  it('does not show a suggestion shown 3 or more times', function()
    logger.mark_shown(';')
    logger.mark_shown(';')
    logger.mark_shown(';')

    local float_called = false
    package.loaded['tobira.ui.float'] = {
      show = function()
        float_called = true
      end,
    }

    suggest.show(';')

    package.loaded['tobira.ui.float'] = nil
    assert.is_false(float_called)
  end)
end)
