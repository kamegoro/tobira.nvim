local patterns_cmdline = require('tobira.core.patterns_cmdline')

-- patterns_cmdline.tokenize(text) is a pure function: given the text of a
-- command-line buffer as returned by vim.fn.getcmdline() (i.e. NOT including
-- the leading ':'), it returns a semantic command name ('ex:s', 'ex:g', ...)
-- or nil when the text is empty / unparseable. No vim.* calls — see
-- lua/tobira/CLAUDE.md's "Module splitting policy".

describe('patterns_cmdline.tokenize', function()
  it('returns ex:s for a plain substitute command', function()
    assert.equals('ex:s', patterns_cmdline.tokenize('s/foo/bar/g'))
  end)

  it('strips a % range prefix before extracting the command word', function()
    assert.equals('ex:s', patterns_cmdline.tokenize('%s/foo/bar/g'))
  end)

  it('returns ex:g for a global command with no range prefix', function()
    assert.equals('ex:g', patterns_cmdline.tokenize('g/TODO/d'))
  end)

  it('returns ex:norm for a normal-mode command', function()
    assert.equals('ex:norm', patterns_cmdline.tokenize('norm A;'))
  end)

  it('returns ex:norm for the unabbreviated "normal" spelling', function()
    assert.equals('ex:normal', patterns_cmdline.tokenize('normal A;'))
  end)

  it('strips a numeric line-range prefix (N,M)', function()
    assert.equals('ex:d', patterns_cmdline.tokenize('5,10d'))
  end)

  it("strips a visual-selection range prefix ('<,'>)", function()
    assert.equals('ex:norm', patterns_cmdline.tokenize("'<,'>norm @a"))
  end)

  it('strips a single mark reference prefix', function()
    assert.equals('ex:d', patterns_cmdline.tokenize("'a,'bd"))
  end)

  it('strips a search-pattern range prefix (/pat/,/pat2/)', function()
    assert.equals('ex:d', patterns_cmdline.tokenize('/start/,/end/d'))
  end)

  it('lowercases the command word', function()
    assert.equals('ex:s', patterns_cmdline.tokenize('S/foo/bar/'):lower())
  end)

  it('returns nil for an empty command line', function()
    assert.is_nil(patterns_cmdline.tokenize(''))
  end)

  it('returns nil for a command line that is only whitespace', function()
    assert.is_nil(patterns_cmdline.tokenize('   '))
  end)

  it('returns nil for nil input', function()
    assert.is_nil(patterns_cmdline.tokenize(nil))
  end)

  it('falls back to the literal punctuation character for symbolic commands', function()
    assert.equals('ex:!', patterns_cmdline.tokenize('!ls'))
  end)

  it('handles a bare command word with no arguments', function()
    assert.equals('ex:w', patterns_cmdline.tokenize('w'))
  end)

  it('handles cdo (used across the whole quickfix list)', function()
    assert.equals('ex:cdo', patterns_cmdline.tokenize('cdo s/foo/bar/g'))
  end)

  it('does not mistake an escaped delimiter inside a search-address range for its closing delimiter', function()
    -- Range "/foo\/bar/,/end/" — an escaped '/' inside the first search
    -- pattern must not be treated as that pattern's closing delimiter.
    assert.equals('ex:d', patterns_cmdline.tokenize('/foo\\/bar/,/end/d'))
  end)

  it('returns nil when the command line is only a range with no command word', function()
    assert.is_nil(patterns_cmdline.tokenize('%'))
  end)

  it('returns nil when a stray character remains that is neither a command word nor punctuation', function()
    -- e.g. a stray space typed after a visual-range prefix ("'<,'> d")
    assert.is_nil(patterns_cmdline.tokenize("'<,'> d"))
  end)
end)

-- patterns_cmdline.command_arg(text) is the argument-aware counterpart to
-- tokenize() above: tokenize() deliberately discards everything after the
-- command word (#57's scope), but the :e/:b ping-pong detector below (#114)
-- needs the filename argument itself. Reuses the same strip_range() range
-- handling as tokenize() so a leading range prefix never leaks into the
-- returned argument.

describe('patterns_cmdline.command_arg', function()
  it('returns the lowercased command word and trimmed argument for a plain command', function()
    local word, arg = patterns_cmdline.command_arg('e foo.txt')
    assert.equals('e', word)
    assert.equals('foo.txt', arg)
  end)

  it('returns a nil argument for a bare command word with no argument', function()
    local word, arg = patterns_cmdline.command_arg('e')
    assert.equals('e', word)
    assert.is_nil(arg)
  end)

  it('lowercases the command word the same way tokenize does', function()
    local word = patterns_cmdline.command_arg('E foo.txt')
    assert.equals('e', word)
  end)

  it('strips a force-bang between the command word and its argument', function()
    local word, arg = patterns_cmdline.command_arg('e! foo.txt')
    assert.equals('e', word)
    assert.equals('foo.txt', arg)
  end)

  it('trims surrounding whitespace from the argument', function()
    local _, arg = patterns_cmdline.command_arg('e    foo.txt   ')
    assert.equals('foo.txt', arg)
  end)

  it('strips a leading range prefix before extracting word and argument, like tokenize does', function()
    local word, arg = patterns_cmdline.command_arg("'<,'>norm @a")
    assert.equals('norm', word)
    assert.equals('@a', arg)
  end)

  it('returns nil, nil for an empty command line', function()
    local word, arg = patterns_cmdline.command_arg('')
    assert.is_nil(word)
    assert.is_nil(arg)
  end)

  it('returns nil, nil for a whitespace-only command line', function()
    local word, arg = patterns_cmdline.command_arg('   ')
    assert.is_nil(word)
    assert.is_nil(arg)
  end)

  it('returns nil, nil for nil input', function()
    local word, arg = patterns_cmdline.command_arg(nil)
    assert.is_nil(word)
    assert.is_nil(arg)
  end)

  it('returns nil, nil when the command line is only a range with no command word', function()
    local word, arg = patterns_cmdline.command_arg('%')
    assert.is_nil(word)
    assert.is_nil(arg)
  end)

  it('returns nil, nil for a symbolic command with no letter word (e.g. "!ls")', function()
    -- Unlike tokenize(), which falls back to the literal punctuation
    -- character for symbolic commands, command_arg() only ever needs to
    -- recognize letter-word commands (:e/:b) -- a leading non-letter means
    -- there is no word to extract at all.
    local word, arg = patterns_cmdline.command_arg('!ls')
    assert.is_nil(word)
    assert.is_nil(arg)
  end)
end)

-- Ex-command ping-pong detection (#114): fires when the two most recently
-- distinct filenames touched via :e/:b alternate — :e A -> :e B -> :e A (or
-- the equivalent with :b) — suggesting <C-^> as the direct shortcut between
-- them. New state alongside tokenize()/command_arg() above rather than a new
-- sibling file: it shares the same call path (both are fed from
-- logger.lua's handle_cmdline_key at <CR> time), which is the "shares the
-- same call path" branch of the module-splitting policy in
-- lua/tobira/CLAUDE.md, even though it shares no actual state with
-- tokenize()'s stateless parsing.

describe('patterns_cmdline ex_file_pingpong detection', function()
  local function pseq()
    return patterns_cmdline.new_pingpong_seq()
  end

  it('does not fire when opening the first file', function()
    local s = pseq()
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_nil(result)
  end)

  it('does not fire when switching to a second, different file', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'B')
    assert.is_nil(result)
  end)

  it('fires ex_file_pingpong suggesting <C-^> when the user returns to the first file', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_not_nil(result)
    assert.equals('ex_file_pingpong', result.pattern)
    assert.equals('<C-^>', result.cmd)
  end)

  it('counts :b the same as :e toward the same two-file rotation', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'b', 'B')
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_not_nil(result)
    assert.equals('ex_file_pingpong', result.pattern)
    assert.equals('<C-^>', result.cmd)
  end)

  it('does not fire again on the very next return while the same two-file rotation continues', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    patterns_cmdline.feed_pingpong(s, 'e', 'A') -- fires here
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_nil(result, 'must fire once per rotation, not on every alternation, like terminal_esc_repeat')
  end)

  it('does not fire when rotating through 3+ different files', function()
    local s = pseq()
    local files = { 'A', 'B', 'C', 'A', 'B', 'C', 'A', 'B', 'C' }
    for _, f in ipairs(files) do
      local result = patterns_cmdline.feed_pingpong(s, 'e', f)
      assert.is_nil(result, 'a 3+ file rotation must never be mistaken for a genuine 2-file ping-pong')
    end
  end)

  it('re-arms after a third file interrupts, so a fresh two-file rotation can fire again', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    patterns_cmdline.feed_pingpong(s, 'e', 'A') -- fires
    patterns_cmdline.feed_pingpong(s, 'e', 'C') -- 3rd file, breaks the A/B rotation
    patterns_cmdline.feed_pingpong(s, 'e', 'D')
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'C')
    assert.is_not_nil(result, 'expected a fresh ping-pong (C, D, C) to fire after the earlier rotation broke')
    assert.equals('ex_file_pingpong', result.pattern)
  end)

  it('does not disturb the two-file history when the same file is reopened consecutively', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    local reopen = patterns_cmdline.feed_pingpong(s, 'e', 'B') -- reopen current file
    assert.is_nil(reopen)
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_not_nil(result, 'reopening the current file must not erase the pending A/B history')
    assert.equals('ex_file_pingpong', result.pattern)
  end)

  it('ignores Ex commands other than :e/:b entirely, without disturbing the history', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    local ignored = patterns_cmdline.feed_pingpong(s, 'w', 'A')
    assert.is_nil(ignored)
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_not_nil(result, ':w must not count as a file switch or disturb the e/b history')
  end)

  it('ignores a bare :e/:b with no filename argument, without disturbing the history', function()
    local s = pseq()
    patterns_cmdline.feed_pingpong(s, 'e', 'A')
    patterns_cmdline.feed_pingpong(s, 'e', 'B')
    local bare = patterns_cmdline.feed_pingpong(s, 'e', nil)
    assert.is_nil(bare)
    local result = patterns_cmdline.feed_pingpong(s, 'e', 'A')
    assert.is_not_nil(result, 'a bare :e/:b reload has no filename signal and must not disturb the history')
  end)
end)
