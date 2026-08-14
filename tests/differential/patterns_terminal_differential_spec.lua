-- Differential ("fake"/reference-model) testing for patterns_terminal.lua's
-- <Esc>-streak state machine — see issue #331/#327 for the technique and
-- rationale, and tests/differential/patterns_seq_differential_spec.lua for
-- the established quality bar this follows.
--
-- patterns_terminal.lua has exactly one pattern and a 2-line threshold+latch
-- implementation, so this suite is deliberately lighter than the seq
-- differential test's generator/reference-model apparatus (per issue #331's
-- own design guidance — a full weighted-random-generator setup covering many
-- interacting compounds would be manufactured complexity for a module this
-- small). What this suite adds beyond the existing direct-call unit tests in
-- tests/spec/unit/patterns_terminal_spec.lua is coverage of the RAW-BYTE
-- dispatch layer those unit tests never exercise (they only ever call
-- feed_terminal() with an already-canonicalized '<Esc>' string or nil) —
-- see real_model_terminal.lua and reference_model_terminal.lua's headers.
--
-- No new divergence was found while building this suite. The one concrete,
-- previously-unverified risk investigated — whether a Meta/Alt chord (e.g.
-- <M-x>) could ever arrive at vim.on_key() split into a bare <Esc> byte
-- followed by a separate character (which would let ordinary Alt-key shell
-- usage, like bash's Alt-b/Alt-f, spuriously feed the <Esc> streak) — was
-- empirically checked (nvim_replace_termcodes('<M-x>', true, true, true)
-- returns one atomic 4-byte K_SPECIAL-prefixed sequence, never two events)
-- and confirmed to be a non-issue; the "Meta chords never contribute to a
-- streak" scenario below locks that in as a regression guard.
--
-- Lives in tests/differential/, a sibling of tests/spec/, NOT
-- tests/spec/differential/ — same reasoning as patterns_seq_differential_spec.lua:
-- this suite must NEVER run with COVERAGE=1 (luacov's per-line instrumentation
-- makes suites like this exceed plenary's default per-file job timeout — see
-- tests/CLAUDE.md). Not wired into .github/workflows/ci.yml by this PR (issue
-- #331 explicitly says not to). Run it manually:
--
-- nvim --headless --noplugin -u tests/minimal_init.lua \
--   -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

package.path = vim.fn.getcwd() .. '/tests/differential/?.lua;' .. package.path

local reference_model = require('reference_model_terminal')
local real_model = require('real_model_terminal')
local generator = require('generator_terminal')

-- Runs one generated sequence through both models, asserting full agreement
-- on the pattern name AND cmd at every single keystroke. Unlike the seq
-- differential test, there is no known-expected-divergence bucket here —
-- patterns_terminal.lua has no open, tracked issues (see this PR's
-- description), so ANY disagreement is a genuine, previously-unknown
-- divergence worth investigating before this suite may be considered green.
local function diff_run(keys)
  local fake = reference_model.new_state()
  local real = real_model.new_state()

  for i, key in ipairs(keys) do
    local expected = reference_model.step(fake, key)
    local actual = real_model.step(real, key)

    local expected_name = expected and expected.pattern or nil
    local actual_name = actual and actual.pattern or nil

    if expected_name ~= actual_name then
      return {
        step = i,
        key_bytes = { string.byte(key, 1, #key) },
        expected = expected_name,
        actual = actual_name,
      }
    end

    if expected and actual then
      assert.equals(expected.cmd, actual.cmd, string.format('cmd mismatch at step %d', i))
    end
  end

  return nil
end

local function report_failure(seed, length, divergence)
  return string.format(
    'Differential test found a divergence.\n'
      .. 'Reproduce with: generator.generate(generator.new_rng(%d), %d)\n'
      .. '  step=%d key_bytes=%s expected=%s actual=%s',
    seed,
    length,
    divergence.step,
    vim.inspect(divergence.key_bytes),
    divergence.expected or 'nil',
    divergence.actual or 'nil'
  )
end

-- A fixed seed range keeps this suite fully deterministic — required for a
-- test asserting zero divergences to be a stable CI gate rather than a flaky
-- one, same reasoning as patterns_seq_differential_spec.lua.
local SEED_COUNT = 60
local BASE_SEED = 20260814

describe(
  'patterns_terminal.lua <Esc>-streak state machine (differential test against a naive reference model)',
  function()
    it(
      'agrees with the real dispatch on realistic terminal-mode keystroke noise interleaved with <Esc> streaks',
      function()
        local first_failure = nil

        for i = 1, SEED_COUNT do
          local seed = BASE_SEED + i
          local rng = generator.new_rng(seed)
          local keys = generator.generate(rng, 80)
          local divergence = diff_run(keys)
          if divergence and not first_failure then
            first_failure = report_failure(seed, 80, divergence)
          end
        end

        assert.is_nil(first_failure, first_failure)
      end
    )

    describe('pinned scenarios: real dispatch through the raw-byte translation layer', function()
      -- These are deterministic (no generator involved) so they document the
      -- exact minimal repro for each scenario directly, independent of what
      -- the random corpus above happens to roll.

      local function replay(raw_keys)
        local real = real_model.new_state()
        local fires = {}
        for _, key in ipairs(raw_keys) do
          local result = real_model.step(real, key)
          if result then
            table.insert(fires, result.pattern)
          end
        end
        return fires
      end

      local ESC = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)

      it('fires once on exactly two consecutive <Esc> raw bytes', function()
        assert.same({ 'terminal_esc_repeat' }, replay({ ESC, ESC }))
      end)

      it('does not fire on a single <Esc> (ordinary REPL-cancel usage)', function()
        assert.same({}, replay({ ESC }))
      end)

      it('does not fire when real shell noise separates two <Esc> presses', function()
        -- Simulates: cancel a reverse-search with <Esc>, type more, then
        -- separately dismiss something else with <Esc> — never the "stuck,
        -- hammering the same key twice" reflex this pattern targets.
        local ctrl_r = vim.api.nvim_replace_termcodes('<C-r>', true, true, true)
        assert.same({}, replay({ ctrl_r, 'g', 'i', 't', ESC, 'l', 's', ESC }))
      end)

      it('fires exactly once even when the user keeps hammering <Esc> past the 2nd press', function()
        assert.same({ 'terminal_esc_repeat' }, replay({ ESC, ESC, ESC, ESC, ESC, ESC }))
      end)

      it('re-arms after an interrupted streak and fires on the next fresh pair', function()
        local ctrl_c = vim.api.nvim_replace_termcodes('<C-c>', true, true, true)
        assert.same({ 'terminal_esc_repeat' }, replay({ ESC, ctrl_c, ESC, ESC }))
      end)

      it('typing the actual fix (<C-\\><C-n>) never itself contributes to a future streak', function()
        local ctrl_bslash = vim.api.nvim_replace_termcodes('<C-\\>', true, true, true)
        local ctrl_n = vim.api.nvim_replace_termcodes('<C-n>', true, true, true)
        -- One streak fires, the user takes the suggested escape hatch, then a
        -- brand-new streak must still require two FRESH <Esc> presses.
        assert.same(
          { 'terminal_esc_repeat', 'terminal_esc_repeat' },
          replay({ ESC, ESC, ctrl_bslash, ctrl_n, ESC, ESC })
        )
      end)

      it('a Meta/Alt chord (single atomic raw sequence) never contributes to the <Esc> streak', function()
        -- Empirically verified (see this file's header): <M-x> arrives at
        -- vim.on_key() as ONE atomic K_SPECIAL-prefixed raw sequence, never as
        -- a bare <Esc> byte followed by a separate 'x'. Interleaving Meta
        -- chords between real <Esc> presses must not help or hinder the
        -- streak — each chord is just an ordinary key that resets it.
        local meta_x = vim.api.nvim_replace_termcodes('<M-x>', true, true, true)
        assert.same({}, replay({ meta_x, ESC, meta_x, ESC }))
      end)

      it('shell history navigation (multi-byte K_SPECIAL raw sequences) never canonicalizes as <Esc>', function()
        local up = vim.api.nvim_replace_termcodes('<Up>', true, true, true)
        local down = vim.api.nvim_replace_termcodes('<Down>', true, true, true)
        assert.same({}, replay({ up, up, down, ESC, up }))
      end)
    end)
  end
)
