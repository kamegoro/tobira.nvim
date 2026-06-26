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
      [','] = { count = 0, shown = 0, adopted = true },
    }
    assert.is_nil(graph.find_best(usage))
  end)

  it('skips suggestions shown 3 or more times', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 0, shown = 3, adopted = false },
      [','] = { count = 0, shown = 3, adopted = false },
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
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      dw = { count = 30, shown = 0, adopted = false },
    }
    local result = graph.find_best(usage)
    assert.is_not_nil(result)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)

  it('subtracts target usage from score', function()
    local usage = {
      f = { count = 10, shown = 0, adopted = false },
      [';'] = { count = 8, shown = 0, adopted = false },
      dw = { count = 10, shown = 0, adopted = false },
    }
    local result = graph.find_best(usage)
    -- dw score=10, ; score=2 → dw-based suggestion wins
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

describe('graph.suggestions — required fields', function()
  it('each suggestion has all required fields', function()
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

describe('graph.suggestions — new patterns', function()
  it('has , as a suggestion (reverse f)', function()
    assert.is_not_nil(graph.suggestions[','])
    assert.equals('f', graph.suggestions[','].trigger)
  end)

  it('has <C-r> as a suggestion (redo after u)', function()
    assert.is_not_nil(graph.suggestions['<C-r>'])
    assert.equals('u', graph.suggestions['<C-r>'].trigger)
  end)

  it('has ddp as a suggestion (swap lines)', function()
    assert.is_not_nil(graph.suggestions['ddp'])
    assert.equals('dd', graph.suggestions['ddp'].trigger)
  end)

  it('has {n}j as a suggestion (repeated j)', function()
    assert.is_not_nil(graph.suggestions['{n}j'])
    assert.equals('j', graph.suggestions['{n}j'].trigger)
  end)

  it('has ^ as a suggestion (0 then w)', function()
    assert.is_not_nil(graph.suggestions['^'])
    assert.equals('0', graph.suggestions['^'].trigger)
  end)

  it('has cgn as a suggestion (repeated search+edit)', function()
    assert.is_not_nil(graph.suggestions['cgn'])
    assert.equals('n', graph.suggestions['cgn'].trigger)
  end)
end)

describe('graph.adjacency', function()
  it('each entry is a table of strings', function()
    for trigger, neighbors in pairs(graph.adjacency) do
      assert.is_table(neighbors, trigger .. ' adjacency should be a table')
      for _, neighbor in ipairs(neighbors) do
        assert.is_string(neighbor)
      end
    end
  end)
end)
