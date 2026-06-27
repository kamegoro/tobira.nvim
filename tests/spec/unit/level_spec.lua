local level = require('tobira.core.level')

-- ── skill level detection (usage injected directly) ──────────────────────────

describe('when no commands have been used at all', function()
  it('returns novice', function()
    assert.equals('novice', level.get({}))
  end)
end)

describe('when the user navigates with hjkl', function()
  it('returns beginner once hjkl count reaches the threshold', function()
    assert.equals('beginner', level.get({ j = { count = 10 } }))
  end)

  it('stays at novice when hjkl is below the threshold', function()
    assert.equals('novice', level.get({ j = { count = 5 } }))
  end)
end)

describe('when the user uses f to jump to characters', function()
  it('returns intermediate once f count reaches the threshold', function()
    assert.equals('intermediate', level.get({ f = { count = 5 } }))
  end)
end)

describe('when the user uses w / b heavily', function()
  it('returns intermediate once combined wb count reaches the threshold', function()
    assert.equals('intermediate', level.get({ w = { count = 20 } }))
  end)
end)

describe('when the user uses ; or , regularly', function()
  it('returns advanced', function()
    assert.equals('advanced', level.get({ [';'] = { count = 3 } }))
  end)
end)

describe('when the user has adopted cgn', function()
  it('returns advanced', function()
    assert.equals('advanced', level.get({ cgn = { adopted = true } }))
  end)
end)
