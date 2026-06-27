local skills = require('tobira.core.skills')

-- ── track + threshold items ───────────────────────────────────────────────────

describe('when an item is learned by reaching the usage threshold', function()
  local item = { track = { 'h', 'j' }, threshold = 10 }

  it('is false when total usage is below the threshold', function()
    assert.is_false(skills.is_learned(item, { h = { count = 4 }, j = { count = 5 } }))
  end)

  it('is true when total usage meets the threshold exactly', function()
    assert.is_true(skills.is_learned(item, { h = { count = 5 }, j = { count = 5 } }))
  end)

  it('is false when usage data is empty', function()
    assert.is_false(skills.is_learned(item, {}))
  end)
end)

-- ── adopted items ─────────────────────────────────────────────────────────────

describe('when an item is learned by adopting a specific command', function()
  local item = { adopted = 'cw' }

  it('is false when the command has not been adopted and never used', function()
    assert.is_false(skills.is_learned(item, { cw = { count = 0, adopted = false } }))
  end)

  it('is true when the command has been adopted', function()
    assert.is_true(skills.is_learned(item, { cw = { count = 5, adopted = true } }))
  end)

  it('is true when the command has been used even without explicit adoption', function()
    assert.is_true(skills.is_learned(item, { cw = { count = 3, adopted = false } }))
  end)

  it('is false when there is no usage data for the command', function()
    assert.is_false(skills.is_learned(item, {}))
  end)
end)

-- ── items with no criteria ────────────────────────────────────────────────────

describe('when an item has neither track nor adopted criteria', function()
  it('is never considered learned', function()
    assert.is_false(skills.is_learned({}, { anything = { count = 999 } }))
  end)
end)
