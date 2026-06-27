local suggest = require('tobira.core.suggest')
local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

before_each(function()
  logger.reset()
  config.reset()
  package.loaded['tobira.core.suggest'] = nil
  suggest = require('tobira.core.suggest')
end)

after_each(function()
  logger.reset()
  config.reset()
end)

describe('suggest.show suppression', function()
  it('does not show an adopted command', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')

    local float_called = false
    package.loaded['tobira.ui.float'] = { show = function() float_called = true end }

    suggest.show(';')

    package.loaded['tobira.ui.float'] = nil
    assert.is_false(float_called)
  end)

  it('suppresses after max_shown from config', function()
    config.setup({ max_shown = 2 })

    -- Reload suggest so it picks up new config
    package.loaded['tobira.core.suggest'] = nil
    suggest = require('tobira.core.suggest')

    logger.mark_shown(';')
    logger.mark_shown(';')

    local float_called = false
    package.loaded['tobira.ui.float'] = { show = function() float_called = true end }

    suggest.show(';')

    package.loaded['tobira.ui.float'] = nil
    assert.is_false(float_called)
  end)

  it('shows when shown fewer times than max_shown', function()
    config.setup({ max_shown = 3 })

    package.loaded['tobira.core.suggest'] = nil
    suggest = require('tobira.core.suggest')

    logger.mark_shown(';')
    logger.mark_shown(';')

    local float_called = false
    package.loaded['tobira.ui.float'] = { show = function() float_called = true end }

    suggest.show(';')

    package.loaded['tobira.ui.float'] = nil
    assert.is_true(float_called)
  end)
end)

describe('suggest.manual', function()
  it('notifies when there are no suggestions', function()
    local notified = false
    local orig = vim.notify
    vim.notify = function(msg, _)
      if msg:find('no new suggestions') then notified = true end
    end

    suggest.manual()
    vim.notify = orig

    assert.is_true(notified)
  end)
end)
