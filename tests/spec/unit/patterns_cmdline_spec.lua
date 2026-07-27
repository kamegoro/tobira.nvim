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

-- patterns_cmdline.track_substitute(state, text, line) is a second pure
-- function alongside tokenize() (#115). It detects the SAME :s pattern and
-- replacement being manually re-run on 2+ distinct lines, and returns a
-- suggestion for '&' (repeat on this line) the first time that happens, or
-- 'g&' (repeat file-wide) once a THIRD distinct line repeats it — see the
-- module header comment for why 3 distinct lines (not line distance) is the
-- chosen "spans enough of the file" threshold. state is created via
-- M.new_substitute_state() and accumulates across the whole session (unlike
-- tokenize(), which is stateless).
describe('patterns_cmdline.track_substitute', function()
  local state

  before_each(function()
    state = patterns_cmdline.new_substitute_state()
  end)

  it('does not fire on the first use of a substitute pattern', function()
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    assert.is_nil(result)
  end)

  it('fires substitute_repeat / & when the identical pattern+replacement runs on a second distinct line', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar/', 2)
    assert.equals('substitute_repeat', result.pattern)
    assert.equals('&', result.cmd)
  end)

  it('fires substitute_repeat_wide / g& when a third distinct line repeats it', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 2)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar/', 3)
    assert.equals('substitute_repeat_wide', result.pattern)
    assert.equals('g&', result.cmd)
  end)

  it('does not fire again on a fourth distinct line (already suggested g&)', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 2)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 3)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar/', 4)
    assert.is_nil(result)
  end)

  it('does not fire when the same line runs the command twice (not a distinct line)', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 5)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar/', 5)
    assert.is_nil(result)
  end)

  it('does not fire when the pattern differs between the two invocations', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foo2/bar/', 2)
    assert.is_nil(result)
  end)

  it('does not fire when the replacement differs between the two invocations', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar2/', 2)
    assert.is_nil(result)
  end)

  it('tracks flags separately from the pattern/replacement equality key (g vs no g still matches)', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar/g', 2)
    assert.equals('substitute_repeat', result.pattern)
  end)

  it('supports a custom delimiter (# instead of /)', function()
    patterns_cmdline.track_substitute(state, 's#foo#bar#', 1)
    local result = patterns_cmdline.track_substitute(state, 's#foo#bar#', 2)
    assert.equals('substitute_repeat', result.pattern)
  end)

  it('does not confuse two different delimiters that happen to produce the same raw text', function()
    -- 's#foo#bar#' (pattern "foo", replacement "bar") vs a literal-delimiter
    -- mismatch must not be treated as equal to 's/foo/bar/' by accident.
    -- (Both actually parse to pattern="foo", replacement="bar" here, so they
    -- SHOULD match — this test pins that intentional behavior down.)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 's#foo#bar#', 2)
    assert.equals('substitute_repeat', result.pattern)
  end)

  it('honors an escaped delimiter inside the pattern (:s/foo\\/bar/baz/)', function()
    patterns_cmdline.track_substitute(state, 's/foo\\/bar/baz/', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foo\\/bar/baz/', 2)
    assert.equals('substitute_repeat', result.pattern)
    assert.equals('&', result.cmd)
  end)

  it('does not merge two different patterns that only differ by an escaped delimiter', function()
    patterns_cmdline.track_substitute(state, 's/foo\\/bar/baz/', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foobar/baz/', 2)
    assert.is_nil(result)
  end)

  it('recognizes the "substitute" abbreviations su/sub/substitute, not just "s"', function()
    patterns_cmdline.track_substitute(state, 'substitute/foo/bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 'sub/foo/bar/', 2)
    assert.equals('substitute_repeat', result.pattern)
  end)

  it('does not track a command with an explicit range prefix (e.g. :5s or :%s)', function()
    -- Scope decision (see module header): only bare, no-range :s is tracked,
    -- since the target line then comes unambiguously from the cursor. An
    -- explicit range makes "which line was this run on" ambiguous (a range
    -- can span many lines) without much extra payoff, since :%s / :N,Ms are
    -- already a single one-shot file-wide edit, not the "repeat on the next
    -- line" workflow this feature targets.
    local result = patterns_cmdline.track_substitute(state, '%s/foo/bar/', 1)
    assert.is_nil(result)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    local result2 = patterns_cmdline.track_substitute(state, '5s/foo/bar/', 2)
    assert.is_nil(result2)
  end)

  it('does not track a bare :s with no pattern (repeats the last substitute)', function()
    local result = patterns_cmdline.track_substitute(state, 's', 1)
    assert.is_nil(result)
  end)

  it('does not track :s with only flags and no explicit pattern (e.g. "s g")', function()
    local result = patterns_cmdline.track_substitute(state, 's g', 1)
    assert.is_nil(result)
  end)

  it('does not track an empty explicit pattern (:s//bar/ reuses the last search)', function()
    patterns_cmdline.track_substitute(state, 's//bar/', 1)
    local result = patterns_cmdline.track_substitute(state, 's//bar/', 2)
    assert.is_nil(result)
  end)

  it('does not track a command with no closing delimiter for the pattern (:s/foo)', function()
    local result = patterns_cmdline.track_substitute(state, 's/foo', 1)
    assert.is_nil(result)
  end)

  it('supports an omitted trailing delimiter after the replacement (:s/foo/bar)', function()
    patterns_cmdline.track_substitute(state, 's/foo/bar', 1)
    local result = patterns_cmdline.track_substitute(state, 's/foo/bar', 2)
    assert.equals('substitute_repeat', result.pattern)
  end)

  it('does not track an unrelated command (e.g. :g) as a substitute', function()
    local result = patterns_cmdline.track_substitute(state, 'g/foo/d', 1)
    assert.is_nil(result)
  end)

  it('does not track a symbolic command with no leading command word (e.g. :!ls)', function()
    -- No range prefix is stripped (strip_range leaves '!ls' untouched), but
    -- '!' is not a letter, so there is no command word to check against
    -- "substitute" at all.
    local result = patterns_cmdline.track_substitute(state, '!ls', 1)
    assert.is_nil(result)
  end)

  it('returns nil for nil text or nil line', function()
    assert.is_nil(patterns_cmdline.track_substitute(state, nil, 1))
    assert.is_nil(patterns_cmdline.track_substitute(state, 's/foo/bar/', nil))
  end)

  it('returns nil for an empty command line', function()
    assert.is_nil(patterns_cmdline.track_substitute(state, '', 1))
  end)
end)
