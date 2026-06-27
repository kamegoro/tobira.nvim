local logger = require('tobira.core.logger')

-- ── default state ─────────────────────────────────────────────────────────────

describe('before any usage is recorded', function()
  before_each(function()
    logger.reset()
  end)

  it('reports zero counts for any command', function()
    local data = logger.get('unknown_cmd')
    assert.equals(0, data.count)
    assert.equals(0, data.shown)
    assert.is_false(data.adopted)
  end)

  it('returns an empty usage table', function()
    assert.same({}, logger.get_all())
  end)
end)

-- ── mark_shown ────────────────────────────────────────────────────────────────

describe('when a suggestion has been shown to the user', function()
  before_each(function()
    logger.reset()
  end)

  it('tracks that it was shown once', function()
    logger.mark_shown(';')
    assert.equals(1, logger.get(';').shown)
  end)

  it('tracks each additional showing', function()
    logger.mark_shown(';')
    logger.mark_shown(';')
    assert.equals(2, logger.get(';').shown)
  end)

  it('creates a new record even if the command was never used', function()
    logger.mark_shown('brand_new_cmd')
    local data = logger.get('brand_new_cmd')
    assert.equals(1, data.shown)
    assert.equals(0, data.count)
    assert.is_false(data.adopted)
  end)
end)

-- ── mark_adopted ──────────────────────────────────────────────────────────────

describe('when the user adopts a suggested command', function()
  before_each(function()
    logger.reset()
  end)

  it('marks it as adopted', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')
    assert.is_true(logger.get(';').adopted)
  end)
end)

describe('when mark_adopted is called for an unknown command', function()
  before_each(function()
    logger.reset()
  end)

  it('does not error', function()
    assert.has_no_error(function()
      logger.mark_adopted('never_seen')
    end)
  end)
end)

-- ── reset ─────────────────────────────────────────────────────────────────────

describe('after a reset', function()
  it('all usage data is cleared', function()
    logger.mark_shown('f')
    logger.reset()
    assert.same({}, logger.get_all())
  end)
end)

-- ── setup idempotence ─────────────────────────────────────────────────────────

describe('when setup is called more than once', function()
  it('does not error or register duplicate handlers', function()
    assert.has_no_error(function()
      logger.setup()
      logger.setup()
    end)
  end)
end)
-- ── reset side-effects ──────────────────────────────────────────────────────

describe('when reset is called', function()
  it('does not trigger a notification', function()
    local notified = false
    local orig = vim.notify
    vim.notify = function()
      notified = true
    end
    local ok, err = pcall(logger.reset)
    vim.notify = orig
    assert.is_true(ok, err)
    assert.is_false(notified)
  end)
end)

-- ── guide_seen ───────────────────────────────────────────────────────────────

describe('when the guide is marked as seen', function()
  it('reports it as seen immediately after', function()
    logger.mark_guide_seen()
    assert.is_true(logger.is_guide_seen())
  end)
end)