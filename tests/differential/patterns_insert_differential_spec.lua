-- Differential ("fake"/reference-model) testing for patterns_insert.lua's
-- insert-mode state machine — see issue #329/#327 for the technique and
-- rationale (mirrors #316's patterns.lua/seq suite, but is a fully parallel
-- apparatus with no shared state or files — patterns_insert.lua shares no
-- state with patterns.lua's seq, per lua/tobira/CLAUDE.md's "Module
-- splitting policy").
--
-- Generates randomized-but-realistic keystroke-action sequences
-- (tests/differential/generator_insert.lua), runs each one through BOTH the
-- real end-to-end dispatch (tests/differential/real_model_insert.lua, which
-- replays patterns_insert.feed_insert()/feed_after_escape() PLUS
-- patterns.feed()/feed_macro() with logger.lua's own documented priority)
-- and a deliberately simple, independently-written reference model
-- (tests/differential/reference_model_insert.lua), and asserts the two
-- agree on every keystroke about which of the 6 insert-mode patterns (if
-- any) fires.
--
-- This DID surface a real, previously-unknown divergence (#334, now fixed)
-- — see the "known-expected-divergence: pinned repro scenarios" describe
-- block below for the minimal repro, and docs/adr/0116 for the fix. The
-- KNOWN_334 classification bucket stays as a regression guard.
--
-- Lives in tests/differential/, NOT tests/spec/ — same reasoning as
-- patterns_seq_differential_spec.lua: not wired into .github/workflows/ci.yml
-- by this PR (CI wiring for all of #327's sub-issues is a deliberate shared
-- follow-up), and this suite must NEVER run with COVERAGE=1 — luacov's
-- per-line instrumentation caused exactly this class of suite to exceed
-- plenary's default per-spec-file timeout on #316's own introducing PR
-- (#323). tests/ is excluded from the coverage gate by .luacov anyway.
--
-- Run it manually:
--   nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

package.path = vim.fn.getcwd() .. '/tests/differential/?.lua;' .. package.path

local reference_model = require('reference_model_insert')
local generator = require('generator_insert')
local real_model = require('real_model_insert')

-- #334 (fixed): patterns.feed_macro()'s MACRO_EDIT_KEYS set ({d,c,y,>,<}
-- plus EDIT_OP_KEYS = {x,X,i,I,a,A,o,O,s,S}) was designed for Normal-mode
-- tokens, but logger.lua's handle_insert_key() feeds it the SAME raw
-- characters an insert-mode keystroke stream produces (canonical or key —
-- see docs/adr/0016's cross-mode feed_macro call). An ordinary identifier
-- typed 3 times in a row (e.g. any word containing 'i', 'a', 'o', 's', 'x',
-- 'd', 'c', or 'y', which is most English/code identifiers) could anchor-
-- match macro_opportunity purely because its own letters happened to
-- overlap MACRO_EDIT_KEYS — a coincidence with no relationship to "the user
-- is repeating an edit". `patterns.feed_macro()` now takes an
-- `is_normal_key` parameter (docs/adr/0116) and only counts a
-- MACRO_EDIT_KEYS match for tokens fed from the Normal-mode call site;
-- handle_insert_key's own call site always passes false, so insert-mode
-- characters can no longer anchor-match macro_opportunity at all. The
-- KNOWN_334 classification bucket below stays as a safety net for any
-- future call site that reuses feed_macro without threading this through.
local KNOWN_334 = { macro_opportunity = true, visual_block_opportunity = true }

-- Raw real pattern names that legitimately, correctly outrank
-- insert_co_oneshot on the exact same keystroke, per pre-existing,
-- documented, in-scope-for-patterns.lua arbitration this test does not
-- model. patterns.lua's inner_feed has several "single motion key X,
-- immediately followed by an insert-entry key" checks keyed off
-- seq.run.key — the exact same keystroke shape <Esc> X i/a/A/I (the
-- one-shot round trip insert_co_oneshot targets) can also satisfy:
--   x_then_insert         — seq.run.key=='x', count==1, any INSERT_KEYS key
--   zero_col_then_insert  — seq.run.key=='0', key=='i'
--   dollar_then_append    — seq.run.key=='$', key=='a'
-- None of these are bugs — each is a real, independently correct
-- suggestion for that exact keystroke shape, and docs/adr/0016's
-- unqualified "result wins over co_result" priority is what's supposed to
-- happen when two genuinely-applicable patterns disagree on one keystroke.
local OUT_OF_SCOPE_ARBITRATION = {
  x_then_insert = true,
  zero_col_then_insert = true,
  dollar_then_append = true,
}

-- Prints a human-pasteable reproduction: the seed and the exact action list
-- (as a Lua literal), plus every disagreement found.
local function action_literal(a)
  if a.mode == 'insert' then
    return string.format(
      '{mode=%q, canonical=%s, char=%s}',
      a.mode,
      a.canonical and string.format('%q', a.canonical) or 'nil',
      a.char and string.format('%q', a.char) or 'nil'
    )
  end
  return string.format('{mode=%q, key=%q}', a.mode, a.key)
end

local function report_failure(seed, length, only, actions, unexplained)
  local lines = {
    string.format('Differential test found %d unexplained divergence(s).', #unexplained),
    string.format(
      'Reproduce with: generator_insert.generate(generator_insert.new_rng(%d), %d, %s)',
      seed,
      length,
      only and string.format('%q', only) or 'nil'
    ),
  }
  for _, d in ipairs(unexplained) do
    table.insert(
      lines,
      string.format(
        '  step=%d action=%s expected=%s raw_actual=%s',
        d.step,
        action_literal(d.action),
        d.expected or 'nil',
        d.raw_actual or 'nil'
      )
    )
  end
  return table.concat(lines, '\n')
end

-- Runs one generated action sequence through both models, classifying every
-- disagreement. Returns { known_334 = n }, { {step=, action=, expected=,
-- raw_actual=}, ... }.
local function diff_run(actions)
  local fake = reference_model.new_state()
  local real = real_model.new_state()
  local counts = { known_334 = 0, out_of_scope = 0 }
  local unexplained = {}

  for i, action in ipairs(actions) do
    local expected, actual_raw
    if action.mode == 'insert' then
      expected = reference_model.step_insert(fake, action.canonical, action.char)
      actual_raw = real_model.step_insert(real, action.canonical, action.char)
    else
      expected = reference_model.step_normal_watch(fake, action.key)
      actual_raw = real_model.step_normal_watch(real, action.key)
    end
    local actual = (actual_raw and reference_model.TRACKED_PATTERNS[actual_raw.pattern]) and actual_raw or nil

    local expected_name = expected and expected.pattern or nil
    local actual_name = actual and actual.pattern or nil

    if expected_name ~= actual_name then
      local raw_name = actual_raw and actual_raw.pattern or nil
      if KNOWN_334[raw_name] then
        counts.known_334 = counts.known_334 + 1
      elseif expected_name and OUT_OF_SCOPE_ARBITRATION[raw_name] then
        counts.out_of_scope = counts.out_of_scope + 1
      else
        table.insert(unexplained, {
          step = i,
          action = action,
          expected = expected_name,
          raw_actual = raw_name,
        })
      end
    end
  end

  return counts, unexplained
end

-- A fixed seed range keeps this suite fully deterministic — required for a
-- test asserting zero UNEXPLAINED divergences to be a stable CI gate rather
-- than a flaky one.
local SEED_COUNT = tonumber(os.getenv('TOBIRA_DIFFERENTIAL_SEEDS')) or 150
local BASE_SEED = 20260814

describe('patterns_insert.lua insert-mode state machine (differential test against a naive reference model)', function()
  describe('isolated corpus: one pattern family + safe noise at a time', function()
    for _, kind in ipairs(generator.ALL_CHUNK_KINDS) do
      it('agrees with the real dispatch, or only diverges in already-known ways, for ' .. kind, function()
        local first_failure = nil

        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + i
          local rng = generator.new_rng(seed)
          local actions = generator.generate(rng, 60, kind)
          local _, unexplained = diff_run(actions)
          if #unexplained > 0 and not first_failure then
            first_failure = report_failure(seed, 60, kind, actions, unexplained)
          end
        end

        assert.is_nil(first_failure, first_failure)
      end)
    end
  end)

  describe(
    'mixed corpus: every pattern family, macro_opportunity collisions, and cross-family noise together',
    function()
      it('agrees with the real dispatch, or only diverges in already-known ways (#334)', function()
        local total = { known_334 = 0, out_of_scope = 0 }
        local first_failure = nil

        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + 100000 + i
          local rng = generator.new_rng(seed)
          local actions = generator.generate(rng, 150)
          local counts, unexplained = diff_run(actions)
          for k, v in pairs(counts) do
            total[k] = total[k] + v
          end
          if #unexplained > 0 and not first_failure then
            first_failure = report_failure(seed, 150, nil, actions, unexplained)
          end
        end

        assert.is_nil(first_failure, first_failure)
        -- #334 is fixed: is_normal_key=false on every insert-mode feed_macro
        -- call means an insert-mode character can no longer anchor-match
        -- MACRO_EDIT_KEYS, so the known_334 bucket no longer triggers at all
        -- across this corpus. This is the flipped regression guard — a
        -- future call site reusing feed_macro incorrectly would make this
        -- fail again.
        assert.equals(
          0,
          total.known_334,
          'expected #334 (insert-mode keystrokes anchor-matching macro_opportunity via '
            .. 'MACRO_EDIT_KEYS letter overlap) to no longer reproduce across '
            .. SEED_COUNT
            .. ' seeds now that is_normal_key is wired up — if this is nonzero again, #334 regressed'
        )
        assert.is_true(
          total.out_of_scope > 0,
          'expected this mixed corpus to demonstrate x_then_insert legitimately outranking '
            .. 'insert_co_oneshot at least once across '
            .. SEED_COUNT
            .. ' seeds — if this now legitimately never happens, update this test'
        )
      end)
    end
  )

  describe('known-expected-divergence: pinned repro scenarios', function()
    -- Deterministic (no generator involved) — documents the exact minimal
    -- repro for #334 directly, independent of whatever the random corpora
    -- above happen to roll.

    it('fixed (#334): typing the same 6+ char word 3 times no longer swallows insert_completion_repeat', function()
      -- 'diamond' contains 'i', 'a', 'o', 'd' — all MACRO_EDIT_KEYS members
      -- (i/a via EDIT_OP_KEYS' INSERT_KEYS, d via the operator set) — so the
      -- macro_buf window "d i a m o n d <space>" (8 tokens, within
      -- MACRO_MAX_LEN=15) would anchor-match on the 3rd repetition, 30ms
      -- apart (well within MACRO_WINDOW_MS), same as any genuine 3x
      -- edit-repeat — EXCEPT every token here is fed with
      -- is_normal_key=false (docs/adr/0116), so it can no longer satisfy
      -- MACRO_EDIT_KEYS at all and macro_opportunity never fires.
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      local fake_fires, real_fires = {}, {}
      for _ = 1, 3 do
        for c in ('diamond'):gmatch('.') do
          local e = reference_model.step_insert(fake, nil, c)
          local r = real_model.step_insert(real, nil, c)
          if e then
            table.insert(fake_fires, e.pattern)
          end
          if r then
            table.insert(real_fires, r.pattern)
          end
        end
        local e = reference_model.step_insert(fake, nil, ' ')
        local r = real_model.step_insert(real, nil, ' ')
        if e then
          table.insert(fake_fires, e.pattern)
        end
        if r then
          table.insert(real_fires, r.pattern)
        end
      end
      -- Naive/intended model: insert_completion_repeat fires on BOTH the
      -- 2nd and 3rd occurrences' boundaries — the ring already contains a
      -- match both times.
      assert.same({ 'insert_completion_repeat', 'insert_completion_repeat' }, fake_fires)
      -- Fixed: real dispatch now matches — macro_opportunity can never
      -- anchor-match an insert-mode-only token stream, so nothing
      -- silently swallows insert_completion_repeat's 3rd fire anymore.
      assert.same({ 'insert_completion_repeat', 'insert_completion_repeat' }, real_fires)
    end)

    it('x_then_insert legitimately outranks insert_co_oneshot when the one-shot motion is exactly x', function()
      -- x_then_insert (patterns.lua) fires whenever a single 'x' is
      -- immediately followed by an insert-entry key (i/a/A/I/o/O/s/S) — the
      -- exact same keystroke shape as <Esc> x i, the one-shot round trip
      -- insert_co_oneshot is designed to catch. Both patterns are correctly
      -- applicable to this sequence; docs/adr/0016's unqualified
      -- "result wins over co_result" priority is what's SUPPOSED to happen
      -- here, so x_then_insert winning is not a bug.
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      reference_model.step_insert(fake, '<Esc>')
      real_model.step_insert(real, '<Esc>')
      reference_model.step_normal_watch(fake, 'x')
      local real_mid = real_model.step_normal_watch(real, 'x')
      assert.is_nil(real_mid, 'the motion itself must not fire anything')
      local fake_result = reference_model.step_normal_watch(fake, 'i')
      local real_result = real_model.step_normal_watch(real, 'i')
      assert.equals('insert_co_oneshot', fake_result.pattern) -- naive model: unaware of x_then_insert
      assert.equals('x_then_insert', real_result.pattern) -- real: x_then_insert legitimately wins
    end)
  end)
end)
