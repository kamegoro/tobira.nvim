local config = require('tobira.core.config')

describe('config.values', function()
  before_each(function()
    config.reset()
  end)

  it('has correct defaults', function()
    assert.equals(1500, config.values.idle_delay)
    assert.equals(2, config.values.max_shown)
    assert.equals('en', config.values.lang)
  end)

  it('setup overrides individual values', function()
    config.setup({ idle_delay = 800 })
    assert.equals(800, config.values.idle_delay)
    assert.equals(2, config.values.max_shown)
  end)

  it('setup merges without losing unspecified defaults', function()
    config.setup({ max_shown = 5 })
    assert.equals(1500, config.values.idle_delay)
    assert.equals(5, config.values.max_shown)
  end)

  it('reset restores defaults', function()
    config.setup({ idle_delay = 999, max_shown = 10 })
    config.reset()
    assert.equals(1500, config.values.idle_delay)
    assert.equals(2, config.values.max_shown)
  end)
end)

describe('config.setup validation', function()
  before_each(function()
    config.reset()
  end)

  it('rejects non-number idle_delay and keeps previous values', function()
    local notified = false
    local orig = vim.notify
    vim.notify = function(msg, _)
      if msg:find('invalid config') then
        notified = true
      end
    end
    local ok, err = pcall(config.setup, { idle_delay = 'fast' })
    vim.notify = orig
    assert.is_true(ok, err)
    assert.is_true(notified)
    assert.equals(1500, config.values.idle_delay)
  end)
end)
