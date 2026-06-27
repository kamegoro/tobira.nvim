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

  it('has a non-empty title', function()
    for key, sug in pairs(graph.suggestions) do
      assert.is_string(sug.title, key .. ': missing title')
      assert.is_true(#sug.title > 0, key .. ': title must not be empty')
    end
  end)

  it('has a non-empty body', function()
    for key, sug in pairs(graph.suggestions) do
      assert.is_string(sug.body, key .. ': missing body')
      assert.is_true(#sug.body > 0, key .. ': body must not be empty')
    end
  end)

  it('has a non-empty example', function()
    for key, sug in pairs(graph.suggestions) do
      assert.is_string(sug.example, key .. ': missing example')
      assert.is_true(#sug.example > 0, key .. ': example must not be empty')
    end
  end)

  it('declares a trigger command', function()
    for key, sug in pairs(graph.suggestions) do
      assert.is_string(sug.trigger, key .. ': missing trigger')
    end
  end)
end)

-- ── learning progression ──────────────────────────────────────────────────────

describe('the f → ; → , learning progression', function()
  it('; is triggered by f usage', function()
    assert.equals('f', graph.suggestions[';'].trigger)
  end)

  it(', is triggered by ; usage (comes after learning ;)', function()
    assert.equals(';', graph.suggestions[','].trigger)
  end)
end)

describe('adjacency map', function()
  it('each entry lists neighboring commands as strings', function()
    for trigger, neighbors in pairs(graph.adjacency) do
      assert.is_table(neighbors, trigger .. ' adjacency must be a table')
      for _, neighbor in ipairs(neighbors) do
        assert.is_string(neighbor, trigger .. ': each neighbor must be a string')
      end
    end
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
