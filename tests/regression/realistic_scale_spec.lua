-- Realistic-scale regression suite (issue #317, part of the #315 umbrella).
--
-- Runs graph.find_best() / graph.efficiency_gaps() / graph.guide_commands() /
-- graph.is_forgotten() / graph.is_mastered() against a realistic, full-scale
-- generated usage.json fixture (tests/regression/fixture.lua) and asserts
-- product-level invariants, not just "does the function run without
-- erroring." The thin, hand-picked fixtures in tests/spec/unit/graph_spec.lua
-- are the right tool for scoring-logic unit tests; they structurally cannot
-- reproduce the scale- or duration-dependent bugs this suite targets (#290,
-- #291, #292, #307 were all found this way -- see issue #315 for the full
-- retrospective).
--
-- (Note: is_forgotten()/is_mastered() actually live in core/graph.lua, not
-- core/logger.lua -- #317's own text names them as logger functions, but
-- that's not where they're defined. logger.lua owns usage.json's session
-- rolling-window (MAX_SESSIONS) that graph.is_forgotten() reads.)
--
-- Deliberately NOT under tests/spec/ -- CI's existing test/coverage jobs
-- both point PlenaryBustedDirectory at tests/spec/ only, and lint jobs only
-- scan lua/ and plugin/, so nothing here is picked up by .github/workflows/
-- ci.yml. Per #317's design guidance, CI wiring for all of #315's
-- sub-issues is a separate, later follow-up. Run this suite manually:
--
--   nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/regression/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
--
-- Unlike tests/spec/*_spec.lua, several it() blocks below are EXPECTED TO
-- FAIL right now. They are regression trackers for real, already-filed,
-- still-open bugs (#291, #292, #307) that building this fixture reproduced
-- deterministically. Each is marked "KNOWN FAILING" with the issue it
-- tracks. Do not pending()/skip/delete them:
--   - plenary's pending() does not even execute the test body (see
--     plenary/busted.lua's mod.pending), so it would silently stop
--     exercising the real code path -- exactly the kind of hidden problem
--     this project's workflow forbids.
--   - Once the referenced issue's fix lands, the corresponding it() should
--     start passing with no changes needed here. If a KNOWN FAILING test
--     unexpectedly passes, that's a signal the fix already landed --
--     confirm against the issue tracker and delete the stale comment above
--     it (but keep the assertion itself as a normal regression test).

local this_dir = debug.getinfo(1, 'S').source:match('@(.*/)') or './'
package.path = this_dir .. '?.lua;' .. package.path

local graph = require('tobira.core.graph')
local commands = require('tobira.commands')
local fixture = require('fixture')

-- A handful of different seeds, all exercised by the smoke-test describe
-- block below, so the suite isn't accidentally only validated against one
-- lucky/unlucky draw.
local SEEDS = { 1, 42, 12345 }

-- ── Smoke tests: realistic full-scale fixture, no forced overrides ─────────

describe('when a realistic full-scale usage fixture is generated', function()
  for _, seed in ipairs(SEEDS) do
    describe('with seed ' .. seed, function()
      local usage = fixture.generate(seed)

      it('covers every non-compound command currently in the registry', function()
        local expected = fixture.registry_commands()
        local n = 0
        for _ in pairs(usage) do
          n = n + 1
        end
        assert.equals(#expected, n)
        for _, cmd in ipairs(expected) do
          assert.is_not_nil(usage[cmd])
        end
      end)

      it('does not error calling find_best/efficiency_gaps/guide_commands/knowledge_dist', function()
        assert.has_no.errors(function()
          graph.find_best(usage)
        end)
        assert.has_no.errors(function()
          graph.efficiency_gaps(usage, 10)
        end)
        assert.has_no.errors(function()
          graph.guide_commands(usage)
        end)
        assert.has_no.errors(function()
          graph.knowledge_dist(usage)
        end)
      end)

      it('reports a knowledge_dist that accounts for every registry command exactly once', function()
        local dist = graph.knowledge_dist(usage)
        local total = dist.never + dist.tried + dist.familiar + dist.mastered
        assert.equals(#fixture.registry_commands(), total)
      end)
    end)
  end
end)

-- ── Invariant: find_best() never offers a command it shouldn't ─────────────

describe('when find_best() picks a suggestion from a realistic full-scale fixture', function()
  it('never picks a command flagged suppressed', function()
    for _, seed in ipairs(SEEDS) do
      local usage = fixture.generate(seed)
      local picked = graph.find_best(usage)
      if picked then
        assert.is_false(usage[picked].suppressed, 'seed ' .. seed .. ' picked a suppressed command: ' .. picked)
      end
    end
  end)

  it('never picks an already-mastered command', function()
    for _, seed in ipairs(SEEDS) do
      local usage = fixture.generate(seed)
      local picked = graph.find_best(usage)
      if picked then
        assert.is_false(
          graph.is_mastered(usage[picked]),
          'seed ' .. seed .. ' picked an already-mastered command: ' .. picked
        )
      end
    end
  end)
end)

-- ── Invariant #1: a category with a genuinely mastered command must still ──
-- ── appear in guide_commands() (root cause of #292) ─────────────────────────
--
-- graph.guide_commands() computes ONE global ceiling level from whether any
-- beginner-level command ANYWHERE in the registry is still unmastered, then
-- hides every command above that ceiling in EVERY category. A category with
-- zero beginner-level commands of its own (currently only 'ex') can never
-- clear that ceiling until the user has mastered literally every beginner
-- command across every other category -- so it can vanish from the Guide
-- panel entirely, even when its own commands are well-used. See #292's issue
-- body for the full repro this mirrors.

describe('when a category with no beginner-level commands has a genuinely mastered command', function()
  for _, cat in ipairs(fixture.categories_without_beginner_commands()) do
    describe("category '" .. cat .. "'", function()
      local cat_cmds = fixture.commands_in_category(cat)
      local mastered_cmd = cat_cmds[1]

      local overrides = {
        -- Heavily used, well past mastery, not forgotten: real evidence the
        -- user knows this category.
        [mastered_cmd] = { count = 250, sessions = { 10, 12, 15, 20, 18, 22, 19, 21, 17, 20 } },
      }
      for i = 2, #cat_cmds do
        -- The rest of the category stays genuinely untouched, so the
        -- category still has something left to teach.
        overrides[cat_cmds[i]] = { count = 0, sessions = {} }
      end

      -- Realistic filler elsewhere in the registry (seed 42) keeps the
      -- global ceiling capped at 1 -- i.e. this isn't a fixture where the
      -- user has coincidentally mastered every beginner command everywhere
      -- else, which would trivially let any category through regardless of
      -- this bug.
      local usage = fixture.generate(42, overrides)

      it('has at least one unmastered beginner-level command elsewhere, keeping the global ceiling at 1', function()
        local found_unmastered_beginner = false
        for cmd, entry in pairs(commands.registry) do
          if not entry.compound and entry.category ~= cat and (entry.level or 'beginner') == 'beginner' then
            if not graph.is_mastered(usage[cmd]) then
              found_unmastered_beginner = true
              break
            end
          end
        end
        assert.is_true(
          found_unmastered_beginner,
          'fixture precondition not met: expected an unmastered beginner command outside ' .. cat
        )
      end)

      it('confirms the forced command is genuinely mastered', function()
        assert.is_true(graph.is_mastered(usage[mastered_cmd]))
      end)

      -- KNOWN FAILING -- tracks issue #292 (open). Do not pending()/skip/
      -- delete. guide_commands()'s global ceiling currently hides this
      -- category outright regardless of its own mastered command; this
      -- should start passing once #292's fix (the issue's own suggested
      -- direction: compute the ceiling per-category) lands.
      it('still appears in the guide_commands() output', function()
        local by_cat = graph.guide_commands(usage)
        assert.is_not_nil(by_cat[cat], "category '" .. cat .. "' is completely absent from guide_commands() (#292)")
      end)
    end)
  end
end)

-- ── Invariant #2: efficiency_gaps() top-N must not be monopolized by one ───
-- ── trigger (related to #291) ───────────────────────────────────────────────
--
-- find_best()'s score (trigger_count - cmd_count) and efficiency_gaps()'s
-- ratio (trigger_count / max(child_count, 1)) are both unbounded, so a
-- naturally high-fan-out trigger (currently the base key with the most
-- registry children sharing it as `requires`) can flood the top-N results
-- with its own children, crowding out every other genuine gap. See #291's
-- issue body: "4 of top 5 results all sharing trigger j" was the original
-- repro; this reproduces the same shape against whichever trigger currently
-- has the worst fan-out, so it stays valid as the registry grows.

describe('when efficiency_gaps() ranks gaps from a realistic full-scale fixture', function()
  local dominant_trigger, fanout = fixture.highest_fanout_trigger()
  local children = fixture.children_of(dominant_trigger)

  local overrides = { [dominant_trigger] = { count = 10000, sessions = {} } }
  for _, child in ipairs(children) do
    overrides[child] = { count = 1, sessions = {} }
  end
  local usage = fixture.generate(7, overrides)

  it('fixture precondition: the dominant trigger has at least 3 eligible children', function()
    assert.is_true(fanout >= 3, 'expected a trigger with real fan-out to test diversity against, got ' .. fanout)
  end)

  -- KNOWN FAILING -- tracks issue #291 (open, "find_best()/efficiency_gaps()
  -- let high-frequency base keys monopolize suggestions regardless of habit
  -- severity"). Do not pending()/skip/delete. This is a real design-review
  -- fix (unbounded ratio/score needs normalization, or efficiency_gaps needs
  -- top-N dedup by parent), not yet implemented. Should start passing once
  -- #291 lands.
  it('includes suggestions from at least 3 distinct trigger commands in the top 5', function()
    local gaps = graph.efficiency_gaps(usage, 5)
    local distinct_parents = {}
    for _, gap in ipairs(gaps) do
      distinct_parents[gap.parent] = true
    end
    local count = 0
    for _ in pairs(distinct_parents) do
      count = count + 1
    end
    assert.is_true(
      count >= 3,
      'top 5 efficiency_gaps() results came from only ' .. count .. ' distinct trigger(s) (#291): ' .. vim.inspect(gaps)
    )
  end)
end)

-- ── Invariant #3: a heavily-used-then-abandoned command must stay flagged ──
-- ── forgotten past 10+ session closes (root cause of #307) ─────────────────
--
-- usage[cmd].sessions is hard-capped at MAX_SESSIONS = 10 (logger.lua).
-- is_forgotten()'s historical average is always computed from at most 10
-- entries, so once enough zero-activity session closes roll the old
-- high-usage sessions off the window (empirically: as few as 3 closes past
-- abandonment), historical drops below FORGOTTEN_ADOPTED_BAR and
-- is_forgotten() unconditionally flips to false forever -- regardless of the
-- lifetime `count`, which stays huge the whole time. This directly
-- contradicts ADR 0029's stated goal. See #307's issue body for the exact
-- repro this mirrors (the same '&'-shaped sessions history).

describe('when a heavily-used command goes quiet for 10+ simulated session closes', function()
  -- Same shape as #307's own repro: heavy historical use, already tapering
  -- off in the last two sessions.
  local data = { count = 1821, sessions = { 10, 11, 12, 8, 9, 10, 11, 1, 0, 0 } }

  it(
    'fixture precondition: is genuinely forgotten immediately after the taper (not yet past the bug window)',
    function()
      assert.is_true(graph.is_forgotten(data))
    end
  )

  for i = 1, 12 do
    fixture.simulate_session_close(data.sessions, 0)
  end

  it('fixture precondition: count stays large throughout (this is not a light, easily-mastered command)', function()
    assert.equals(1821, data.count)
  end)

  -- KNOWN FAILING -- tracks issue #307 (open, priority: high). Do not
  -- pending()/skip/delete. Once the sessions[] rolling window fills with
  -- zeros, is_forgotten() currently flips to false (and is_mastered() flips
  -- to true) permanently, regardless of how large `count` is. This needs a
  -- real design decision (per #307: the fixed-ratio/session-cap interaction
  -- is the bug independent of #247's proposed adaptive-decay redesign).
  -- Should start passing once #307 lands.
  it('is still flagged is_forgotten() == true after 12 session closes of zero activity', function()
    assert.is_true(
      graph.is_forgotten(data),
      'a count=1821 command with 12 session-closes of zero recent activity is no longer flagged forgotten (#307); sessions='
        .. vim.inspect(data.sessions)
    )
  end)
end)
