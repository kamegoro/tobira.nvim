-- Differential ("fake"/reference-model) testing for patterns_cmdline.lua's
-- four independent cmdline detectors — see issue #330/#327 for the
-- technique and its rationale, and #316/#315 for the sibling suite this one
-- mirrors (tests/differential/patterns_seq_differential_spec.lua).
--
-- Generates randomized-but-realistic SESSIONS of full command-line
-- submissions (tests/differential/generator_cmdline.lua) — not raw
-- normal-mode keystrokes, a fundamentally different vocabulary than
-- patterns.lua's own differential suite — and runs each session through
-- BOTH the real dispatch (tests/differential/real_model_cmdline.lua, which
-- replays tokenize()/command_arg() and all four real detectors in
-- logger.lua's own order) and a deliberately simple, independently-written
-- reference model (tests/differential/reference_model_cmdline.lua).
--
-- Two things are asserted on every submission:
--
--  1. Mutual exclusivity by construction (docs/adr/0095-cmdline-history-recall-detection.md):
--     "for any given submitted command line, at most one of the four
--     cmdline detectors can ever return non-nil." This is checked directly
--     against the REAL functions (#fires <= 1), not inferred from the
--     reference model's own routing — a real violation here would mean two
--     of the four real guards let their detector fire on the same
--     submission, exactly the hazard #241's own detector was designed to
--     avoid double-firing.
--  2. The one pattern that DOES fire (if any) matches what the independent
--     reference model expects.
--
-- Lives in tests/differential/, NOT tests/spec/ — same reasoning as the
-- patterns.lua differential suite: issue #330 says not to wire this into
-- .github/workflows/ci.yml in this PR, and this suite must NEVER run with
-- COVERAGE=1 (luacov's per-line instrumentation slows a suite shaped like
-- this by roughly two orders of magnitude — measured on #316's own PR,
-- #323 — which exceeds plenary's default 50s per-spec-file job timeout).
-- tests/ is excluded from the coverage gate by .luacov anyway. Run manually:
--
--   nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

package.path = vim.fn.getcwd() .. '/tests/differential/?.lua;' .. package.path

local reference_model = require('reference_model_cmdline')
local generator = require('generator_cmdline')
local real_model = require('real_model_cmdline')

-- Renders a session for a human-pasteable failure report.
local function describe_session(session)
  if session.action == 'cancel' then
    return string.format('{presses=%d, action=cancel}', session.presses)
  end
  return string.format(
    '{presses=%d, action=submit, text=%q, kind=%s}',
    session.presses,
    session.event.text,
    session.event.kind
  )
end

-- Runs one generated session list through both models. Returns:
--   mutual_exclusivity_violations: sessions where the REAL dispatch let more
--     than one of the four detectors fire on the same submission.
--   unexplained: sessions where the real dispatch's single winner (if any)
--     didn't match the reference model's expectation.
local function run_sessions(sessions)
  local fake = reference_model.new_state()
  local real = real_model.new_state()
  local mutual_exclusivity_violations = {}
  local unexplained = {}
  local fire_counts = {}

  for i, session in ipairs(sessions) do
    for _ = 1, session.presses do
      reference_model.press_history_key(fake)
      real_model.press_history_key(real)
    end

    if session.action == 'cancel' then
      reference_model.cancel_session(fake)
      real_model.cancel_session(real)
    else
      local event = session.event
      local expected = reference_model.submit(fake, event)
      local actual = real_model.submit(real, event.text, { line = event.line, win_count = event.win_count })

      if #actual.fires > 1 then
        table.insert(mutual_exclusivity_violations, { step = i, session = session, fires = actual.fires })
      end

      local expected_name = expected and expected.pattern or nil
      local actual_name = actual.fires[1] and actual.fires[1].pattern or nil
      if expected_name ~= actual_name then
        table.insert(unexplained, {
          step = i,
          session = session,
          expected = expected_name,
          actual = actual_name,
        })
      end
      if actual_name then
        fire_counts[actual_name] = (fire_counts[actual_name] or 0) + 1
      end
    end
  end

  return mutual_exclusivity_violations, unexplained, fire_counts
end

local function report_mutual_exclusivity_failure(seed, length, only, violations)
  local lines = {
    string.format('Mutual-exclusivity-by-construction (docs/adr/0095) violated %d time(s).', #violations),
    string.format(
      'Reproduce with: generator.generate_sessions(generator.new_rng(%d), %d, %s)',
      seed,
      length,
      only and string.format('%q', only) or 'nil'
    ),
  }
  for _, v in ipairs(violations) do
    local fired_names = {}
    for _, f in ipairs(v.fires) do
      table.insert(fired_names, f.pattern .. '(' .. f.source .. ')')
    end
    table.insert(
      lines,
      string.format(
        '  step=%d session=%s fired=%s',
        v.step,
        describe_session(v.session),
        table.concat(fired_names, ', ')
      )
    )
  end
  return table.concat(lines, '\n')
end

local function report_divergence_failure(seed, length, only, unexplained)
  local lines = {
    string.format('Differential test found %d unexplained divergence(s).', #unexplained),
    string.format(
      'Reproduce with: generator.generate_sessions(generator.new_rng(%d), %d, %s)',
      seed,
      length,
      only and string.format('%q', only) or 'nil'
    ),
  }
  for _, d in ipairs(unexplained) do
    table.insert(
      lines,
      string.format(
        '  step=%d session=%s expected=%s actual=%s',
        d.step,
        describe_session(d.session),
        d.expected or 'nil',
        d.actual or 'nil'
      )
    )
  end
  return table.concat(lines, '\n')
end

-- Fixed seed range: deterministic, required for a suite asserting zero
-- divergences/violations to be a stable CI gate rather than a flaky one —
-- same precedent as patterns_seq_differential_spec.lua.
local SEED_COUNT = 60
local BASE_SEED = 20260814

describe('patterns_cmdline.lua cmdline state machine (differential test against a naive reference model)', function()
  describe('isolated corpus: one detector family + realistic session noise at a time', function()
    for _, kind in ipairs(generator.ALL_EVENT_KINDS) do
      it('agrees with the real dispatch for ' .. kind .. ' (pattern + mutual exclusivity)', function()
        local first_violation, first_divergence = nil, nil

        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + i
          local rng = generator.new_rng(seed)
          local sessions = generator.generate_sessions(rng, 60, kind)
          local violations, unexplained = run_sessions(sessions)
          if #violations > 0 and not first_violation then
            first_violation = report_mutual_exclusivity_failure(seed, 60, kind, violations)
          end
          if #unexplained > 0 and not first_divergence then
            first_divergence = report_divergence_failure(seed, 60, kind, unexplained)
          end
        end

        assert.is_nil(first_violation, first_violation)
        assert.is_nil(first_divergence, first_divergence)
      end)
    end
  end)

  describe('mixed corpus: every detector family, history-recall sessions, and cancel/restart together', function()
    it('agrees with the real dispatch (pattern + mutual exclusivity) across the whole mixed corpus', function()
      local first_violation, first_divergence = nil, nil
      local total_fires = {}

      for i = 1, SEED_COUNT do
        local seed = BASE_SEED + 100000 + i
        local rng = generator.new_rng(seed)
        local sessions = generator.generate_sessions(rng, 200)
        local violations, unexplained, fire_counts = run_sessions(sessions)
        for name, n in pairs(fire_counts) do
          total_fires[name] = (total_fires[name] or 0) + n
        end
        if #violations > 0 and not first_violation then
          first_violation = report_mutual_exclusivity_failure(seed, 200, nil, violations)
        end
        if #unexplained > 0 and not first_divergence then
          first_divergence = report_divergence_failure(seed, 200, nil, unexplained)
        end
      end

      assert.is_nil(first_violation, first_violation)
      assert.is_nil(first_divergence, first_divergence)

      -- This corpus is EXPECTED to organically cross every detector's
      -- threshold at least once across 60 seeds of 200 sessions each — proves
      -- the corpus isn't vacuously green (never exercising the interesting
      -- cases) rather than genuinely agreeing on them.
      for pattern in pairs(reference_model.TRACKED_PATTERNS) do
        assert.is_true(
          (total_fires[pattern] or 0) > 0,
          'expected the mixed corpus to fire ' .. pattern .. ' at least once across ' .. SEED_COUNT .. ' seeds'
        )
      end
    end)
  end)

  describe('known-expected-divergence: pinned repro scenarios', function()
    -- These are deterministic (no generator involved) — direct confirmations
    -- of specific, documented behavior from docs/adr/0095 and the issues
    -- that shaped it (#241, #259), run through both models the same way the
    -- random corpora above are.

    local function submit(fake, real, event)
      local expected = reference_model.submit(fake, event)
      local actual = real_model.submit(real, event.text, { line = event.line, win_count = event.win_count })
      return expected, actual
    end

    it('substitute_repeat fires on the 2nd distinct line, substitute_repeat_wide on the 3rd', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      local e1 = { kind = 'sub', text = 's/foo/bar/', pattern = 'foo', replacement = 'bar', ranged = false, line = 1 }
      local e2 = { kind = 'sub', text = 's/foo/bar/', pattern = 'foo', replacement = 'bar', ranged = false, line = 2 }
      local e3 = { kind = 'sub', text = 's/foo/bar/', pattern = 'foo', replacement = 'bar', ranged = false, line = 3 }
      local exp1, act1 = submit(fake, real, e1)
      assert.is_nil(exp1)
      assert.equals(0, #act1.fires)
      local exp2, act2 = submit(fake, real, e2)
      assert.equals('substitute_repeat', exp2.pattern)
      assert.equals('substitute_repeat', act2.fires[1].pattern)
      local exp3, act3 = submit(fake, real, e3)
      assert.equals('substitute_repeat_wide', exp3.pattern)
      assert.equals('substitute_repeat_wide', act3.fires[1].pattern)
    end)

    it('ex_file_pingpong fires on returning to the first of two alternating files', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      local a = { kind = 'ex_file', text = 'e a.txt', word = 'e', arg = 'a.txt' }
      local b = { kind = 'ex_file', text = 'e b.txt', word = 'e', arg = 'b.txt' }
      submit(fake, real, a)
      submit(fake, real, b)
      local exp, act = submit(fake, real, a)
      assert.equals('ex_file_pingpong', exp.pattern)
      assert.equals('ex_file_pingpong', act.fires[1].pattern)
    end)

    it('tabnew_run fires on the 3rd distinct one-file-per-tab open, and a mid-streak split resets it', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      local t1 = { kind = 'tabnew', text = 'tabnew a.txt', arg = 'a.txt', win_count = 1 }
      -- A window split happened before this 2nd :tabnew fired (win_count ~= 1) — resets the streak.
      local t2 = { kind = 'tabnew', text = 'tabnew b.txt', arg = 'b.txt', win_count = 2 }
      local t3 = { kind = 'tabnew', text = 'tabnew c.txt', arg = 'c.txt', win_count = 1 }
      local t4 = { kind = 'tabnew', text = 'tabnew d.txt', arg = 'd.txt', win_count = 1 }
      local exp1, act1 = submit(fake, real, t1)
      assert.is_nil(exp1)
      assert.equals(0, #act1.fires)
      local exp2, act2 = submit(fake, real, t2) -- split reset: streak restarts at 1, no fire
      assert.is_nil(exp2)
      assert.equals(0, #act2.fires)
      local exp3, act3 = submit(fake, real, t3) -- streak 2
      assert.is_nil(exp3)
      assert.equals(0, #act3.fires)
      local exp4, act4 = submit(fake, real, t4) -- streak 3, fires
      assert.equals('tabnew_run', exp4.pattern)
      assert.equals('tabnew_run', act4.fires[1].pattern)
    end)

    it('cmdline_history_recall fires on the 2nd retype of an unclaimed command (e.g. :edit)', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      local event = { kind = 'other', text = 'edit somefile.txt', word = 'edit', arg = 'somefile.txt' }
      local exp1, act1 = submit(fake, real, event)
      assert.is_nil(exp1)
      assert.equals(0, #act1.fires)
      local exp2, act2 = submit(fake, real, event)
      assert.equals('cmdline_history_recall', exp2.pattern)
      assert.equals('cmdline_history_recall', act2.fires[1].pattern)
    end)

    it(
      'never fires either substitute_repeat or cmdline_history_recall for a retyped :s (word-family exclusion)',
      function()
        local fake, real = reference_model.new_state(), real_model.new_state()
        -- Confirms the retyped :s claims substitute_repeat and that
        -- cmdline_history_recall never ALSO fires for the same submission.
        local event =
          { kind = 'sub', text = 's/foo/bar/', pattern = 'foo', replacement = 'bar', ranged = false, line = 1 }
        local event2 =
          { kind = 'sub', text = 's/foo/bar/', pattern = 'foo', replacement = 'bar', ranged = false, line = 2 }
        submit(fake, real, event)
        local exp, act = submit(fake, real, event2)
        assert.equals('substitute_repeat', exp.pattern)
        assert.equals(1, #act.fires)
        assert.equals('substitute_repeat', act.fires[1].pattern)
      end
    )

    it(
      'a ranged substitute (:%s) retyped twice fires NEITHER detector — accepted trade-off, docs/adr/0095',
      function()
        local fake, real = reference_model.new_state(), real_model.new_state()
        local event =
          { kind = 'sub', text = '%s/foo/bar/', pattern = 'foo', replacement = 'bar', ranged = true, line = 1 }
        submit(fake, real, event)
        local exp, act = submit(fake, real, event)
        assert.is_nil(exp)
        assert.equals(0, #act.fires)
      end
    )

    it('a bare trivial command (:w) retyped many times never fires cmdline_history_recall (#241 floor)', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      local event = { kind = 'other', text = 'w', word = 'w', arg = nil }
      for _ = 1, 5 do
        local exp, act = submit(fake, real, event)
        assert.is_nil(exp)
        assert.equals(0, #act.fires)
      end
    end)

    it('genuine <Up> history recall does not fire cmdline_history_recall (#259 exact repro)', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      local event = { kind = 'other', text = 'g/uniquepattern123/d', word = 'g', arg = '/uniquepattern123/d' }
      submit(fake, real, event) -- manual submission #1
      reference_model.press_history_key(fake)
      real_model.press_history_key(real)
      local exp, act = submit(fake, real, event) -- recalled via <Up>, resubmitted unchanged
      assert.is_nil(exp)
      assert.equals(0, #act.fires)
    end)

    it('canceling a session with <Up> pressed does not leak recalled_via_history into the next session', function()
      local fake, real = reference_model.new_state(), real_model.new_state()
      reference_model.press_history_key(fake)
      real_model.press_history_key(real)
      reference_model.cancel_session(fake)
      real_model.cancel_session(real)

      local event = { kind = 'other', text = 'g/pattern/d', word = 'g', arg = '/pattern/d' }
      submit(fake, real, event) -- manual #1, flag must be false here (cancel cleared it)
      local exp, act = submit(fake, real, event) -- manual #2 -> should fire normally
      assert.equals('cmdline_history_recall', exp.pattern)
      assert.equals('cmdline_history_recall', act.fires[1].pattern)
    end)
  end)
end)
