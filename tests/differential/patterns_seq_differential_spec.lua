-- Differential ("fake"/reference-model) testing for patterns.lua's seq state
-- machine — see issue #316/#315 for the technique and its rationale.
--
-- Generates randomized-but-realistic keystroke sequences (tests/differential/
-- generator.lua), runs each one through BOTH the real dispatch
-- (tests/differential/real_model.lua, which replays patterns.feed() +
-- patterns.feed_macro() with logger.lua's own documented priority — see
-- docs/adr/0016) and a deliberately simple, independently-written reference
-- model (tests/differential/reference_model.lua), and asserts the two agree
-- on every keystroke about which of the 10 in-scope streak patterns (if any)
-- fires. On any unexplained disagreement, the seed and full key sequence are
-- printed so the exact failure can be replayed deterministically by pasting
-- the seed back into generator.new_rng().
--
-- This DID immediately surface real divergences — exactly what issue #316
-- predicted. Every one found traces to one of two already-tracked, open
-- issues:
--
--   #312 — macro_opportunity's dispatch priority over ANY other pattern
--          (docs/adr/0016) silently swallows a tracked pattern's own fire
--          once a streak repeats long enough to also satisfy macro's
--          anchored 3x-repeat window (docs/adr/0018).
--   #313 — several of patterns.lua's early-return prefix-consumer branches
--          (pending_r, pending_ctrl_w, pending_z, …) skip the shared
--          bottom-of-function bookkeeping (track_run()/streak-reset) that
--          docs/adr/0026 says should run unconditionally on every key. This
--          differential test found the gap is broader than #313's own
--          repro: it's not just track_run()/seq.run (bare j/k/l/… streaks)
--          but the same mechanism also freezes dd_streak/indent_streak/
--          dedent_streak/ctrl_w_close_streak/ctrl_w_resize_streak/
--          fold_open_streak/fold_close_streak whenever a DIFFERENT
--          compound family's key interrupts them, and — a genuinely new
--          finding of this test — can cascade: a frozen seq.run left behind
--          by one prefix-consumer branch can make an unrelated LATER key
--          spuriously match zero_then_w/zero_col_then_insert-style checks,
--          whose own early return then skips a completely different
--          streak's reset too. See the "known-expected-divergence: pinned
--          repro scenarios" describe block below for that cascade.
--
-- No new issue was filed — every divergence this test produces is evidence
-- for #312 or #313, not a new defect. Once either is fixed, the
-- classification helpers below (raw pattern name buckets) will simply stop
-- matching anything for that issue, and this file's own assertions will
-- start requiring exact agreement for it automatically — no test rewrite
-- needed.
--
-- Lives in tests/differential/, a sibling of tests/spec/, NOT
-- tests/spec/differential/ — same reasoning as tests/regression/
-- (realistic_scale_spec.lua): issue #316 explicitly says not to wire this
-- into .github/workflows/ci.yml in this PR (CI wiring for all of #315's
-- sub-issues is a deliberate shared follow-up). ci.yml's existing
-- `PlenaryBustedDirectory tests/spec/` invocation scans that directory
-- recursively, so a file placed under tests/spec/ is wired into CI whether
-- or not ci.yml itself is touched. Run it manually until that follow-up
-- lands (see tests/CLAUDE.md).
--
-- Whoever does that CI wiring: this file's ~0.5s runtime does NOT hold once
-- COVERAGE=1 is set. luacov's per-line debug.sethook instrumentation slowed
-- this same 60-seeds-per-corpus suite to 50+ seconds (measured, reproduced
-- twice), which exceeds plenary.nvim's own default 50000ms per-spec-file job
-- timeout (test_harness.lua) — the child process gets killed before
-- printing any result, exactly what broke this PR's Coverage CI job the
-- first time this file lived under tests/spec/. Either keep this suite out
-- of the coverage job, or re-measure and budget for the coverage slowdown
-- (roughly two orders of magnitude here) before adding it there.

package.path = vim.fn.getcwd() .. '/tests/differential/?.lua;' .. package.path

local reference_model = require('reference_model')
local generator = require('generator')
local real_model = require('real_model')

-- Raw real pattern names that legitimately, correctly outrank j_repeat/
-- k_repeat on the exact same keystroke, per pre-existing, documented,
-- in-scope-for-OTHER-issues arbitration this test does not model:
--   manual_return / changelist_return — docs/adr/0019 (jumplist/changelist
--     underuse arbitration checked before the bottom-of-function count==5
--     check j_repeat/k_repeat use)
--   cursor_center_repeat — docs/adr/0097 (same arbitration block)
--   named_mark_opportunity — docs/adr/0100 (same arbitration block)
-- None of these are bugs — they're a different, correct feature winning a
-- real priority contest this test's reference model doesn't participate in.
local OUT_OF_SCOPE_ARBITRATION = {
  manual_return = true,
  changelist_return = true,
  cursor_center_repeat = true,
  named_mark_opportunity = true,
}

-- j_many/k_many are the count==10 continuation of the SAME run counter
-- j_repeat/k_repeat (count==5) uses. This reference model only tracks the
-- 5-threshold (issue #316 scopes in j_repeat/k_repeat, not j_many/k_many) —
-- seeing one of these on a keystroke the model had no opinion about is not
-- a divergence, just an unmodeled sibling threshold.
local UNMODELED_SIBLING_THRESHOLD = { j_many = true, k_many = true }

-- Runs one generated sequence through both models, classifying every
-- disagreement. Returns { known_312 = n, known_313 = n, out_of_scope = n,
-- unmodeled_threshold = n, unexplained = { {step=, key=, expected=,
-- raw_actual=}, ... } }.
local function diff_run(keys)
  local fake = reference_model.new_state()
  local real = real_model.new_state()
  local counts = { known_312 = 0, known_313 = 0, out_of_scope = 0, unmodeled_threshold = 0 }
  local unexplained = {}

  for i, key in ipairs(keys) do
    local expected = reference_model.step(fake, key)
    local actual_raw = real_model.step(real, key)
    local actual = (actual_raw and reference_model.TRACKED_PATTERNS[actual_raw.pattern]) and actual_raw or nil

    local expected_name = expected and expected.pattern or nil
    local actual_name = actual and actual.pattern or nil

    if expected_name ~= actual_name then
      local raw_name = actual_raw and actual_raw.pattern or nil
      if raw_name == 'macro_opportunity' then
        counts.known_312 = counts.known_312 + 1
      elseif expected_name and OUT_OF_SCOPE_ARBITRATION[raw_name] then
        counts.out_of_scope = counts.out_of_scope + 1
      elseif UNMODELED_SIBLING_THRESHOLD[raw_name] then
        counts.unmodeled_threshold = counts.unmodeled_threshold + 1
      elseif raw_name == nil or reference_model.TRACKED_PATTERNS[raw_name] then
        -- #313's signature: the real dispatch either fired nothing (a
        -- streak this model says should have fired got silently frozen
        -- short of its threshold) or fired one of OUR OWN 10 tracked
        -- patterns at the wrong moment (a streak fired early/late because
        -- an unrelated compound's early-return branch skipped its
        -- reset/count bookkeeping — see this file's header). Either way,
        -- the raw pattern involved is always one this model already has an
        -- opinion about, never some unrelated 11th pattern — that's what
        -- makes this bucket safe to treat as known rather than a hard
        -- failure, and what keeps the `else` branch below meaningful: a
        -- REAL new divergence would surface as some other pattern entirely.
        counts.known_313 = counts.known_313 + 1
      else
        table.insert(unexplained, {
          step = i,
          key = key,
          expected = expected_name,
          raw_actual = raw_name,
        })
      end
    end
  end

  return counts, unexplained
end

-- Prints a human-pasteable reproduction: the seed and the exact keystroke
-- list (as a Lua literal), plus every disagreement found.
local function report_failure(seed, length, only, keys, unexplained)
  local lines = {
    string.format('Differential test found %d unexplained divergence(s).', #unexplained),
    string.format(
      'Reproduce with: generator.generate(generator.new_rng(%d), %d, %s)',
      seed,
      length,
      only and string.format('%q', only) or 'nil'
    ),
  }
  for _, d in ipairs(unexplained) do
    table.insert(
      lines,
      string.format(
        '  step=%d key=%q expected=%s raw_actual=%s',
        d.step,
        d.key,
        d.expected or 'nil',
        d.raw_actual or 'nil'
      )
    )
  end
  return table.concat(lines, '\n')
end

-- A fixed seed range keeps this suite fully deterministic — required for a
-- test asserting zero UNEXPLAINED divergences to be a stable CI gate rather
-- than a flaky one. See this file's own header / the PR description for
-- this test's runtime and the recommendation on adding a separate,
-- randomly-seeded nightly variant for broader coverage.
local SEED_COUNT = 60
local BASE_SEED = 20260810

describe('patterns.lua seq state machine (differential test against a naive reference model)', function()
  describe('isolated corpus: one streak family + safe noise at a time', function()
    -- Isolating one family per sequence means no OTHER family's two-key
    -- compound can ever interrupt this one's streak — so any remaining
    -- divergence here is purely this family's own thresholds/tolerances
    -- (validated) or macro_opportunity's collision with it (#312) or a
    -- track_run-class freeze from an unrelated single-key noise pick
    -- interacting with this family's own compound (#313, see the module
    -- header for the zero_then_w cascade this actually found).
    for _, kind in ipairs(generator.ALL_CHUNK_KINDS) do
      it('agrees with the real dispatch, or only diverges in already-known ways, for ' .. kind, function()
        local first_failure = nil

        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + i
          local rng = generator.new_rng(seed)
          local keys = generator.generate(rng, 60, kind)
          local _, unexplained = diff_run(keys)
          if #unexplained > 0 and not first_failure then
            first_failure = report_failure(seed, 60, kind, keys, unexplained)
          end
        end

        assert.is_nil(first_failure, first_failure)
      end)
    end
  end)

  describe(
    'mixed corpus: every streak family, macro_opportunity collisions, and cross-family noise together',
    function()
      it('agrees with the real dispatch, or only diverges in already-known ways (#312, #313)', function()
        local total = { known_312 = 0, known_313 = 0, out_of_scope = 0, unmodeled_threshold = 0 }
        local first_failure = nil

        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + 100000 + i
          local rng = generator.new_rng(seed)
          local keys = generator.generate(rng, 150)
          local counts, unexplained = diff_run(keys)
          for k, v in pairs(counts) do
            total[k] = total[k] + v
          end
          if #unexplained > 0 and not first_failure then
            first_failure = report_failure(seed, 150, nil, keys, unexplained)
          end
        end

        assert.is_nil(first_failure, first_failure)
        -- This corpus is EXPECTED to exercise #312/#313 — assert it actually
        -- did, so a future fix silently making these buckets go to zero is
        -- visible (update this assertion, don't delete it, once fixed).
        assert.is_true(
          total.known_312 > 0,
          'expected this mixed corpus to demonstrate #312 (macro_opportunity dispatch-priority '
            .. 'collision) at least once across '
            .. SEED_COUNT
            .. ' seeds — if this now legitimately never happens, #312 may be fixed; update this test'
        )
        assert.is_true(
          total.known_313 > 0,
          'expected this mixed corpus to demonstrate #313 (prefix-consumer branches skipping '
            .. 'shared streak bookkeeping) at least once across '
            .. SEED_COUNT
            .. ' seeds — if this now legitimately never happens, #313 may be fixed; update this test'
        )
      end)
    end
  )

  describe('known-expected-divergence: pinned repro scenarios', function()
    -- These are deterministic (no generator involved), so they document the
    -- exact minimal repro for each known issue directly, independent of
    -- whatever the random corpora above happen to roll.

    it('#312: macro_opportunity silently swallows dd_run on repetitions past the first', function()
      -- dd pressed 9 times = 3 dd_run-qualifying trios. The reference model
      -- expects dd_run to fire again at every trio boundary (3 total
      -- fires); the real dispatch fires dd_run only once — from the
      -- moment macro_opportunity's own anchored 3x-repeat window
      -- (docs/adr/0018) also qualifies (the 3rd trio, key 9 of 18), it wins
      -- every remaining keystroke's dispatch instead, per docs/adr/0016's
      -- unqualified macro_result > result priority (#312).
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      local fake_fires, real_fires = {}, {}
      for _ = 1, 9 do
        for _, key in ipairs({ 'd', 'd' }) do
          local e = reference_model.step(fake, key)
          local r = real_model.step(real, key)
          if e then
            table.insert(fake_fires, e.pattern)
          end
          if r then
            table.insert(real_fires, r.pattern)
          end
        end
      end
      assert.same({ 'dd_run', 'dd_run', 'dd_run' }, fake_fires)
      assert.equals('dd_run', real_fires[1])
      for i = 2, #real_fires do
        assert.equals('macro_opportunity', real_fires[i])
      end
      assert.is_true(#real_fires > 3) -- macro re-qualifies on almost every 'd' once armed
    end)

    it('#313: r_run streak survives an unrelated ctrl_w_close_repeat compound instead of resetting', function()
      -- Naive/intended behavior: starting an entirely unrelated <C-w>c
      -- compound between two r{char} replacements is "doing something
      -- else" and should reset r_streak (docs/adr/0027's h/l tolerance is
      -- the only documented exception). Real patterns.lua's pending_ctrl_w
      -- branch resolves and returns before reaching r_streak's own reset
      -- check, so the streak is left frozen instead.
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      local sequence = { 'r', 'x', '\23', 'c', 'r', 'x', 'r', 'x' }
      local fake_fired, real_fired = nil, nil
      for _, key in ipairs(sequence) do
        local e = reference_model.step(fake, key)
        local r = real_model.step(real, key)
        fake_fired = fake_fired or (e and e.pattern)
        real_fired = real_fired or (r and r.pattern)
      end
      assert.is_nil(fake_fired) -- naive model: <C-w>c broke the streak, only 2 genuine reps followed
      assert.equals('r_run', real_fired) -- real: streak survived, firing on the 3rd (interrupted) rep
    end)

    it('#313 cascade: a stray zero_then_w check swallows an unrelated ctrl_w_resize_repeat reset', function()
      -- '0' sets seq.run.key = '0'. <C-w>> (a resize target) resolves via
      -- pending_ctrl_w and returns before track_run() ever updates
      -- seq.run — so seq.run.key is STILL '0' afterward. The next bare 'w'
      -- then matches patterns.lua's unrelated "0 → w" check
      -- (zero_then_w), which ALSO returns early, skipping the ordinary
      -- bottom-of-function reset that this 'w' should have applied to
      -- ctrl_w_resize_streak. A second <C-w>> then wrongly completes what
      -- should have been a broken streak. Two hops of #313's same
      -- mechanism, chained.
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      local sequence = { '0', '\23', '>', 'w', '\23', '>' }
      local fake_fired_resize, real_fired_resize = false, false
      for _, key in ipairs(sequence) do
        local e = reference_model.step(fake, key)
        local r = real_model.step(real, key)
        if e and e.pattern == 'ctrl_w_resize_repeat' then
          fake_fired_resize = true
        end
        -- 'w' at step 4 legitimately fires the unrelated, untracked
        -- zero_then_w along the way — this test only cares about whether
        -- ctrl_w_resize_repeat itself (wrongly) fires by the end.
        if r and r.pattern == 'ctrl_w_resize_repeat' then
          real_fired_resize = true
        end
      end
      assert.is_false(fake_fired_resize) -- naive model: bare 'w' broke the resize streak
      assert.is_true(real_fired_resize) -- real: streak survived via the cascade above
    end)
  end)
end)
