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

-- patterns_cmdline.command_arg(text) is a pure function: given the same raw
-- command-line text tokenize() receives, it returns the trimmed argument
-- that follows the range + command word, or '' when there is none.
-- tokenize() deliberately discards this (see its header) — command_arg()
-- exists for #113's tabnew-habit detection, which needs to tell ":tabnew"
-- (no argument) apart from ":tabnew foo.txt" (a file argument).
describe('patterns_cmdline.command_arg', function()
  it('returns the trimmed argument following the command word', function()
    assert.equals('foo.txt', patterns_cmdline.command_arg('tabnew foo.txt'))
  end)

  it('returns an empty string for a bare command with no argument', function()
    assert.equals('', patterns_cmdline.command_arg('tabnew'))
  end)

  it('returns an empty string when only trailing whitespace follows the command word', function()
    assert.equals('', patterns_cmdline.command_arg('tabnew   '))
  end)

  it('strips a range prefix before extracting the argument', function()
    assert.equals('foo.txt', patterns_cmdline.command_arg('%tabnew foo.txt'))
  end)

  it('returns an empty string for nil input', function()
    assert.equals('', patterns_cmdline.command_arg(nil))
  end)

  it('returns an empty string for an empty command line', function()
    assert.equals('', patterns_cmdline.command_arg(''))
  end)
end)

-- ── tabnew one-file-per-tab habit detection (#113) ──────────────────────────
-- new_tabnew_seq()/feed_tabnew() form a second, independent state machine in
-- this same file (see patterns_cmdline.lua's module comment for why this
-- lives here rather than a new sibling file). feed_tabnew() is fed evidence
-- gathered at each ":tabnew" <CR> submission: the trimmed file argument text
-- (from command_arg() above, '' when there is none), and the window count of
-- the tabpage this invocation is about to leave (read by the caller — see
-- logger.lua).
--
-- The feature's own name is "one-tab-per-FILE" — feed_tabnew() only counts an
-- argument toward the streak the first time that exact filename appears in
-- it. Every test below therefore uses distinct filenames ('a.txt', 'b.txt',
-- ...) unless a test is specifically about the repeated-filename case.
describe('patterns_cmdline tabnew one-file-per-tab habit detection (#113)', function()
  it('does not fire on the first two tabnew calls', function()
    local seq = patterns_cmdline.new_tabnew_seq()
    assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'a.txt', 1))
    assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'b.txt', 1))
  end)

  it('fires tabnew_run, suggesting <C-^>, on the 3rd tabnew call when every prior tab stayed single-window', function()
    local seq = patterns_cmdline.new_tabnew_seq()
    patterns_cmdline.feed_tabnew(seq, 'a.txt', 1)
    patterns_cmdline.feed_tabnew(seq, 'b.txt', 1)
    local result = patterns_cmdline.feed_tabnew(seq, 'c.txt', 1)
    assert.equals('tabnew_run', result.pattern)
    assert.equals('<C-^>', result.cmd)
  end)

  it('does not fire again immediately after firing (streak resets)', function()
    local seq = patterns_cmdline.new_tabnew_seq()
    patterns_cmdline.feed_tabnew(seq, 'a.txt', 1)
    patterns_cmdline.feed_tabnew(seq, 'b.txt', 1)
    patterns_cmdline.feed_tabnew(seq, 'c.txt', 1) -- fires here
    assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'd.txt', 1))
  end)

  it('does not extend the streak for a bare :tabnew with no file argument', function()
    local seq = patterns_cmdline.new_tabnew_seq()
    patterns_cmdline.feed_tabnew(seq, 'a.txt', 1)
    assert.is_nil(patterns_cmdline.feed_tabnew(seq, '', 1))
    patterns_cmdline.feed_tabnew(seq, 'b.txt', 1)
    -- streak is only 2 (the bare tabnew reset it) — one more call is needed
    assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'c.txt', 1))
  end)

  it('does not fire when an earlier tabnew-opened tab picked up a second window (e.g. a :split)', function()
    local seq = patterns_cmdline.new_tabnew_seq()
    patterns_cmdline.feed_tabnew(seq, 'a.txt', 1) -- tab 1 opened
    -- tab 1 now has 2 windows (a :split happened) by the time tab 2's tabnew fires
    patterns_cmdline.feed_tabnew(seq, 'b.txt', 2)
    local result = patterns_cmdline.feed_tabnew(seq, 'c.txt', 1)
    assert.is_nil(result, 'the split should have reset the streak, not counted toward it')
  end)

  it('resumes counting from the tabnew right after a window split reset the streak', function()
    local seq = patterns_cmdline.new_tabnew_seq()
    patterns_cmdline.feed_tabnew(seq, 'a.txt', 1)
    patterns_cmdline.feed_tabnew(seq, 'b.txt', 2) -- split detected, streak resets to 1
    patterns_cmdline.feed_tabnew(seq, 'c.txt', 1) -- streak 2
    local result = patterns_cmdline.feed_tabnew(seq, 'd.txt', 1) -- streak 3, fires
    assert.equals('tabnew_run', result.pattern)
    assert.equals('<C-^>', result.cmd)
  end)

  -- ── regression: repeated filename must not count as "another file" (QA) ──
  -- Bug: feed_tabnew() used to receive only a has_arg boolean, so re-opening
  -- the exact same file 3 times via :tabnew fired the "switch to buffers"
  -- suggestion even though Vim reuses the existing buffer for a file already
  -- open — there is only ever 1 real buffer in that scenario, making the
  -- :b / <C-^> suggestion nonsensical. The fix threads the actual filename
  -- through and resets the streak the moment a repeat is seen: re-opening a
  -- file you already have open in another tab is a different, unrelated
  -- habit, not "one-tab-per-file browsing" (see patterns_cmdline.lua's
  -- feed_tabnew doc comment for the full reasoning).
  describe('when the exact same filename is opened via :tabnew repeatedly', function()
    it('never fires no matter how many times the same file is reopened', function()
      local seq = patterns_cmdline.new_tabnew_seq()
      assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'samefile.txt', 1))
      assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'samefile.txt', 1))
      assert.is_nil(patterns_cmdline.feed_tabnew(seq, 'samefile.txt', 1))
    end)

    it('resets the streak (not merely ignores the repeat) — 2 distinct files after a repeat do not fire', function()
      local seq = patterns_cmdline.new_tabnew_seq()
      patterns_cmdline.feed_tabnew(seq, 'a.txt', 1)
      patterns_cmdline.feed_tabnew(seq, 'a.txt', 1) -- repeat: resets the streak to 0
      patterns_cmdline.feed_tabnew(seq, 'b.txt', 1)
      local result = patterns_cmdline.feed_tabnew(seq, 'c.txt', 1)
      assert.is_nil(
        result,
        'if the repeat had merely been ignored (streak left at 1) these 2 more distinct files would have reached 3 and fired'
      )
    end)

    it('fires once 3 full distinct files follow the reset, proving the reset truly zeroed the streak', function()
      local seq = patterns_cmdline.new_tabnew_seq()
      patterns_cmdline.feed_tabnew(seq, 'a.txt', 1)
      patterns_cmdline.feed_tabnew(seq, 'a.txt', 1) -- repeat: resets the streak to 0
      patterns_cmdline.feed_tabnew(seq, 'b.txt', 1)
      patterns_cmdline.feed_tabnew(seq, 'c.txt', 1)
      local result = patterns_cmdline.feed_tabnew(seq, 'd.txt', 1)
      assert.equals('tabnew_run', result.pattern)
      assert.equals('<C-^>', result.cmd)
    end)
  end)
end)
