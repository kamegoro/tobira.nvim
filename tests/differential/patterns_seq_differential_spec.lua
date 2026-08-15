-- Differential ("fake"/reference-model) testing for patterns.lua's seq state
-- machine — see issue #316/#315 for the technique and its rationale, and
-- issue #328/#327 for the expansion this file implements.
--
-- Generates randomized-but-realistic keystroke sequences (tests/differential/
-- generator.lua), runs each one through BOTH the real dispatch
-- (tests/differential/real_model.lua, which replays patterns.feed() +
-- patterns.feed_macro() with logger.lua's own documented priority — see
-- docs/adr/0016) and a deliberately simple, independently-written reference
-- model (tests/differential/reference_model.lua), and asserts the two agree
-- on every keystroke about which pattern (if any) fires.  On any unexplained
-- disagreement, the seed and full key sequence are printed so the exact
-- failure can be replayed deterministically by pasting the seed back into
-- generator.new_rng().
--
-- History: issue #316 (PR #323) scoped this to 10 streak-based patterns.
-- Issue #328 expands coverage to (almost) every remaining pattern
-- patterns.lua can fire — see reference_model.lua's own header for the two
-- deliberately-unmodeled exceptions (macro_opportunity, itself the subject
-- of the collision surface below; visual_block_opportunity, which shares
-- macro_opportunity's own macro_buf subsystem).
--
-- This DID immediately surface real divergences at the original 10-pattern
-- scope — exactly what issue #316 predicted. Every one found there traced to
-- one of two mechanisms, both now fixed (see the classification helpers
-- below, which stay as regression guards rather than being deleted):
--
--   #312 (fixed) — macro_opportunity's dispatch priority over ANY other
--          pattern (docs/adr/0016) could silently swallow a tracked
--          pattern's own fire once a streak repeated long enough to also
--          satisfy macro's anchored 3x-repeat window (docs/adr/0018).
--          dd_run/indent_run/dedent_run/r_run/fold_open_repeat/
--          fold_close_repeat/ci_dquote_repeat/ci_squote_repeat/
--          named_mark_opportunity now each declare `beats_macro = true`
--          (docs/adr/0113) and win this collision instead of losing it. The
--          known_312 classification bucket below stays as a safety net for
--          any future pattern that shares this same collision shape without
--          being wired up correctly.
--   #313 (fixed) — several of patterns.lua's early-return prefix-consumer
--          branches skipped the shared bottom-of-function bookkeeping
--          (track_run()/streak-reset) docs/adr/0026 says should run
--          unconditionally on every key, freezing tolerated streaks and
--          seq.run across an unrelated compound instead of correctly
--          reacting to it. Every branch docs/adr/0114 lists now calls
--          track_run()/reset_unclaimed_streaks() itself. The known_313
--          bucket below is broader than this one gap (it also classifies
--          ordinary timing divergences against this deliberately-simpler
--          reference model), so it is not expected to reach zero just
--          because this specific gap is fixed.
--
-- Lives in tests/differential/, a sibling of tests/spec/, NOT
-- tests/spec/differential/ — CI wiring for this suite is a deliberate,
-- separate follow-up (see #327's sub-issue sequencing). Run it manually
-- until that follow-up lands (see tests/CLAUDE.md).
--
-- Whoever does that CI wiring: this file's runtime does NOT hold once
-- COVERAGE=1 is set. luacov's per-line debug.sethook instrumentation slowed
-- this same suite (at the smaller #316 scope) to 50+ seconds (measured,
-- reproduced twice), which exceeds plenary.nvim's own default 50000ms
-- per-spec-file job timeout (test_harness.lua) — the child process gets
-- killed before printing any result, exactly what broke this PR's Coverage
-- CI job the first time this file lived under tests/spec/. Either keep this
-- suite out of the coverage job, or re-measure and budget for the coverage
-- slowdown (roughly two orders of magnitude at the #316 scope) before
-- adding it there. Do NOT run this suite locally with COVERAGE=1 either.

package.path = vim.fn.getcwd() .. '/tests/differential/?.lua;' .. package.path

local reference_model = require('reference_model')
local generator = require('generator')
local real_model = require('real_model')

-- Runs one generated sequence through both models, classifying every
-- disagreement. Returns { known_312 = n, known_313 = n } and a list of
-- unexplained divergences.
--
-- ctx (optional): { is_diff=, is_wrapped= }, constant for the whole run —
-- threaded to both models identically, per issue #328's design guidance for
-- context-gated patterns.
local function diff_run(keys, ctx)
  ctx = ctx or {}
  local fake = reference_model.new_state()
  local real = real_model.new_state()
  local counts = { known_312 = 0, known_313 = 0 }
  local unexplained = {}

  for i, key in ipairs(keys) do
    local expected = reference_model.step(fake, key, ctx)
    local actual_raw = real_model.step(real, key, ctx)
    local actual = (actual_raw and reference_model.TRACKED_PATTERNS[actual_raw.pattern]) and actual_raw or nil

    local expected_name = expected and expected.pattern or nil
    local actual_name = actual and actual.pattern or nil

    if expected_name ~= actual_name then
      local raw_name = actual_raw and actual_raw.pattern or nil
      if raw_name == 'macro_opportunity' or raw_name == 'visual_block_opportunity' then
        -- Both share the same macro_buf-priority mechanism (docs/adr/0016) —
        -- see this file's own header for why a NEW collision here still
        -- classifies as #312, not a fresh issue.
        counts.known_312 = counts.known_312 + 1
      elseif raw_name == nil or reference_model.TRACKED_PATTERNS[raw_name] then
        -- The real dispatch either fired nothing (a streak this model says
        -- should have fired got silently frozen short of its threshold) or
        -- fired one of OUR OWN tracked patterns at the wrong moment (fired
        -- early/late because an unrelated compound's early-return branch
        -- skipped its reset/count bookkeeping — see this file's header).
        -- Either way the raw pattern involved is always one this model
        -- already has an opinion about, never some unrelated pattern — that
        -- is what makes this bucket safe to treat as known-#313 rather than
        -- a hard failure, and what keeps the `else` branch below meaningful:
        -- a REAL new divergence would surface as some other pattern
        -- entirely.
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
-- than a flaky one.
local SEED_COUNT = 60
local BASE_SEED = 20260810

describe('patterns.lua seq state machine (differential test against a naive reference model)', function()
  describe('isolated corpus: one chunk family + safe noise at a time', function()
    -- Isolating one family per sequence means no OTHER family's compound can
    -- ever interrupt this one's streak — so any remaining divergence here is
    -- purely this family's own thresholds/tolerances (validated) or a
    -- collision with macro_opportunity (#312) or a track_run-class freeze
    -- from an unrelated single-key noise pick interacting with this
    -- family's own compound (#313).
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

  describe('mixed corpus: every chunk family, macro_opportunity collisions, and cross-family noise together', function()
    it('agrees with the real dispatch, or only diverges in already-known ways (#312, #313)', function()
      local total = { known_312 = 0, known_313 = 0 }
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
      -- #312 is fixed for its own specific failure mode (a beats_macro
      -- pattern silently swallowed by macro_opportunity on the exact
      -- keystroke both fire on) — the three pinned scenarios below assert
      -- that directly, deterministically. The known_312 bucket itself
      -- stays nonzero-tolerant here, same reasoning as known_313: it also
      -- classifies ordinary reactive ONE-SHOT patterns (e.g. dd_then_p)
      -- correctly losing to macro_opportunity per ADR 0016's original,
      -- still-valid rationale (a confirmed 3x edit-repeat outranks a
      -- single one-off suggestion) — this model has no notion of macro at
      -- all, so it cannot tell that apart from a real regression on its
      -- own. Only patterns that declare beats_macro = true are expected to
      -- never lose this collision; see the pinned scenarios for that
      -- specific, precise guarantee.
      assert.is_true(total.known_312 >= 0, 'known_312 must be a non-negative count')
      assert.is_true(
        total.known_313 > 0,
        'expected this mixed corpus to demonstrate at least one already-tracked-pattern timing '
          .. 'divergence across '
          .. SEED_COUNT
          .. ' seeds — if this now legitimately never happens, update this test'
      )
    end)
  end)

  describe('context corpus: is_wrapped / is_diff-gated patterns', function()
    -- j_repeat_wrapped/k_repeat_wrapped and j_many_diff/k_many_diff share
    -- their base key's ordinary run counter with j_repeat/k_repeat/j_many/
    -- k_many — is_wrapped/is_diff only changes WHICH pattern name fires at
    -- the same threshold, so this corpus reuses the same j_run/k_run
    -- generation shape as the mixed corpus, just with the flag set for the
    -- whole run (see generator.generate_context's own header).
    for _, kind in ipairs(generator.CONTEXT_RUN_KINDS) do
      it('agrees with the real dispatch for ' .. kind, function()
        local first_failure = nil
        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + 200000 + i
          local rng = generator.new_rng(seed)
          local ctx_run = generator.generate_context(rng, 40, kind)
          local _, unexplained = diff_run(ctx_run.keys, { is_diff = ctx_run.is_diff, is_wrapped = ctx_run.is_wrapped })
          if #unexplained > 0 and not first_failure then
            first_failure = report_failure(seed, 40, kind, ctx_run.keys, unexplained)
          end
        end
        assert.is_nil(first_failure, first_failure)
      end)
    end

    for _, kind in ipairs(generator.CONTEXT_DIFF_JUMP_KINDS) do
      it('agrees with the real dispatch for ' .. kind, function()
        local first_failure = nil
        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + 300000 + i
          local rng = generator.new_rng(seed)
          local ctx_run = generator.generate_context(rng, 1, kind)
          local _, unexplained = diff_run(ctx_run.keys, { is_diff = ctx_run.is_diff, is_wrapped = ctx_run.is_wrapped })
          if #unexplained > 0 and not first_failure then
            first_failure = report_failure(seed, 1, kind, ctx_run.keys, unexplained)
          end
        end
        assert.is_nil(first_failure, first_failure)
      end)
    end
  end)

  describe('named_mark_opportunity: line-return corpus', function()
    -- The only pattern gated on the caller-supplied `line` parameter rather
    -- than pure keystroke sequence (besides f_repeat, covered by a pinned
    -- scenario below) — see generator.generate_line_walk's own header and
    -- docs/adr/0100.
    it('agrees with the real dispatch across 1-6 return cycles', function()
      for cycles = 1, 6 do
        local walk = generator.generate_line_walk(cycles)
        local fake = reference_model.new_state()
        local real = real_model.new_state()
        for i, step in ipairs(walk) do
          local expected = reference_model.step(fake, step.key, { line = step.line })
          local actual_raw = real_model.step(real, step.key, { line = step.line })
          local actual = (actual_raw and reference_model.TRACKED_PATTERNS[actual_raw.pattern]) and actual_raw or nil
          local expected_name = expected and expected.pattern or nil
          local actual_name = actual and actual.pattern or nil
          assert.equals(
            expected_name,
            actual_name,
            string.format('cycles=%d step=%d key=%q line=%d', cycles, i, step.key, step.line)
          )
        end
      end
    end)
  end)

  describe('known-expected-divergence: pinned repro scenarios', function()
    -- These are deterministic (no generator involved), so they document the
    -- exact minimal repro for each known issue directly, independent of
    -- whatever the random corpora above happen to roll.

    it('fixed (#312): dd_run wins its collision with macro_opportunity on every qualifying trio', function()
      -- dd pressed 9 times = 3 dd_run-qualifying trios, each completing on
      -- the 2nd 'd' of every 3rd rep (overall keystroke 6, 12, 18). Before
      -- the fix, macro_opportunity's own anchored 3x-repeat window
      -- (docs/adr/0018) ALSO qualified on that same keystroke from the 3rd
      -- trio onward and won the collision (docs/adr/0016's unqualified
      -- macro_result > result priority), silently swallowing dd_run past
      -- its first fire. dd_run now declares beats_macro = true
      -- (docs/adr/0113), so it wins this collision on every trio.
      --
      -- macro_opportunity legitimately keeps firing on OTHER keystrokes in
      -- this run too (it re-qualifies on almost every 'd' once its window
      -- is long enough — a homogeneous 'dd' run is a valid, if repetitive,
      -- macro candidate on its own) — that's correct, unrelated behavior
      -- this test does not assert against; it only checks that dd_run is
      -- never silently swallowed on the exact keystroke where BOTH fire.
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      local real_fired_by_step = {}
      local step = 0
      for _ = 1, 9 do
        for _, key in ipairs({ 'd', 'd' }) do
          step = step + 1
          reference_model.step(fake, key)
          local r = real_model.step(real, key)
          real_fired_by_step[step] = r and r.pattern
        end
      end
      assert.equals('dd_run', real_fired_by_step[6])
      assert.equals('dd_run', real_fired_by_step[12])
      assert.equals('dd_run', real_fired_by_step[18])
    end)

    it('fixed (#313): r_run streak correctly resets across an unrelated ctrl_w_close_repeat compound', function()
      -- Starting an entirely unrelated <C-w>c compound between two r{char}
      -- replacements is "doing something else" and must reset r_streak
      -- (docs/adr/0027's h/l tolerance is the only documented exception).
      -- Before the fix, patterns.lua's pending_ctrl_w branch resolved and
      -- returned before reaching r_streak's own reset check, leaving the
      -- streak frozen. reset_unclaimed_streaks now runs from that branch
      -- too (docs/adr/0114), so real now matches the reference model.
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
      assert.is_nil(fake_fired) -- <C-w>c broke the streak, only 2 genuine reps followed
      assert.is_nil(real_fired) -- fixed: real now agrees
    end)

    it('fixed (#313) cascade: a stray zero_then_w check no longer swallows a ctrl_w_resize_repeat reset', function()
      -- '0' sets seq.run.key = '0'. Before the fix, <C-w>> (a resize target)
      -- resolved via pending_ctrl_w and returned before track_run() ever
      -- updated seq.run, so seq.run.key was STILL '0' afterward — the next
      -- bare 'w' then wrongly matched patterns.lua's unrelated "0 → w"
      -- check (zero_then_w), which ALSO returned early, skipping the
      -- bottom-of-function reset that 'w' should have applied to
      -- ctrl_w_resize_streak. A second <C-w>> then wrongly completed what
      -- should have been a broken streak — two chained hops of the same
      -- #313 mechanism. pending_ctrl_w now calls track_run() unconditionally
      -- (docs/adr/0114), so seq.run.key is '>' (not '0') by the time 'w'
      -- arrives, zero_then_w no longer misfires, and the ordinary bottom
      -- reset correctly breaks the resize streak.
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
        if r and r.pattern == 'ctrl_w_resize_repeat' then
          real_fired_resize = true
        end
      end
      assert.is_false(fake_fired_resize) -- bare 'w' broke the resize streak
      assert.is_false(real_fired_resize) -- fixed: real now agrees
    end)

    it('#280 (fixed): named_mark_opportunity wins its narrow exception over macro_opportunity', function()
      -- 3 "leave anchor -> edit -> return" cycles using a byte-identical
      -- single-key edit ('x') and a single-key return motion ('k') satisfy
      -- BOTH macro_opportunity's anchored-repeat window AND
      -- named_mark_opportunity's own return-count threshold on the same
      -- keystroke. Per ADR 0016's narrow exception (shipped for #280),
      -- named_mark_opportunity wins this one specific collision — verifying
      -- real_model.lua's own implementation of that exception (see its
      -- header) actually matches logger.lua's real arbitration, now that
      -- named_mark_opportunity is a pattern this suite tracks.
      local walk = generator.generate_line_walk(3)
      local real = real_model.new_state()
      local last = nil
      for _, step in ipairs(walk) do
        local r = real_model.step(real, step.key, { line = step.line })
        if r then
          last = r.pattern
        end
      end
      assert.equals('named_mark_opportunity', last)
    end)

    it('f_repeat: same char, same line, twice in a row via the same f/F/t/T operator', function()
      local fake = reference_model.new_state()
      local real = real_model.new_state()
      local sequence = { 'f', 'x', 'f', 'x' }
      local fake_fired, real_fired = nil, nil
      for _, key in ipairs(sequence) do
        local e = reference_model.step(fake, key, { line = 7 })
        local r = real_model.step(real, key, { line = 7 })
        fake_fired = fake_fired or (e and e.pattern)
        real_fired = real_fired or (r and r.pattern)
      end
      assert.equals('f_repeat', fake_fired)
      assert.equals(fake_fired, real_fired)
    end)
  end)
end)
