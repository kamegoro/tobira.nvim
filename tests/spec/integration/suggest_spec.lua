local suggest = require('tobira.core.suggest')
local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

local function with_float_spy(fn)
  local called = false
  package.loaded['tobira.ui.float'] = { show = function() called = true end }
  local ok, err = pcall(fn)
  package.loaded['tobira.ui.float'] = nil
  assert.is_true(ok, err)
  return called
end

describe('when a command has been adopted by the user', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('never shows it again', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')

    local shown = with_float_spy(function()
      suggest.show(';')
    end)

    assert.is_false(shown)
  end)
end)

describe('when a command has been shown the maximum number of times without adoption', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('stops showing it', function()
    config.setup({ max_shown = 2 })
    logger.mark_shown(';')
    logger.mark_shown(';')

    local shown = with_float_spy(function()
      suggest.show(';')
    end)

    assert.is_false(shown)
  end)

  it('still shows it when shown count is below the limit', function()
    config.setup({ max_shown = 3 })
    logger.mark_shown(';')
    logger.mark_shown(';')

    local shown = with_float_spy(function()
      suggest.show(';')
    end)

    assert.is_true(shown)
  end)
end)

describe('when :Tobira is called but there is nothing new to suggest', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('notifies the user that they are up to date', function()
    local notified = false
    local orig = vim.notify
    vim.notify = function(msg, _)
      if msg:find('no new suggestions') then
        notified = true
      end
    end
    local ok, err = pcall(suggest.manual)
    vim.notify = orig
    assert.is_true(ok, err)
    assert.is_true(notified)
  end)
end)
