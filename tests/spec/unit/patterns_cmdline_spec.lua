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
