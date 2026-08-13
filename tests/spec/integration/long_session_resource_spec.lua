-- Long, realistic-scale editing session driven entirely through the real
-- vim.on_key() dispatch path (never a direct call into suggest.lua's or
-- logger.lua's internals), asserting that per-session resource usage stays
-- bounded at the end versus the start. See docs/adr/0047 (adoption-watch
-- rolling buffer) and docs/adr/0006/0095 (cmdline pattern state) for the
-- production mechanisms this exercises.

local logger = require('tobira.core.logger')
local suggest = require('tobira.core.suggest')
local config = require('tobira.core.config')

-- Test-local disk cleanup, mirroring logger_spec.lua/suggest_spec.lua's helper of the
-- same name.
local _data_file = vim.fn.stdpath('data') .. '/tobira/usage.json'
local function wipe_disk()
  pcall(os.remove, _data_file)
end

local ESC = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
local CR = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
local CTRL_R = vim.api.nvim_replace_termcodes('<C-r>', true, true, true)
local CTRL_D = vim.api.nvim_replace_termcodes('<C-d>', true, true, true)
local CTRL_U = vim.api.nvim_replace_termcodes('<C-u>', true, true, true)
local CTRL_O = vim.api.nvim_replace_termcodes('<C-o>', true, true, true)
local CTRL_I = vim.api.nvim_replace_termcodes('<C-i>', true, true, true)
local BS = vim.api.nvim_replace_termcodes('<BS>', true, true, true)

-- Sends `keys` through the real typed-key pipeline (feedkeys with the 't'
-- flag, so typed ~= '' inside the on_key callback) so vim.on_key() sees
-- exactly what a human typing would produce. This test exists specifically
-- to catch leaks in that dispatch wiring (suggest.lua's watch_adoption(),
-- logger.lua's handle_cmdline_key()), so every stimulus below must arrive
-- this way rather than through a direct Lua call into their internals.
local function type_keys(keys)
  vim.fn.feedkeys(keys, 'xt')
  vim.api.nvim_feedkeys('', 'x', false)
end

local function goto_line(n)
  vim.api.nvim_win_set_cursor(0, { n, 0 })
end

local function run_ex(text)
  type_keys(':' .. text .. CR)
end

local SUB_LINE_COUNT = 40
local ECHO_COUNT = 40
local RING_TOKEN_COUNT = 15

-- Seeds a scratch buffer with SUB_LINE_COUNT lines, each holding one
-- guaranteed-unique word, so a bare (no-range) :s run after navigating to
-- that line always produces a real, distinct edit -- required for
-- track_substitute() to ever be invoked (see logger.lua's changedtick-gated
-- vim.schedule() call site, docs/adr/0015).
local function seed_buffer()
  vim.cmd('enew!')
  local lines = {}
  for i = 1, SUB_LINE_COUNT do
    lines[i] = string.format('alpha bravo target%02d charlie delta', i)
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  goto_line(1)
end

-- Runs SUB_LINE_COUNT distinct bare :s/// substitutions, one per line, each
-- with a unique pattern/replacement pair -- grows patterns_cmdline.lua's
-- substitute_state.entries by one real, production-verified entry per call.
local function run_substitutions()
  for i = 1, SUB_LINE_COUNT do
    goto_line(i)
    run_ex(string.format('s/target%02d/replaced%02d/', i, i))
  end
  -- Credit is deferred to vim.schedule() (docs/adr/0015) -- one wait after
  -- the whole batch is enough: each deferred check only compares the
  -- buffer's current changedtick against its own captured pre-edit
  -- baseline, and every real edit here strictly advances changedtick, so
  -- batching (vs. waiting after every single call) cannot change which
  -- checks pass.
  vim.wait(50)
end

-- Runs ECHO_COUNT distinct, harmless Ex commands (never :s/:e/:b/:tabnew) --
-- grows patterns_cmdline.lua's history_recall_state.entries by one real
-- entry per distinct command line.
local function run_distinct_ex_commands()
  for i = 1, ECHO_COUNT do
    run_ex(string.format('echo "unique message %d"', i))
  end
end

-- Types RING_TOKEN_COUNT distinct identifiers of >= 6 chars each, separated
-- by a space (which finalizes the in-progress completion token) -- grows
-- patterns_insert.lua's completion ring, which is expected to stay capped.
local RING_WORDS = {
  'alphabetical',
  'bureaucracy',
  'chocolate',
  'directory',
  'elephant',
  'fireplace',
  'greenhouse',
  'happiness',
  'important',
  'junction',
  'knowledge',
  'landscape',
  'marketing',
  'necessary',
  'operation',
}

-- feedkeys() run with the 'x' (execute) flag behaves like :normal! for mode
-- purposes: it auto-leaves Insert mode the instant one call's queued keys
-- run out, even if the very next call re-enters it. A whole Insert-mode
-- session (entry key, every typed character, exit key) must therefore
-- travel in ONE feedkeys() call, never split across separate type_keys()
-- calls, or the later characters land back in Normal mode and get
-- interpreted as commands instead of text.
local function run_insert_tokens()
  local session = 'o'
  for i = 1, RING_TOKEN_COUNT do
    session = session .. RING_WORDS[i] .. ' '
  end
  session = session .. ESC
  type_keys(session)
end

-- General normal/insert-mode filler: motions, operators, a genuine dd streak
-- and a genuine insert-mode backspace streak, all driven through real
-- keystrokes so at least one suggestion is shown via the REAL
-- pattern-detection -> on_pattern -> suggest.queue chain, not only via the
-- direct suggest.show() calls in run_curated_suggestions() below. Run AFTER
-- run_substitutions() so its dd's cannot delete any of the still-pending
-- targetNN lines that loop still needs.
local function run_general_filler()
  goto_line(1)
  type_keys('wwbb')
  type_keys('jjkk')
  type_keys('yy')
  type_keys('dddddd') -- 3x dd -- dd_run streak (threshold 3, patterns.lua)
  vim.wait(5) -- let the queued dd_run suggestion resolve before queuing the next one
  -- One combined feedkeys() call -- see run_insert_tokens()'s header comment
  -- for why 'i' + text + <BS>s + <Esc> cannot be split across separate
  -- type_keys() calls.
  type_keys('i' .. 'placeholder' .. BS .. BS .. BS .. BS .. BS .. ESC) -- 5x <BS> -- insert_bs_repeat
  vim.wait(5)
end

-- A curated, collision-free set of real suggestion commands (see
-- graph.suggestions, derived from commands.lua) used to deterministically
-- drive a realistic MIX of adopted / never-adopted suggestions through the
-- real do_show() -> watch_adoption() -> vim.on_key() path -- this is the
-- part of the session #310's leak actually lives in. `keys` is a COMPLETE,
-- self-contained keystroke sequence for that command (never leaves a
-- pending operator/mode), chosen so no two entries' typed forms could ever
-- satisfy another entry's suffix match (buf_matches() compares exact
-- trailing substrings of equal length) -- avoids any accidental
-- cross-adoption between entries that would make the leaked-count math
-- ambiguous.
local SUGGESTIONS = {
  { cmd = ';', keys = ';', adopt = true },
  { cmd = ',', keys = ',', adopt = false },
  { cmd = 'A', keys = 'A' .. ESC, adopt = true },
  { cmd = 'O', keys = 'O' .. ESC, adopt = false },
  { cmd = 'D', keys = 'D', adopt = true },
  { cmd = 'I', keys = 'I' .. ESC, adopt = false },
  { cmd = 'H', keys = 'H', adopt = true },
  { cmd = 'M', keys = 'M', adopt = false },
  { cmd = 'L', keys = 'L', adopt = true },
  { cmd = 'P', keys = 'P', adopt = false },
  { cmd = 'T', keys = 'Tx', adopt = true },
  { cmd = '}', keys = '}', adopt = false },
  { cmd = '{', keys = '{', adopt = true },
  { cmd = 'zt', keys = 'zt', adopt = false },
  { cmd = 'zb', keys = 'zb', adopt = true },
  { cmd = 'W', keys = 'W', adopt = false },
  { cmd = 'B', keys = 'B', adopt = true },
  { cmd = '%', keys = '%', adopt = false },
  { cmd = '~', keys = '~', adopt = true },
  { cmd = 'yiw', keys = 'yiw', adopt = false },
  { cmd = 'ciw', keys = 'ciw' .. ESC, adopt = true },
  { cmd = 'ddp', keys = 'ddp', adopt = false },
  { cmd = 'J', keys = 'J', adopt = true },
  { cmd = '<C-r>', keys = CTRL_R, adopt = false },
  { cmd = '<C-d>', keys = CTRL_D, adopt = true },
  { cmd = '<C-u>', keys = CTRL_U, adopt = false },
  { cmd = '<C-o>', keys = CTRL_O, adopt = true },
  { cmd = '<C-i>', keys = CTRL_I, adopt = false },
  { cmd = '{n}j', keys = '3j', adopt = true },
  { cmd = '{n}k', keys = '3k', adopt = false },
}

-- Shows every command in SUGGESTIONS via the real suggest.show() (the same
-- production entry point fire_ambient()/queue() use), then immediately types
-- the real adopting keystrokes for the ones marked adopt = true, before
-- moving to the next entry -- so a given entry's own watch_adoption() buffer
-- never has a chance to observe a LATER entry's typed keys (it doesn't exist
-- yet), and only ever sees an EARLIER entry's typed keys, which cannot
-- satisfy its own suffix match (see SUGGESTIONS' header comment for why the
-- chosen set is pairwise collision-free anyway).
local function run_curated_suggestions()
  goto_line(2)
  type_keys('yy') -- seed the unnamed register so 'P' has something to paste
  for _, entry in ipairs(SUGGESTIONS) do
    suggest.show(entry.cmd, 'long_session_resource_spec')
    if entry.adopt then
      type_keys(entry.keys)
    end
  end
end

-- Runs the full scripted session once: real Ex-command traffic, real
-- normal/insert-mode editing, and a curated real suggestion-adoption mix --
-- roughly 2200 real keystrokes end to end. Returns the measurements each
-- it() below asserts on.
local function run_long_session()
  wipe_disk()
  logger.reset()
  config.reset()
  suggest.reset_session()
  logger.on_pattern = nil
  suggest.on_show = nil
  suggest.on_adopt = nil

  config.setup({ idle_delay = 1, suggestion_cooldown = 0, max_shown = 5 })
  logger.setup()
  logger.on_pattern = suggest.queue
  suggest.on_show = function() end
  suggest.on_adopt = function() end
  suggest.setup_idle()

  seed_buffer()

  -- Session-start baseline: measured after the same production wiring
  -- init.lua performs (logger.setup() + suggest.setup_idle()), before any
  -- suggestion has ever been shown.
  local baseline_on_key = vim.on_key()

  run_substitutions()
  run_distinct_ex_commands()
  run_general_filler()
  run_insert_tokens()
  run_curated_suggestions()

  -- Let any still-pending idle-suggestion defer_fn timers resolve so the
  -- final on_key count reflects the session's settled end state, not a
  -- mid-flight one.
  vim.wait(50)

  local sizes = logger.get_state_table_sizes()

  return {
    baseline_on_key = baseline_on_key,
    final_on_key = vim.on_key(),
    substitute_entries = sizes.substitute_entries,
    history_recall_entries = sizes.history_recall_entries,
    insert_completion_ring = sizes.insert_completion_ring,
  }
end

local function cleanup()
  logger.on_pattern = nil
  suggest.on_show = nil
  suggest.on_adopt = nil
  suggest.reset_session()
  if vim.fn.mode() ~= 'n' then
    pcall(vim.api.nvim_input, ESC)
  end
  wipe_disk()
end

describe('after a long, realistic session with a mix of adopted and un-adopted suggestions', function()
  after_each(cleanup)

  -- Tracks issue #310 (suggest.lua's watch_adoption() registers a
  -- persistent vim.on_key namespace per shown suggestion, torn down only on
  -- adoption; reset_session() is never called from production code). This
  -- assertion is currently FAILING: this session shows every SUGGESTIONS
  -- entry and adopts only half of them, so the leaked-namespace count is far
  -- above any small, well-understood bound. Do not silently skip or delete
  -- this test -- it should start passing once #310 is fixed.
  it('keeps the number of active vim.on_key namespaces within a small bound of the session-start baseline', function()
    local result = run_long_session()
    -- Generous headroom: the persistent tobira_logger/tobira_idle
    -- namespaces are already inside baseline_on_key (measured after setup);
    -- this only allows a couple more beyond that, not one per shown-and-
    -- unadopted suggestion.
    local BOUND = 3
    assert.is_true(
      result.final_on_key <= result.baseline_on_key + BOUND,
      string.format(
        'expected on_key namespaces to stay near baseline (%d + %d), got %d -- tracks #310',
        result.baseline_on_key,
        BOUND,
        result.final_on_key
      )
    )
  end)
end)

describe('after a long session with many distinct Ex commands', function()
  after_each(cleanup)

  -- Tracks issue #314 (patterns_cmdline.lua's substitute_state.entries and
  -- history_recall_state.entries grow without bound or eviction). Currently
  -- FAILING: SUB_LINE_COUNT/ECHO_COUNT distinct commands each create one
  -- permanent entry, well past any reasonable cap. Do not silently skip or
  -- delete this test -- it should start passing once #314 is fixed.
  it('keeps substitute-repeat tracking state below a reasonable cap', function()
    local result = run_long_session()
    local CAP = 20
    assert.is_true(
      result.substitute_entries <= CAP,
      string.format('expected <= %d substitute entries, got %d -- tracks #314', CAP, result.substitute_entries)
    )
  end)

  it('keeps Ex-command history-recall tracking state below a reasonable cap', function()
    local result = run_long_session()
    local CAP = 20
    assert.is_true(
      result.history_recall_entries <= CAP,
      string.format('expected <= %d history-recall entries, got %d -- tracks #314', CAP, result.history_recall_entries)
    )
  end)
end)

describe('after a long session with many distinct insert-mode completion tokens', function()
  after_each(cleanup)

  -- Locks in currently-correct behavior (unlike #310/#314 above, this is
  -- NOT a known-failing regression guard) -- patterns_insert.lua's
  -- completion ring already evicts its oldest entry past RING_SIZE (8).
  it('keeps the completion-repeat ring capped at its fixed size', function()
    local result = run_long_session()
    assert.is_true(
      result.insert_completion_ring <= 8,
      string.format('expected insert completion ring <= 8, got %d', result.insert_completion_ring)
    )
  end)
end)
