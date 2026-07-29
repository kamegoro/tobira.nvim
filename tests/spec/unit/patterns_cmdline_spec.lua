local patterns_cmdline = require('tobira.core.patterns_cmdline')

-- patterns_cmdline.tokenize(text) is a pure function: given the text of a
-- command-line buffer as returned by vim.fn.getcmdline() (i.e. NOT including
-- the leading ':'), it returns a semantic command name ('ex:s', 'ex:g', ...)
-- or nil when the text is empty / unparseable. No vim.* calls — see
-- lua/tobira/CLAUDE.md's "Module splitting policy".

describe('when classifying the text of a command-line buffer into a semantic command name', function()
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

-- patterns_cmdline.command_arg(text) is the argument-aware counterpart to
-- tokenize() above: tokenize() deliberately discards everything after the
-- command word (#57's scope), but two later detectors need the argument text
-- itself: #113's tabnew one-tab-per-file streak (below) needs to tell a bare
-- ":tabnew" apart from ":tabnew foo.txt", and the :e/:b ping-pong detector
-- (also below, #114) needs the filename argument to tell ":e A" apart from
-- ":e B". Both share this single implementation. Reuses the same
-- strip_range() range handling as tokenize() so a leading range prefix never
-- leaks into the returned argument.

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

  it('returns the trimmed argument following the command word for a :tabnew-style command', function()
    local word, arg = patterns_cmdline.command_arg('tabnew foo.txt')
    assert.equals('tabnew', word)
    assert.equals('foo.txt', arg)
  end)

  it('strips a range prefix before extracting a :tabnew argument', function()
    local word, arg = patterns_cmdline.command_arg('%tabnew foo.txt')
    assert.equals('tabnew', word)
    assert.equals('foo.txt', arg)
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

-- ── tabnew one-file-per-tab habit detection (#113) ──────────────────────────
-- new_tabnew_seq()/feed_tabnew() form a second, independent state machine in
-- this same file (see patterns_cmdline.lua's module comment for why this
-- lives here rather than a new sibling file). feed_tabnew() is fed evidence
-- gathered at each ":tabnew" <CR> submission: the trimmed file argument text
-- (the second return value of command_arg() above, converted from nil to ''
-- by the caller — see logger.lua), and the window count of the tabpage this
-- invocation is about to leave (read by the caller — see logger.lua).
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
