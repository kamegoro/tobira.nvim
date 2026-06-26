local graph = require('tobira.core.graph')

describe('graph.find_best', function()
  it('returns nil when usage is empty', function()
    assert.is_nil(graph.find_best({}))
  end)

  it('returns nil when trigger command has never been used', function()
    local usage = {
      [';'] = { count = 0, shown = 0, adopted = false },
    }
    assert.is_nil(graph.find_best(usage))
  end)

  it('returns the suggestion when trigger is used and target is not', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
    }
    assert.equals(';', graph.find_best(usage))
  end)

  it('skips suggestions that are already adopted', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 0, adopted = true },
    }
    -- ; is adopted, so no suggestion should come from f
    assert.is_nil(graph.find_best(usage))
  end)

  it('skips suggestions shown 3 or more times', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 3, adopted = false },
    }
    assert.is_nil(graph.find_best(usage))
  end)

  it('still suggests when shown fewer than 3 times', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 2, adopted = false },
    }
    assert.equals(';', graph.find_best(usage))
  end)

  it('picks the highest-scoring suggestion among multiple candidates', function()
    -- dw used 30 times, f used 10 times → dw-based suggestion scores higher
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      dw = { count = 30, shown = 0, adopted = false },
    }
    local result = graph.find_best(usage)
    -- cw and ciw are both triggered by dw; either is a valid answer
    assert.is_not_nil(result)
    assert.is_not_nil(graph.suggestions[result])
    assert.equals('dw', graph.suggestions[result].trigger)
  end)

  it('subtracts target usage from score (prefers unused targets)', function()
    -- f used 10 times, ; used 8 times → score for ; is 10-8=2
    -- dw used 10 times, cw never used → score for cw is 10-0=10
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 8, shown = 0, adopted = false },
      dw = { count = 10, shown = 0, adopted = false },
    }
    local result = graph.find_best(usage)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

describe('graph.suggestions', function()
  it('each suggestion has required fields', function()
    for cmd, sug in pairs(graph.suggestions) do
      assert.is_not_nil(sug.cmd, cmd .. ' missing .cmd')
      assert.is_not_nil(sug.trigger, cmd .. ' missing .trigger')
      assert.is_not_nil(sug.title, cmd .. ' missing .title')
      assert.is_not_nil(sug.body, cmd .. ' missing .body')
      assert.is_not_nil(sug.example, cmd .. ' missing .example')
    end
  end)

  it('cmd field matches the table key', function()
    for cmd, sug in pairs(graph.suggestions) do
      assert.equals(cmd, sug.cmd)
    end
  end)
end)

describe('graph.adjacency', function()
  it('each adjacency entry is a table of strings', function()
    for trigger, neighbors in pairs(graph.adjacency) do
      assert.is_table(neighbors, trigger .. ' adjacency should be a table')
      for _, neighbor in ipairs(neighbors) do
        assert.is_string(neighbor)
      end
    end
  end)
end)
