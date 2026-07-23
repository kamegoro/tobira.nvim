-- Pure terminal-mode key-streak detection (#110). No vim.* calls —
-- patterns_terminal.lua has zero Neovim dependencies.
--
-- A separate pure state machine from patterns.lua's normal-mode seq/feed and
-- patterns_insert.lua's insert-mode iseq/feed_insert: shares no state with
-- either and is never called from the same code path (logger.lua only calls
-- feed_terminal() while its mode cache says mode() == 't') — see
-- lua/tobira/CLAUDE.md's "Module splitting policy".
--
-- logger.lua feeds a canonical key name ('<Esc>') for the one key this cares
-- about, or nil for any other key (including <C-\><C-n> itself, and anything
-- the terminal job consumes) — same convention as feed_insert().

local patterns_terminal = require('tobira.core.patterns_terminal')

local function tseq()
  return patterns_terminal.new_terminal_seq()
end

describe('when the user presses <Esc> twice in a row with no effect in terminal mode', function()
  it('does not fire on the first <Esc>', function()
    local s = tseq()
    local result = patterns_terminal.feed_terminal(s, '<Esc>')
    assert.is_nil(result, 'a single Esc has an ordinary purpose (e.g. cancel) and must not fire yet')
  end)

  it('fires terminal_esc_repeat suggesting <C-\\><C-n> on the second consecutive <Esc>', function()
    local s = tseq()
    patterns_terminal.feed_terminal(s, '<Esc>')
    local result = patterns_terminal.feed_terminal(s, '<Esc>')
    assert.is_not_nil(result)
    assert.equals('terminal_esc_repeat', result.pattern)
    assert.equals('<C-\\><C-n>', result.cmd)
  end)
end)

describe('when the user keeps hammering <Esc> past the second press', function()
  it('does not fire again for the 3rd, 4th, ... <Esc> in the same uninterrupted streak', function()
    local s = tseq()
    patterns_terminal.feed_terminal(s, '<Esc>')
    patterns_terminal.feed_terminal(s, '<Esc>') -- fires here
    for _ = 1, 5 do
      local result = patterns_terminal.feed_terminal(s, '<Esc>')
      assert.is_nil(result, 'suggestion must fire once per streak, not spam on every extra <Esc>')
    end
  end)
end)

describe('when an ordinary key breaks the <Esc> streak', function()
  it('requires two fresh consecutive <Esc> presses to fire again', function()
    local s = tseq()
    patterns_terminal.feed_terminal(s, '<Esc>')
    patterns_terminal.feed_terminal(s, '<Esc>') -- 1st streak fires, latches
    patterns_terminal.feed_terminal(s, nil) -- ordinary key breaks the streak and re-arms it
    local first = patterns_terminal.feed_terminal(s, '<Esc>')
    assert.is_nil(first, 'only 1 consecutive <Esc> so far in the new streak')
    local second = patterns_terminal.feed_terminal(s, '<Esc>')
    assert.is_not_nil(second, 'expected a fresh terminal_esc_repeat after the streak restarted')
    assert.equals('terminal_esc_repeat', second.pattern)
  end)
end)

describe('when the terminal job itself legitimately consumes a single <Esc> at a time', function()
  it('does not fire when <Esc> presses are each separated by ordinary typing', function()
    -- Simulates a REPL-like program where <Esc> cancels one thing at a time
    -- (e.g. clearing an input line) rather than being an ineffective vim reflex.
    local s = tseq()
    patterns_terminal.feed_terminal(s, nil) -- ordinary input to the job
    local first = patterns_terminal.feed_terminal(s, '<Esc>')
    assert.is_nil(first)
    patterns_terminal.feed_terminal(s, nil) -- more ordinary input
    local second = patterns_terminal.feed_terminal(s, '<Esc>')
    assert.is_nil(second, 'non-consecutive <Esc> presses must never fire — that is the false-positive guard')
  end)
end)
