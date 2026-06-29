local graph = require('tobira.core.graph')

-- Helper: build usage data with given session history.
-- sessions is a list of per-session counts (oldest first, newest last).
local function usage_entry(count, sessions, shown, suppressed)
  return { count = count, sessions = sessions or {}, shown = shown or 0, suppressed = suppressed or false }
end

-- ── find_best scoring ─────────────────────────────────────────────────────────

describe('when usage log is empty', function()
  it('has no suggestion to offer', function()
    assert.is_nil(graph.find_best({}))
  end)
end)

describe('when the trigger command has never been used', function()
  it('has no suggestion to offer', function()
    assert.is_nil(graph.find_best({ [';'] = usage_entry(0) }))
  end)
end)

describe('when f is used but ; is unknown to the user', function()
  it('suggests ; as the next door', function()
    assert.equals(';', graph.find_best({ f = usage_entry(10) }))
  end)
end)

describe('when ; is used often (user already knows it)', function()
  it('suggests , as the next step', function()
    assert.equals(',', graph.find_best({ [';'] = usage_entry(15) }))
  end)
end)

describe('when the best candidate has been adopted by the user', function()
  it('has no suggestion to offer', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(0, { 5, 6, 7 }),  -- avg 6 ≥ 5 → adopted
    }
    assert.is_nil(graph.find_best(usage))
  end)
end)

describe('when the best candidate has been shown the maximum number of times', function()
  it('has no suggestion to offer', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(15, {}, 3),
      [','] = usage_entry(0, {}, 3),
    }
    assert.is_nil(graph.find_best(usage))
  end)
end)

describe('when a candidate has been shown but fewer than the maximum times', function()
  it('still suggests it', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(0, {}, 2),
    }
    assert.equals(';', graph.find_best(usage))
  end)
end)

describe('when multiple triggers are active', function()
  it('picks the highest-scoring suggestion', function()
    local usage = {
      f = usage_entry(10),
      dw = usage_entry(30),
    }
    local result = graph.find_best(usage)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)

  it('reduces a suggestion score by how much the user already uses it', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(8),
      dw = usage_entry(10),
    }
    -- dw score = 10, ; score = 10-8 = 2 → dw-based suggestion wins
    local result = graph.find_best(usage)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

-- ── session-based adoption detection ─────────────────────────────────────────

describe('when a command has high average usage over recent sessions', function()
  it('is considered adopted when avg(last 3) ≥ 5', function()
    local data = usage_entry(50, { 5, 6, 7 })
    assert.is_true(graph.is_adopted(data))
  end)

  it('is not adopted when avg(last 3) < 5', function()
    local data = usage_entry(10, { 1, 2, 3 })
    assert.is_false(graph.is_adopted(data))
  end)

  it('uses only the last 3 sessions when history is longer', function()
    -- First 5 sessions are high, but last 3 are low → not adopted
    local data = usage_entry(100, { 9, 8, 7, 1, 2, 3 })
    assert.is_false(graph.is_adopted(data))
  end)

  it('is adopted when sessions history has fewer than 3 entries but avg ≥ 5', function()
    local data = usage_entry(10, { 8 })
    assert.is_true(graph.is_adopted(data))
  end)

  it('is not adopted with no session history', function()
    local data = usage_entry(10, {})
    assert.is_false(graph.is_adopted(data))
  end)
end)

describe('when a command was adopted but recently fell out of use', function()
  it('is considered forgotten when avg(last 3) was high but last 2 are 0', function()
    local data = usage_entry(50, { 7, 8, 0, 0 })
    assert.is_true(graph.is_forgotten(data))
  end)

  it('is not forgotten when recent sessions are non-zero', function()
    local data = usage_entry(50, { 7, 8, 0, 1 })
    assert.is_false(graph.is_forgotten(data))
  end)

  it('is not forgotten with fewer than 3 sessions', function()
    local data = usage_entry(5, { 0, 0 })
    assert.is_false(graph.is_forgotten(data))
  end)

  it('is not forgotten when it was never properly adopted', function()
    -- last 2 are 0, but no early session reached ≥ 5 → was never adopted, not forgotten
    local data = usage_entry(5, { 1, 2, 0, 0 })
    assert.is_false(graph.is_forgotten(data))
  end)

  it('returns to suggestion pool when forgotten', function()
    local usage = {
      f = usage_entry(20),
      [';'] = usage_entry(3, { 8, 9, 0, 0 }),  -- forgotten (used less than trigger → positive score)
    }
    assert.equals(';', graph.find_best(usage))
  end)
end)

describe('when a command is explicitly suppressed', function()
  it('is never suggested even with low session usage', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(0, {}, 0, true),  -- suppressed
    }
    assert.is_nil(graph.find_best(usage))
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
    local result = graph.find_best({ dw = usage_entry(5) })
    assert.is_not_nil(result)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

-- ── new learning chains ───────────────────────────────────────────────────────

describe('the cw → . (dot repeat) chain', function()
  it('suggests . once the user uses cw', function()
    local usage = { cw = usage_entry(8) }
    assert.equals('.', graph.find_best(usage))
  end)
end)

describe('the x → D → C deletion chain', function()
  it('suggests D when x is used', function()
    local result = graph.find_best({ x = usage_entry(10) })
    assert.is_not_nil(result)
    assert.equals('x', graph.suggestions[result].trigger)
  end)

  it('suggests C once D is adopted', function()
    local usage = { D = usage_entry(6) }
    assert.equals('C', graph.find_best(usage))
  end)
end)

-- ── max_shown parameter ────────────────────────────────────────────────────────

describe('when max_shown is raised above the default', function()
  it('still suggests a command shown fewer times than the new limit', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(0, {}, 4),
    }
    assert.equals(';', graph.find_best(usage, 5))
  end)
end)

describe('when max_shown is lowered below the default', function()
  it('does not suggest a command that has reached the lower limit', function()
    local usage = {
      f = usage_entry(10),
      [';'] = usage_entry(0, {}, 2),
    }
    assert.is_nil(graph.find_best(usage, 2))
  end)
end)

-- ── level-based filtering ─────────────────────────────────────────────────────

describe('when find_best has a max_level restriction', function()
  it('excludes intermediate commands when max_level is beginner', function()
    -- x triggers D (beginner) and {n}x (intermediate)
    -- with beginner filter only D is eligible
    local usage = { x = usage_entry(10) }
    assert.equals('D', graph.find_best(usage, 3, 'beginner'))
  end)

  it('includes intermediate commands when max_level is intermediate', function()
    local usage = {
      x = usage_entry(10),
      D = usage_entry(5),   -- D score = 10-5 = 5; {n}x score = 10-0 = 10
    }
    assert.equals('{n}x', graph.find_best(usage, 3, 'intermediate'))
  end)

  it('allows all commands when max_level is nil', function()
    local usage = { x = usage_entry(10) }
    assert.is_not_nil(graph.find_best(usage))
  end)
end)
