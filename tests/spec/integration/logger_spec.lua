local logger = require('tobira.core.logger')

before_each(function()
  logger.reset()
end)

after_each(function()
  logger.reset()
end)

describe('logger.get', function()
  it('returns zero counts for an unknown command', function()
    local data = logger.get('unknown_cmd')
    assert.equals(0, data.count)
    assert.equals(0, data.shown)
    assert.is_false(data.adopted)
  end)
end)

describe('logger.mark_shown', function()
  it('increments the shown count', function()
    logger.mark_shown(';')
    assert.equals(1, logger.get(';').shown)
  end)

  it('increments shown count on repeated calls', function()
    logger.mark_shown(';')
    logger.mark_shown(';')
    assert.equals(2, logger.get(';').shown)
  end)

  it('creates the entry if it does not exist', function()
    logger.mark_shown('new_cmd')
    local data = logger.get('new_cmd')
    assert.equals(1, data.shown)
    assert.equals(0, data.count)
    assert.is_false(data.adopted)
  end)
end)

describe('logger.mark_adopted', function()
  it('sets adopted to true', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')
    assert.is_true(logger.get(';').adopted)
  end)

  it('does nothing if the command has no record', function()
    assert.has_no_error(function()
      logger.mark_adopted('nonexistent')
    end)
  end)
end)

describe('logger.get_all', function()
  it('returns an empty table after reset', function()
    assert.same({}, logger.get_all())
  end)

  it('reflects marks after mark_shown', function()
    logger.mark_shown('f')
    logger.mark_shown(';')
    local all = logger.get_all()
    assert.is_not_nil(all['f'])
    assert.is_not_nil(all[';'])
  end)
end)

describe('logger.reset', function()
  it('clears all usage data', function()
    logger.mark_shown('f')
    logger.mark_shown(';')
    logger.reset()
    assert.same({}, logger.get_all())
  end)
end)

-- Pattern detection via simulate_keys (test helper)
describe('logger pattern detection', function()
  it('detects x_repeat after 3 consecutive x presses', function()
    local queued = nil
    local suggest = require('tobira.core.suggest')
    local orig = suggest.queue
    suggest.queue = function(pattern, cmd)
      queued = { pattern = pattern, cmd = cmd }
    end

    logger.simulate_keys({ 'x', 'x', 'x' })

    suggest.queue = orig
    assert.is_not_nil(queued)
    assert.equals('x_repeat', queued.pattern)
  end)

  it('detects u_repeat after 3 consecutive u presses', function()
    local queued = nil
    local suggest = require('tobira.core.suggest')
    local orig = suggest.queue
    suggest.queue = function(pattern, cmd)
      queued = { pattern = pattern, cmd = cmd }
    end

    logger.simulate_keys({ 'u', 'u', 'u' })

    suggest.queue = orig
    assert.is_not_nil(queued)
    assert.equals('u_repeat', queued.pattern)
  end)

  it('detects j_repeat after 5 consecutive j presses', function()
    local queued = nil
    local suggest = require('tobira.core.suggest')
    local orig = suggest.queue
    suggest.queue = function(pattern, cmd)
      queued = { pattern = pattern, cmd = cmd }
    end

    logger.simulate_keys({ 'j', 'j', 'j', 'j', 'j' })

    suggest.queue = orig
    assert.is_not_nil(queued)
    assert.equals('j_repeat', queued.pattern)
  end)

  it('detects zero_then_w pattern', function()
    local queued = nil
    local suggest = require('tobira.core.suggest')
    local orig = suggest.queue
    suggest.queue = function(pattern, cmd)
      queued = { pattern = pattern, cmd = cmd }
    end

    logger.simulate_keys({ '0', 'w' })

    suggest.queue = orig
    assert.is_not_nil(queued)
    assert.equals('zero_then_w', queued.pattern)
  end)
end)
