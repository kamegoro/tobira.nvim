local graph = require('tobira.core.graph')

-- ── find_best scoring ─────────────────────────────────────────────────────────

describe('when usage log is empty', function()
  it('has no suggestion to offer', function()
    assert.is_nil(graph.find_best({}))
  end)
end)

describe('when the trigger command has never been used', function()
  it('has no suggestion to offer', function()
    assert.is_nil(graph.find_best({ [';'] = { count = 0, shown = 0, adopted = false } }))
  end)
end)

describe('when f is used but ; is unknown to the user', function()
  it('suggests ; as the next door', function()
    assert.equals(';', graph.find_best({ f = { count = 10, shown = 0, adopted = false } }))
  end)
end)

describe('when ; is used often (user already knows it)', function()
  it('suggests , as the next step', function()
    assert.equals(',', graph.find_best({ [';'] = { count = 15, shown = 0, adopted = false } }))
  end)
end)

describe('when the best candidate has been adopted by the user', function()
  it('has no suggestion to offer', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 0, adopted = true },
    }
    assert.is_nil(graph.find_best(usage))
  end)
end)

describe('when the best candidate has been shown the maximum number of times', function()
  it('has no suggestion to offer', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 15, shown = 3, adopted = false },
      [','] = { count = 0, shown = 3, adopted = false },
    }
    assert.is_nil(graph.find_best(usage))
  end)
end)

describe('when a candidate has been shown but fewer than the maximum times', function()
  it('still suggests it', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 2, adopted = false },
    }
    assert.equals(';', graph.find_best(usage))
  end)
end)

describe('when multiple triggers are active', function()
  it('picks the highest-scoring suggestion', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      dw = { count = 30, shown = 0, adopted = false },
    }
    local result = graph.find_best(usage)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)

  it('reduces a suggestion score by how much the user already uses it', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 8, shown = 0, adopted = false },
      dw = { count = 10, shown = 0, adopted = false },
    }
    -- dw score = 10, ; score = 10-8 = 2 → dw-based suggestion wins
    local result = graph.find_best(usage)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

-- ── data integrity ────────────────────────────────────────────────────────────

describe('every suggestion in the graph', function()
  it('has a cmd field that matches its table key', function()
    for key, sug in pairs(graph.suggestions) do
      assert.equals(key, sug.cmd, key .. ': cmd field must match its key')
    end
  end)

  it('declares a trigger command', function()
    for key, sug in pairs(graph.suggestions) do
      assert.is_string(sug.trigger, key .. ': missing trigger')
    end
  end)

end)

-- ── compound-op trigger (bug #15 regression) ─────────────────────────────────

describe('when dw has been used (compound-tracked)', function()
  it('suggests cw as the next step', function()
    local result = graph.find_best({ dw = { count = 5, shown = 0, adopted = false } })
    assert.is_not_nil(result)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

-- ── new learning chains ───────────────────────────────────────────────────────

describe('the cw → . (dot repeat) chain', function()
  it('suggests . once the user uses cw', function()
    local usage = {
      cw = { count = 8, shown = 0, adopted = false },
    }
    assert.equals('.', graph.find_best(usage))
  end)
end)

describe('the x → D → C deletion chain', function()
  it('suggests D when x is used', function()
    local result = graph.find_best({ x = { count = 10, shown = 0, adopted = false } })
    assert.is_not_nil(result)
    assert.equals('x', graph.suggestions[result].trigger)
  end)

  it('suggests C once D is adopted', function()
    local usage = {
      D = { count = 6, shown = 0, adopted = false },
    }
    assert.equals('C', graph.find_best(usage))
  end)
end)

-- ── max_shown parameter ────────────────────────────────────────────────────────

describe('when max_shown is raised above the default', function()
  it('still suggests a command shown fewer times than the new limit', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 4, adopted = false },
    }
    assert.equals(';', graph.find_best(usage, 5))
  end)
end)

describe('when max_shown is lowered below the default', function()
  it('does not suggest a command that has reached the lower limit', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 2, adopted = false },
    }
    assert.is_nil(graph.find_best(usage, 2))
  end)
end)
