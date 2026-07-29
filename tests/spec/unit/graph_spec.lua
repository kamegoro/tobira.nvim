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
  it('suggests ; as the next door (alphabetically first among f-triggered)', function()
    -- ; < F < t alphabetically, so ; wins the tie
    assert.equals(';', graph.find_best({ f = usage_entry(10) }))
  end)
end)

describe('when ; is used often (user already knows it)', function()
  it('suggests , as the next step', function()
    assert.equals(',', graph.find_best({ [';'] = usage_entry(15) }))
  end)
end)

describe('when the best candidate has reached mastery level (count >= 100)', function()
  it('has no suggestion to offer', function()
    local usage = {
      u = usage_entry(10),
      ['<C-r>'] = usage_entry(100, {}), -- mastery_level 2 → excluded
      U = usage_entry(100, {}), -- mastery_level 2 → excluded
    }
    assert.is_nil(graph.find_best(usage))
  end)
end)

describe('when the best candidate has been shown the maximum number of times', function()
  it('has no suggestion to offer', function()
    local usage = {
      u = usage_entry(10),
      ['<C-r>'] = usage_entry(5, {}, 3), -- shown 3 times (default max)
      U = usage_entry(100, {}), -- mastered → excluded
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
      dw = usage_entry(20), -- cw/ciw score 20 > F's 10, no tie needed
    }
    -- ; score = 10-8 = 2; F score = 10; cw/ciw score = 20 → dw-triggered wins
    local result = graph.find_best(usage)
    assert.equals('dw', graph.suggestions[result].trigger)
  end)
end)

-- ── nil best_cmd guard at the -1 score sentinel (#121) ───────────────────────

describe('when the only offered candidate has trigger_count - cmd_count == -1', function()
  it('is selected instead of erroring on a nil best_cmd comparison', function()
    -- #121: best_score starts at -1, so a candidate whose score is exactly
    -- -1 (a realistic value: trigger used 5 times, suggested cmd used 6)
    -- fails `score > best_score`, falling into `cmd < best_cmd` while
    -- best_cmd is still nil -> "attempt to compare string with nil".
    -- A single-entry suggestions table makes pairs() order a non-issue:
    -- with only one candidate, it is always the (only) one visited first.
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      w = { cmd = 'w', trigger = 'l', level = 'beginner', category = 'motion' },
    }
    local ok, result = pcall(graph.find_best, { l = usage_entry(5), w = usage_entry(6) })
    graph.suggestions = original_suggestions

    assert.is_true(ok, result)
    assert.equals('w', result)
  end)
end)

describe('when two offered candidates tie at score -1', function()
  it('still applies the alphabetical tie-break without erroring', function()
    -- Both candidates score trigger_count(5) - cmd_count(6) == -1. Whichever
    -- one pairs() visits first must not crash, and the final pick must be
    -- the alphabetically smaller command regardless of visit order.
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      w = { cmd = 'w', trigger = 'l', level = 'beginner', category = 'motion' },
      b = { cmd = 'b', trigger = 'h', level = 'beginner', category = 'motion' },
    }
    local ok, result = pcall(graph.find_best, {
      l = usage_entry(5),
      w = usage_entry(6),
      h = usage_entry(5),
      b = usage_entry(6),
    })
    graph.suggestions = original_suggestions

    assert.is_true(ok, result)
    assert.equals('b', result)
  end)
end)

-- ── ambient exclusion for reactive-only, nominal-anchor entries (#110 fix) ───
-- A registry entry can be marked `ambient = false` when its suggestion only
-- ever makes sense as a direct reaction to a just-detected pattern (e.g.
-- terminal_esc_repeat), never as a proactive idle-time nudge. find_best()
-- powers both the idle ambient picker and :Tobira's manual pick, so this
-- exclusion must apply to both call sites — see graph.lua's find_best for why.

describe('when a suggestion entry is marked ambient = false', function()
  it('is never returned by find_best, even with a maximal score (#110)', function()
    -- trigger used heavily (500) and the candidate's own count is 0 -> this
    -- would otherwise win find_best outright (score 500, nothing competes).
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      w = { cmd = 'w', trigger = 'l', level = 'beginner', category = 'motion', ambient = false },
    }
    local result = graph.find_best({ l = usage_entry(500) })
    graph.suggestions = original_suggestions

    assert.is_nil(result, 'ambient = false candidates must never be offered by find_best')
  end)

  it('does not block a different, ambient-eligible candidate from being offered (#110)', function()
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      w = { cmd = 'w', trigger = 'l', level = 'beginner', category = 'motion', ambient = false },
      b = { cmd = 'b', trigger = 'l', level = 'beginner', category = 'motion' },
    }
    local result = graph.find_best({ l = usage_entry(500) })
    graph.suggestions = original_suggestions

    assert.equals('b', result)
  end)
end)

describe('the terminal-mode <C-\\><C-n> suggestion (#110 regression)', function()
  it(
    'is never surfaced by find_best from real i usage alone, even though i is the only trigger it shares with <C-w> / gi / I',
    function()
      -- Before the fix: cmd_count for <C-\><C-n> is structurally always 0
      -- (nothing ever increments it — see commands.lua's comment), so its
      -- score against a heavily-used 'i' trigger is always the maximum
      -- possible (trigger_count - 0), and it also wins every alphabetical
      -- tie-break against the other 'i'-triggered entries because
      -- '<C-\><C-n>' sorts before '<C-w>' byte-for-byte. That combination
      -- made it dominate find_best() despite the user never having opened
      -- a terminal.
      local usage = { i = usage_entry(500) }
      for _ = 1, 20 do
        local result = graph.find_best(usage)
        assert.not_equals('<C-\\><C-n>', result)
      end
    end
  )
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

  it(
    'is considered forgotten when recent usage has decayed well below its historical average, even without hitting exactly zero',
    function()
      -- #62: the old rule required the last 2 sessions to be *exactly* 0, so a
      -- single stray use (here: 1) was enough to call this "not forgotten" no
      -- matter how far usage had actually dropped. The graded rule compares the
      -- recent average (0.5) against 30% of the historical average (7.5*0.3=2.25)
      -- instead — a >90% drop reads as forgotten even though it isn't literally 0.
      local data = usage_entry(50, { 7, 8, 0, 1 })
      assert.is_true(graph.is_forgotten(data))
    end
  )

  it('is not forgotten with fewer than 3 sessions', function()
    local data = usage_entry(5, { 0, 0 })
    assert.is_false(graph.is_forgotten(data))
  end)

  it('is not forgotten when it was never properly adopted', function()
    -- last 2 are 0, but no early session reached ≥ 5 → was never adopted, not forgotten
    local data = usage_entry(5, { 1, 2, 0, 0 })
    assert.is_false(graph.is_forgotten(data))
  end)

  it('is not forgotten right at the 30% boundary (recent equals 30% of historical)', function()
    -- historical avg = avg(10,10) = 10; recent avg = avg(3,3) = 3 = 10*0.3 exactly.
    -- Strict "<" means landing exactly on the ratio does not count as forgotten.
    local data = usage_entry(50, { 10, 10, 3, 3 })
    assert.is_false(graph.is_forgotten(data))
  end)

  it('is forgotten just past the 30% boundary', function()
    -- historical avg = 10; recent avg = avg(2,2) = 2, which is < 10*0.3 = 3.
    local data = usage_entry(50, { 10, 10, 2, 2 })
    assert.is_true(graph.is_forgotten(data))
  end)

  it('returns to suggestion pool when forgotten', function()
    local usage = {
      u = usage_entry(500),
      ['<C-r>'] = usage_entry(120, { 8, 9, 0, 0 }), -- mastered but forgotten → back in pool (score 500-120=380)
      U = usage_entry(100, {}), -- mastered and not forgotten → excluded
    }
    assert.equals('<C-r>', graph.find_best(usage))
  end)
end)

describe('when a command is explicitly suppressed', function()
  it('is never suggested even with low usage', function()
    local usage = {
      u = usage_entry(10),
      ['<C-r>'] = usage_entry(0, {}, 0, true), -- suppressed
      U = usage_entry(100, {}), -- mastered → excluded
    }
    assert.is_nil(graph.find_best(usage))
  end)
end)

-- ── Ex command suggestions (#57): stricter never-tried gate ──────────────────
-- Ex commands (:g, :norm) do the work of many ordinary keystrokes in one
-- shot, so continuing to suggest one after the user has tried it even once
-- would read as ignoring feedback. Suggestions flagged ex_command = true are
-- gated on "never tried at all" (count == 0) instead of the generic
-- mastery-level gate (count < 100) every other suggestion uses.

describe('an ex_command-flagged suggestion', function()
  it('is offered when the user has never tried it', function()
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      ['ex:g'] = { cmd = 'ex:g', trigger = 'n', level = 'advanced', category = 'ex', ex_command = true },
    }
    local result = graph.find_best({ n = usage_entry(10) })
    graph.suggestions = original_suggestions
    assert.equals('ex:g', result)
  end)

  it('is not offered once tried even a single time, below the generic mastery threshold', function()
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      ['ex:g'] = { cmd = 'ex:g', trigger = 'n', level = 'advanced', category = 'ex', ex_command = true },
    }
    local result = graph.find_best({ n = usage_entry(10), ['ex:g'] = usage_entry(1) })
    graph.suggestions = original_suggestions
    assert.is_nil(result)
  end)
end)

describe('an ordinary (non ex_command) suggestion', function()
  it('still uses the generic mastery gate, not a never-tried gate', function()
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      cw = { cmd = 'cw', trigger = 'dw', level = 'beginner', category = 'edit' },
    }
    -- cw has been tried once (count=1) but is nowhere near mastered (< 100):
    -- still offered, unlike an ex_command suggestion in the same situation.
    local result = graph.find_best({ dw = usage_entry(10), cw = usage_entry(1) })
    graph.suggestions = original_suggestions
    assert.equals('cw', result)
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

  it('carries the same category as its commands.lua entry', function()
    local commands = require('tobira.commands')
    for key, sug in pairs(graph.suggestions) do
      assert.equals(commands.registry[key].category, sug.category, key .. ': category mismatch')
    end
  end)

  it('carries the ex_command flag from its commands.lua entry (#57)', function()
    local commands = require('tobira.commands')
    for key, sug in pairs(graph.suggestions) do
      assert.equals(commands.registry[key].ex_command == true, sug.ex_command == true, key .. ': ex_command mismatch')
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
    -- cw triggers . and yiw; '.' < 'y' alphabetically so . wins the tie
    assert.equals('.', graph.find_best({ cw = usage_entry(8) }))
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
      u = usage_entry(10),
      ['<C-r>'] = usage_entry(0, {}, 2), -- shown 2 times
      U = usage_entry(100, {}), -- mastered → excluded
    }
    assert.is_nil(graph.find_best(usage, 2))
  end)
end)

-- ── level-based filtering ─────────────────────────────────────────────────────

describe('when find_best has a max_level restriction', function()
  it('excludes intermediate commands when max_level is beginner', function()
    -- b is the sole trigger for B (intermediate): with beginner filter nothing is eligible
    local usage = { b = usage_entry(10) }
    assert.is_nil(graph.find_best(usage, 3, 'beginner'))
  end)

  it('includes intermediate commands when max_level is intermediate', function()
    -- b is the sole trigger for B (intermediate): with intermediate filter B is eligible
    local usage = { b = usage_entry(10) }
    assert.equals('B', graph.find_best(usage, 3, 'intermediate'))
  end)

  it('allows all commands when max_level is nil', function()
    local usage = { x = usage_entry(10) }
    assert.is_not_nil(graph.find_best(usage))
  end)
end)

-- ── mastery_level ─────────────────────────────────────────────────────────────

describe('when computing how mastered a command is from its usage count', function()
  it('returns 0 when the command has never been used', function()
    assert.equals(0, graph.mastery_level({ count = 0, sessions = {} }))
  end)

  it('returns 1 (☆) when used at least once', function()
    assert.equals(1, graph.mastery_level({ count = 1, sessions = {} }))
  end)

  it('returns 1 (☆) when count is below 100', function()
    assert.equals(1, graph.mastery_level({ count = 99, sessions = {} }))
  end)

  it('returns 2 (★) at count 100', function()
    assert.equals(2, graph.mastery_level({ count = 100, sessions = {} }))
  end)

  it('returns 2 (★) when count is below 1000', function()
    assert.equals(2, graph.mastery_level({ count = 999, sessions = {} }))
  end)

  it('returns 3 (★★) at count 1000', function()
    assert.equals(3, graph.mastery_level({ count = 1000, sessions = {} }))
  end)

  it('returns 3 (★★) when count is below 5000', function()
    assert.equals(3, graph.mastery_level({ count = 4999, sessions = {} }))
  end)

  it('returns 4 (★★★) at count 5000', function()
    assert.equals(4, graph.mastery_level({ count = 5000, sessions = {} }))
  end)
end)

-- ── is_mastered ───────────────────────────────────────────────────────────────

describe('when checking whether a command counts as mastered', function()
  it('returns true when count reaches the mastered threshold (100)', function()
    assert.is_true(graph.is_mastered({ count = 100, sessions = {} }))
  end)

  it('returns false when count is below the threshold', function()
    assert.is_false(graph.is_mastered({ count = 99, sessions = {} }))
  end)

  it('returns false when mastered but forgotten (last 2 sessions are 0)', function()
    assert.is_false(graph.is_mastered({ count = 200, sessions = { 8, 9, 0, 0 } }))
  end)
end)

-- ── guide_commands ────────────────────────────────────────────────────────────

describe('when building the list of commands to show in the guide', function()
  local commands = require('tobira.commands')

  local function mastered()
    return { count = 100, sessions = {} }
  end

  it('returns only beginner commands when no usage', function()
    local result = graph.guide_commands({})
    for _, cmds in pairs(result) do
      for _, cmd in ipairs(cmds) do
        local entry = commands.registry[cmd]
        assert.equals('beginner', entry.level, cmd .. ' should be beginner level')
      end
    end
  end)

  it('excludes a command that has reached mastery (count >= 100)', function()
    local result = graph.guide_commands({ [';'] = mastered() })
    for _, cmd in ipairs(result.motion or {}) do
      assert.not_equals(';', cmd, '; is mastered and should not appear')
    end
  end)

  it('shows intermediate commands when all beginner commands are mastered', function()
    local usage = {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.level == 'beginner' then
        usage[cmd] = mastered()
      end
    end
    local result = graph.guide_commands(usage)
    local found_intermediate = false
    for _, cmds in pairs(result) do
      for _, cmd in ipairs(cmds) do
        if commands.registry[cmd].level == 'intermediate' then
          found_intermediate = true
        end
      end
    end
    assert.is_true(found_intermediate, 'should include intermediate commands')
  end)

  it('shows advanced commands when all beginner and intermediate commands are mastered', function()
    local usage = {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and (entry.level == 'beginner' or entry.level == 'intermediate') then
        usage[cmd] = mastered()
      end
    end
    local result = graph.guide_commands(usage)
    local found_advanced = false
    for _, cmds in pairs(result) do
      for _, cmd in ipairs(cmds) do
        if commands.registry[cmd].level == 'advanced' then
          found_advanced = true
        end
      end
    end
    assert.is_true(found_advanced, 'should include advanced commands')
  end)

  it('sorts commands alphabetically within each category', function()
    local result = graph.guide_commands({})
    for _, cmds in pairs(result) do
      for i = 2, #cmds do
        assert.is_true(cmds[i - 1] <= cmds[i], cmds[i - 1] .. ' should come before ' .. cmds[i])
      end
    end
  end)

  it('includes a command that reached mastery but is now forgotten (#68)', function()
    -- count >= 100 (mastery_level 2) but the last 2 sessions are 0 after an
    -- earlier session >= 5 -> is_forgotten(data) == true -> is_mastered(data) == false
    local forgotten = { count = 200, sessions = { 8, 9, 0, 0 } }
    local result = graph.guide_commands({ [';'] = forgotten })
    local found = false
    for _, cmd in ipairs(result.motion or {}) do
      if cmd == ';' then
        found = true
      end
    end
    assert.is_true(found, '; is forgotten and should reappear in guide_commands')
  end)

  it('still excludes a command that is mastered and not forgotten (regression guard)', function()
    -- Guards the old `mastery_level(data) < 2` behavior: a real mastery streak
    -- with no forgotten signal must stay excluded after switching to is_mastered().
    local result = graph.guide_commands({ [';'] = mastered() })
    for _, cmd in ipairs(result.motion or {}) do
      assert.not_equals(';', cmd, '; is mastered and not forgotten, should stay excluded')
    end
  end)

  it('counts a forgotten command as unmastered for the ceiling calculation (#68)', function()
    -- Every beginner command forgotten (not just mastered-and-forgotten) must
    -- still count as "unmastered" so the ceiling doesn't prematurely open up
    -- to intermediate/advanced levels.
    local usage = {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.level == 'beginner' then
        usage[cmd] = { count = 200, sessions = { 8, 9, 0, 0 } }
      end
    end
    local result = graph.guide_commands(usage)
    local found_intermediate = false
    for _, cmds in pairs(result) do
      for _, cmd in ipairs(cmds) do
        if commands.registry[cmd].level == 'intermediate' then
          found_intermediate = true
        end
      end
    end
    assert.is_false(found_intermediate, 'forgotten beginner commands should keep the ceiling at beginner')
  end)
end)

-- ── knowledge_dist ────────────────────────────────────────────────────────────

describe('when summarizing how many commands are never tried, tried, familiar, or mastered', function()
  it('counts every non-compound command as never when usage is empty', function()
    local dist = graph.knowledge_dist({})
    local commands = require('tobira.commands')
    local total_non_compound = 0
    for _, entry in pairs(commands.registry) do
      if not entry.compound then
        total_non_compound = total_non_compound + 1
      end
    end
    assert.equals(total_non_compound, dist.never)
    assert.equals(0, dist.tried)
    assert.equals(0, dist.familiar)
    assert.equals(0, dist.mastered)
  end)

  it('classifies a command with count=1 as tried', function()
    local dist = graph.knowledge_dist({ [';'] = { count = 1, sessions = {} } })
    assert.equals(1, dist.tried)
  end)

  it('classifies a command with count=100 as familiar', function()
    local dist = graph.knowledge_dist({ [';'] = { count = 100, sessions = {} } })
    assert.equals(1, dist.familiar)
  end)

  it('classifies a command with count=1000 as mastered', function()
    local dist = graph.knowledge_dist({ [';'] = { count = 1000, sessions = {} } })
    assert.equals(1, dist.mastered)
  end)
end)

-- ── efficiency_gaps ───────────────────────────────────────────────────────────

describe('when a command is used heavily but a more efficient follow-up command is not', function()
  it('returns empty list when usage is empty', function()
    local gaps = graph.efficiency_gaps({})
    assert.equals(0, #gaps)
  end)

  it('returns a gap when parent is used heavily and child is untouched', function()
    local gaps = graph.efficiency_gaps({ f = { count = 200, sessions = {} } })
    local found = false
    for _, g in ipairs(gaps) do
      if g.parent == 'f' and g.child == ';' then
        found = true
        assert.equals(200, g.parent_count)
        assert.equals(0, g.child_count)
      end
    end
    assert.is_true(found, 'should find f → ; gap')
  end)

  it('omits pairs where parent count is below the threshold', function()
    local gaps = graph.efficiency_gaps({ f = { count = 10, sessions = {} } })
    for _, g in ipairs(gaps) do
      assert.not_equals('f', g.parent, 'f with only 10 uses should not generate a gap')
    end
  end)

  it('omits pairs where the child is already mastered (count >= 100)', function()
    local usage = {
      f = { count = 500, sessions = {} },
      [';'] = { count = 200, sessions = {} },
    }
    local gaps = graph.efficiency_gaps(usage)
    for _, g in ipairs(gaps) do
      assert.not_equals(';', g.child, '; is mastered and should not appear in gaps')
    end
  end)

  it('returns at most limit results when limit is specified', function()
    local usage = {}
    local commands = require('tobira.commands')
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.requires then
        usage[entry.requires] = { count = 500, sessions = {} }
      end
    end
    local gaps = graph.efficiency_gaps(usage, 3)
    assert.is_true(#gaps <= 3)
  end)

  it('sorts results by ratio descending', function()
    local gaps = graph.efficiency_gaps({
      f = { count = 500, sessions = {} },
      j = { count = 200, sessions = {} },
    })
    for i = 2, #gaps do
      assert.is_true(gaps[i - 1].ratio >= gaps[i].ratio, 'gaps should be sorted by ratio desc')
    end
  end)
end)

-- ── efficiency_gaps keymap overrides (#164) ──────────────────────────────────
-- efficiency_gaps() powers :TobiraStats's "Try these next" section -- the
-- panel's own headline actionable section, and unlike find_best() it does not
-- go through find_best's gates at all, so it needs its own override filter
-- rather than inheriting one for free. Mirrors find_best's own filter (see
-- its header comment / the "keymap overrides (#63)" describe block below): a
-- candidate whose own key is remapped is excluded regardless of whether the
-- remap is functionally equivalent to what tobira would otherwise teach.

describe('when a gap candidate has been remapped by the user', function()
  it('is excluded from efficiency_gaps, even though its trigger count would otherwise qualify it', function()
    local usage = { f = { count = 200, sessions = {} } }
    local without = graph.efficiency_gaps(usage)
    local found_without = false
    for _, g in ipairs(without) do
      if g.child == ';' then
        found_without = true
      end
    end
    assert.is_true(found_without, 'expected f -> ; to be a gap before any override is applied')

    local overrides = { [';'] = { rhs = '<Plug>(something)', equivalent = false } }
    local with = graph.efficiency_gaps(usage, nil, overrides)
    for _, g in ipairs(with) do
      assert.not_equals(';', g.child, '; must be excluded from gaps once its key is remapped')
    end
  end)

  it('does not affect an unrelated gap when a different key is overridden (regression guard)', function()
    local usage = { f = { count = 200, sessions = {} } }
    local overrides = { j = { rhs = 'gj', equivalent = false } }
    local without = graph.efficiency_gaps(usage)
    local with = graph.efficiency_gaps(usage, nil, overrides)
    assert.equals(#without, #with)
  end)

  it('still returns the candidate normally when no overrides table is passed (nil is a no-op)', function()
    local usage = { f = { count = 200, sessions = {} } }
    local gaps = graph.efficiency_gaps(usage, nil, nil)
    local found = false
    for _, g in ipairs(gaps) do
      if g.child == ';' then
        found = true
      end
    end
    assert.is_true(found)
  end)
end)

-- ── keymap overrides (#63) ────────────────────────────────────────────────────
-- find_best() is the proactive (ambient / :Tobira manual) suggestion pool.
-- Any candidate whose own key has been remapped by the user is filtered out
-- of this pool entirely, regardless of whether the remap is functionally
-- equivalent to what tobira would teach -- introducing a concept the user has
-- already deliberately bound to that key teaches nothing new. (ui/guide.lua's
-- persistent cheat-sheet, which bypasses find_best entirely, is where the
-- equivalent/different distinction actually matters -- see ui_guide_spec.lua.)

describe('when a candidate command has been remapped by the user', function()
  it('is never returned by find_best, even though it would otherwise win outright', function()
    -- nnoremap Y y$ (#63 AC1): Y requires 'p' and would otherwise win with
    -- score 10 (10 - 0); tobira's own commands.lua entry already documents Y
    -- as "same as y$", so a user who bound Y to literally run y$ has already
    -- established this on their own -- the override marks it `equivalent`,
    -- but find_best excludes it regardless (see this describe block's header).
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      Y = { cmd = 'Y', trigger = 'p', level = 'beginner', category = 'edit' },
    }
    local usage = { p = usage_entry(10) }
    local without = graph.find_best(usage)
    local overrides = { Y = { rhs = 'y$', equivalent = true } }
    local with = graph.find_best(usage, nil, nil, overrides)
    graph.suggestions = original_suggestions
    assert.equals('Y', without)
    assert.is_nil(with)
  end)

  it('removes it from the pool even when the remap is not functionally equivalent', function()
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      s = { cmd = 's', trigger = 'x', level = 'beginner', category = 'edit' },
    }
    local overrides = { s = { rhs = '<Plug>(some-plugin-thing)', equivalent = false } }
    local result = graph.find_best({ x = usage_entry(10) }, nil, nil, overrides)
    graph.suggestions = original_suggestions
    assert.is_nil(result, 's must be excluded once its key is remapped, even to something semantically different')
  end)

  it('does not affect an unrelated candidate when a different key is overridden (#63 AC3 regression guard)', function()
    -- 'j' is only ever a trigger, never a candidate's own key, so overriding
    -- it must never change find_best's ordinary behavior for j-triggered
    -- suggestions like <C-d> (nnoremap j gj must not disturb <C-d>'s scoring).
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      ['<C-d>'] = { cmd = '<C-d>', trigger = 'j', level = 'beginner', category = 'motion' },
    }
    local usage = { j = usage_entry(10) }
    local overrides = { j = { rhs = 'gj', equivalent = false } }
    local without = graph.find_best(usage)
    local with = graph.find_best(usage, nil, nil, overrides)
    graph.suggestions = original_suggestions
    assert.equals('<C-d>', without)
    assert.equals(without, with)
  end)

  it('still returns the candidate normally when no overrides table is passed (nil is a no-op, not "everything filtered")', function()
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      Y = { cmd = 'Y', trigger = 'p', level = 'beginner', category = 'edit' },
    }
    local usage = { p = usage_entry(10) }
    local result = graph.find_best(usage, nil, nil, nil)
    graph.suggestions = original_suggestions
    assert.equals('Y', result)
  end)
end)

-- ── phase 2: integration promotions (#63) ────────────────────────────────────
-- graph.find_best() consumes a plain `promotions` table (cmd -> true) computed
-- by core/integrations.lua -- graph.lua itself never detects plugins or reads
-- config, keeping it pure (see lua/tobira/CLAUDE.md's module dependency
-- rules). A promoted candidate bypasses the ordinary "trigger_count > 0" gate
-- (integrations.lua already verified real usage evidence before promoting),
-- but still has to pass every other gate (mastery / suppression / shown cap).

describe('when a suggestion is promoted by the integrations layer', function()
  it('is offered even though its trigger has never been used', function()
    assert.is_nil(graph.find_best({}))
    local promotions = { [';'] = true }
    assert.equals(';', graph.find_best({}, nil, nil, nil, promotions))
  end)

  it('still respects suppression', function()
    local usage = { [';'] = usage_entry(0, {}, 0, true) }
    local promotions = { [';'] = true }
    assert.is_nil(graph.find_best(usage, nil, nil, nil, promotions))
  end)

  it('still respects the mastery gate', function()
    -- Isolated so ';' being mastered can't also make some other real
    -- ';'-triggered suggestion (',') win ordinarily and mask the assertion.
    local original_suggestions = graph.suggestions
    graph.suggestions = {
      [';'] = { cmd = ';', trigger = 'f', level = 'beginner', category = 'motion' },
    }
    local usage = { [';'] = usage_entry(100, {}), f = usage_entry(10) }
    local promotions = { [';'] = true }
    local result = graph.find_best(usage, nil, nil, nil, promotions)
    graph.suggestions = original_suggestions
    assert.is_nil(result)
  end)

  it('only promotes the exact candidate named in the promotions table', function()
    -- ',' requires ';', and ';' has never been used -- promoting ';' (not ',')
    -- must not accidentally let ',' bypass its own trigger gate too.
    local promotions = { [';'] = true }
    assert.equals(';', graph.find_best({}, nil, nil, nil, promotions))
  end)
end)

-- ── register underuse: "+y system-clipboard promotion (#59) ─────────────────
-- Scope note: only the clipboard heuristic (y count >= 20, "+y count == 0) is
-- implemented here. The issue's "wrong paste" / register-0 heuristics are
-- explicitly deferred to a follow-up pending design review — see the issue's
-- own "Phase 2 (later, needs discussion)" section.

describe('when checking whether y is used heavily but "+y (system clipboard) is not', function()
  it('is false when y has never been used', function()
    assert.is_false(graph.is_register_underused({}))
  end)

  it('is false when y count is below the 20-use threshold', function()
    assert.is_false(graph.is_register_underused({ y = usage_entry(19) }))
  end)

  it('is true once y count reaches the 20-use threshold and "+y has never been used', function()
    assert.is_true(graph.is_register_underused({ y = usage_entry(20) }))
  end)

  it('is true for y counts well above the threshold too', function()
    assert.is_true(graph.is_register_underused({ y = usage_entry(500) }))
  end)

  it('is false once "+y has been used even once, no matter how high y count is', function()
    local usage = { y = usage_entry(500), ['"+y'] = usage_entry(1) }
    assert.is_false(graph.is_register_underused(usage))
  end)
end)

describe('when y is yanked heavily but "+y has never been used', function()
  it('does not suggest "+y below the 20-use threshold', function()
    local usage = { y = usage_entry(19) }
    assert.not_equals('"+y', graph.find_best(usage))
  end)

  it('suggests "+y once y count reaches 20', function()
    local usage = { y = usage_entry(20) }
    assert.equals('"+y', graph.find_best(usage))
  end)

  it('stops suggesting "+y once the user has used it even once', function()
    local usage = { y = usage_entry(50), ['"+y'] = usage_entry(1) }
    assert.not_equals('"+y', graph.find_best(usage))
  end)

  it('outranks an ordinary, lower-scoring suggestion once eligible', function()
    -- f=10 makes ';' score 10 (10-0); "+y's boosted score must still win.
    local usage = { y = usage_entry(20), f = usage_entry(10) }
    assert.equals('"+y', graph.find_best(usage))
  end)

  it('outranks a realistic long-term trigger count like j = 1030 (<C-d>)', function()
    -- Regression test: a fixed +1000 additive boost (score = 1000 + y.count)
    -- used to lose to <C-d>'s own score (trigger_count - cmd_count = 1030 - 0
    -- = 1030) once j's raw count climbed past ~1000, which is unremarkable
    -- for a real long-term user. "+y must win regardless of how high any
    -- ordinary candidate's own count gets.
    local usage = { y = usage_entry(20), j = usage_entry(1030) }
    assert.equals('"+y', graph.find_best(usage))
  end)

  it('outranks an even more extreme competing trigger count (50000)', function()
    -- Confirms the fix is not just a slightly-larger fixed constant that
    -- could still eventually be beaten by a big enough raw count.
    local usage = { y = usage_entry(20), j = usage_entry(50000) }
    assert.equals('"+y', graph.find_best(usage))
  end)

  it('respects suppression like any other suggestion', function()
    local usage = { y = usage_entry(20), ['"+y'] = usage_entry(0, {}, 0, true) }
    assert.is_nil(graph.find_best(usage))
  end)

  it('respects the shown-count cap like any other suggestion', function()
    local usage = { y = usage_entry(20), ['"+y'] = usage_entry(0, {}, 3) }
    assert.is_nil(graph.find_best(usage))
  end)
end)
