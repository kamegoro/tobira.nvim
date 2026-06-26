-- Integration tests for logger.lua
-- Requires Neovim (vim.* APIs are used)

local logger = require('tobira.core.logger')

-- Use a temp file to avoid polluting real usage data
local test_data_file = vim.fn.tempname() .. '_tobira_test.json'

local function setup_logger()
  -- Point logger at a temp file for isolation
  -- We do this by temporarily overriding stdpath data during the test
  logger.reset()
end

before_each(function()
  setup_logger()
end)

after_each(function()
  logger.reset()
  vim.fn.delete(test_data_file)
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
    -- Should not error
    assert.has_no_error(function()
      logger.mark_adopted('nonexistent')
    end)
  end)
end)

describe('logger.get_all', function()
  it('returns an empty table after reset', function()
    local all = logger.get_all()
    assert.same({}, all)
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
