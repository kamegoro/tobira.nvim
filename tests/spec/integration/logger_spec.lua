local logger = require('tobira.core.logger')

describe('logger.get', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
  end)

  it('returns zero counts for an unknown command', function()
    local data = logger.get('unknown_cmd')
    assert.equals(0, data.count)
    assert.equals(0, data.shown)
    assert.is_false(data.adopted)
  end)
end)

describe('logger.mark_shown', function()
  before_each(function()
    logger.reset()
  end)

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
  before_each(function()
    logger.reset()
  end)

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
  before_each(function()
    logger.reset()
  end)

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
    logger.reset()
    assert.same({}, logger.get_all())
  end)
end)

describe('logger.on_pattern callback', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
  end)

  after_each(function()
    logger.on_pattern = nil
  end)

  it('is called when x_repeat pattern is detected', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    logger.simulate_keys({ 'x', 'x', 'x' })
    assert.is_true(#fired > 0)
    assert.equals('x_repeat', fired[1].pattern)
    assert.equals('{n}x', fired[1].cmd)
  end)

  it('is called when u_repeat pattern is detected', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    logger.simulate_keys({ 'u', 'u', 'u' })
    assert.is_true(#fired > 0)
    assert.equals('u_repeat', fired[1].pattern)
    assert.equals('<C-r>', fired[1].cmd)
  end)

  it('is called when j_repeat pattern is detected', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    logger.simulate_keys({ 'j', 'j', 'j', 'j', 'j' })
    assert.is_true(#fired > 0)
    assert.equals('j_repeat', fired[1].pattern)
  end)

  it('is called when zero_then_w pattern is detected', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    logger.simulate_keys({ '0', 'w' })
    assert.is_true(#fired > 0)
    assert.equals('zero_then_w', fired[1].pattern)
    assert.equals('^', fired[1].cmd)
  end)

  it('is not called when on_pattern is nil', function()
    logger.on_pattern = nil
    assert.has_no_error(function()
      logger.simulate_keys({ 'x', 'x', 'x' })
    end)
  end)
end)

describe('logger.setup guard', function()
  it('can be called multiple times without error', function()
    assert.has_no_error(function()
      logger.setup({})
      logger.setup({})
    end)
  end)
end)
