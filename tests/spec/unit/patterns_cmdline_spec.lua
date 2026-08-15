local patterns_cmdline = require('tobira.core.patterns_cmdline')

-- patterns_cmdline.tokenize(text): pure function, text -> semantic command
-- name ('ex:s', 'ex:g', ...) or nil. See docs/adr/0002-ex-command-tokenizer-one-shot-parsing.md.

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

-- patterns_cmdline.track_substitute(state, text, line): detects the
-- SAME :s pattern+replacement manually re-run on 2+ distinct lines, firing
-- '&' on the 2nd distinct line and 'g&' on the 3rd. state accumulates across
-- the whole session (unlike tokenize()). See
-- docs/adr/0006-cmdline-substitute-repeat-detection.md for the scope limits
-- and threshold rationale.
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
    -- Scope decision — see docs/adr/0006-cmdline-substitute-repeat-detection.md.
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

-- A long session accumulating many DISTINCT :s/// pattern+replacement pairs
-- must not let state.entries (and each entry's own .lines set) grow without
-- bound -- see docs/adr/0110-cmdline-state-lru-eviction.md (#314).

local function count_keys(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

local function total_substitute_lines(state)
  local n = 0
  for _, entry in pairs(state.entries) do
    n = n + count_keys(entry.lines)
  end
  return n
end

describe('patterns_cmdline.track_substitute state growth bound (#314)', function()
  it('caps the number of tracked substitute pairs instead of growing without bound', function()
    local state = patterns_cmdline.new_substitute_state()
    for i = 1, 200 do
      patterns_cmdline.track_substitute(state, string.format('s/pat%d/rep%d/', i, i), 1)
    end
    assert.is_true(
      count_keys(state.entries) <= 20,
      string.format('expected a bounded number of tracked pairs, got %d', count_keys(state.entries))
    )
  end)

  it("stops growing a fired pair's distinct-line set once its widest threshold (g&) has already fired", function()
    local state = patterns_cmdline.new_substitute_state()
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 1)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 2)
    patterns_cmdline.track_substitute(state, 's/foo/bar/', 3) -- fires g&
    for line = 4, 200 do
      patterns_cmdline.track_substitute(state, 's/foo/bar/', line)
    end
    assert.is_true(
      total_substitute_lines(state) <= 3,
      string.format("expected the fired pair's line set to stop growing, got %d lines", total_substitute_lines(state))
    )
  end)

  it(
    'still fires substitute_repeat for an actively repeated pair while eviction removes unrelated one-off pairs',
    function()
      local state = patterns_cmdline.new_substitute_state()
      -- Push well past the cap with distinct one-off pairs so LRU eviction is
      -- actively removing entries by the time the pair below is tracked.
      for i = 1, 25 do
        patterns_cmdline.track_substitute(state, string.format('s/pat%d/rep%d/', i, i), i)
      end
      patterns_cmdline.track_substitute(state, 's/target/replaced/', 500)
      local result = patterns_cmdline.track_substitute(state, 's/target/replaced/', 501)
      assert.equals('substitute_repeat', result.pattern)
      assert.equals('&', result.cmd)
    end
  )
end)

-- patterns_cmdline.command_arg(text): argument-aware counterpart to
-- tokenize() above, shared by the tabnew streak and :e/:b ping-pong
-- detectors below. See
-- docs/adr/0003-cmdline-command-arg-shared-argument-extraction.md.

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

-- Ex-command ping-pong detection: fires when the two most recently
-- distinct filenames touched via :e/:b alternate — :e A -> :e B -> :e A (or
-- the equivalent with :b) — suggesting <C-^> as the direct shortcut between
-- them. See docs/adr/0004-ex-file-pingpong-detection.md.

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

-- ── tabnew one-file-per-tab habit detection ───────────────────────────────────
-- See docs/adr/0005-tabnew-one-file-per-tab-detection.md.
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

  -- regression (QA): feed_tabnew() used to track only a has_arg boolean, so
  -- reopening the same file 3x via :tabnew fired the suggestion even though
  -- Vim reuses the existing buffer — see
  -- docs/adr/0005-tabnew-one-file-per-tab-detection.md.
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

-- ── Verbatim Ex-command retype detection ──────────────────────────────────────
-- Generalizes substitute_repeat/ex_file_pingpong/tabnew_run above: retyping
-- the exact same full command-line string 2+ times is a signal for `:`+<Up>
-- (or q:) history recall, for any command NOT already claimed by one of the
-- 3 more specific patterns above. See
-- docs/adr/0095-cmdline-history-recall-detection.md.
describe('patterns_cmdline.feed_history_recall', function()
  local function rseq()
    return patterns_cmdline.new_history_recall_state()
  end

  it('does not fire on the first submission of a command', function()
    local s = rseq()
    local result = patterns_cmdline.feed_history_recall(s, '!somecommand --flags', nil, nil)
    assert.is_nil(result)
  end)

  it('fires cmdline_history_recall suggesting q: when the identical command is retyped a second time', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, '!somecommand --flags', nil, nil)
    local result = patterns_cmdline.feed_history_recall(s, '!somecommand --flags', nil, nil)
    assert.equals('cmdline_history_recall', result.pattern)
    assert.equals('q:', result.cmd)
  end)

  it('fires for a retyped :g command (word is a letter word, not excluded, and has an argument)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
    local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
    assert.equals('cmdline_history_recall', result.pattern)
    assert.equals('q:', result.cmd)
  end)

  it('does not fire again on a third identical submission (fires once, then latches)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
    patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d') -- fires here
    local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
    assert.is_nil(result)
  end)

  it('does not fire when the command text differs between submissions', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
    local result = patterns_cmdline.feed_history_recall(s, 'g/other/d', 'g', '/other/d')
    assert.is_nil(result)
  end)

  it('tracks distinct commands independently, each with their own 2-submission threshold', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'g/foo/d', 'g', '/foo/d')
    patterns_cmdline.feed_history_recall(s, 'g/bar/d', 'g', '/bar/d')
    local result = patterns_cmdline.feed_history_recall(s, 'g/foo/d', 'g', '/foo/d')
    assert.equals('cmdline_history_recall', result.pattern)
  end)

  it('does not fire for a substitute command (claimed by substitute_repeat instead)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 's/foo/bar/', 's', '/foo/bar/')
    local result = patterns_cmdline.feed_history_recall(s, 's/foo/bar/', 's', '/foo/bar/')
    assert.is_nil(result)
  end)

  it('does not fire for a substitute abbreviation (su/sub/substitute), same word-family exclusion', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'substitute/foo/bar/', 'substitute', '/foo/bar/')
    local result = patterns_cmdline.feed_history_recall(s, 'substitute/foo/bar/', 'substitute', '/foo/bar/')
    assert.is_nil(result)
  end)

  it('does not fire for a ranged substitute either, by word-family rather than exact-scope match', function()
    -- track_substitute() itself declines a ranged :%s (out of its scope, see
    -- docs/adr/0006), but the generic detector still excludes it by word
    -- alone so the same edit habit never earns two different suggestions.
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, '%s/foo/bar/', 's', '/foo/bar/')
    local result = patterns_cmdline.feed_history_recall(s, '%s/foo/bar/', 's', '/foo/bar/')
    assert.is_nil(result)
  end)

  it('does not fire for a retyped :e command (claimed by ex_file_pingpong instead)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'e foo.txt', 'e', 'foo.txt')
    local result = patterns_cmdline.feed_history_recall(s, 'e foo.txt', 'e', 'foo.txt')
    assert.is_nil(result)
  end)

  it('does not fire for a retyped :b command (claimed by ex_file_pingpong instead)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'b foo.txt', 'b', 'foo.txt')
    local result = patterns_cmdline.feed_history_recall(s, 'b foo.txt', 'b', 'foo.txt')
    assert.is_nil(result)
  end)

  it('does not fire for a bare :e with no argument either (excluded by word alone, not by arg presence)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'e', 'e', nil)
    local result = patterns_cmdline.feed_history_recall(s, 'e', 'e', nil)
    assert.is_nil(result)
  end)

  it('fires for a retyped :edit command (not excluded -- ping-pong only recognizes the literal word "e")', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'edit foo.txt', 'edit', 'foo.txt')
    local result = patterns_cmdline.feed_history_recall(s, 'edit foo.txt', 'edit', 'foo.txt')
    assert.equals('cmdline_history_recall', result.pattern)
    assert.equals('q:', result.cmd)
  end)

  it('does not fire for a retyped :tabnew command (claimed by tabnew_run instead)', function()
    local s = rseq()
    patterns_cmdline.feed_history_recall(s, 'tabnew foo.txt', 'tabnew', 'foo.txt')
    local result = patterns_cmdline.feed_history_recall(s, 'tabnew foo.txt', 'tabnew', 'foo.txt')
    assert.is_nil(result)
  end)

  it('returns nil for nil text', function()
    assert.is_nil(patterns_cmdline.feed_history_recall(rseq(), nil, nil, nil))
  end)

  it('returns nil for an empty command line', function()
    assert.is_nil(patterns_cmdline.feed_history_recall(rseq(), '', nil, nil))
  end)

  it('returns nil for a whitespace-only command line', function()
    assert.is_nil(patterns_cmdline.feed_history_recall(rseq(), '   ', nil, nil))
  end)

  describe('minimum-complexity floor: a bare command word with no argument (QA-found false positive)', function()
    local trivial_commands = {
      { text = 'w', word = 'w' },
      { text = 'q', word = 'q' },
      { text = 'x', word = 'x' },
      { text = 'wq', word = 'wq' },
      { text = 'qa', word = 'qa' },
      { text = 'noh', word = 'noh' },
    }

    for _, case in ipairs(trivial_commands) do
      it('never fires for a bare :' .. case.text .. ' retyped many times', function()
        local s = rseq()
        for _ = 1, 5 do
          local result = patterns_cmdline.feed_history_recall(s, case.text, case.word, nil)
          assert.is_nil(result)
        end
      end)
    end

    it('never fires for a bang-forced bare command (:qa!) either', function()
      local s = rseq()
      patterns_cmdline.feed_history_recall(s, 'qa!', 'qa', nil)
      local result = patterns_cmdline.feed_history_recall(s, 'qa!', 'qa', nil)
      assert.is_nil(result)
    end)

    it('still fires once a bare command word gains a real argument (:w somefile.txt)', function()
      -- Proves the floor is an argument/complexity check, not a word
      -- blacklist like the substitute/pingpong/tabnew exclusions above --
      -- :w itself is never excluded by word, only by having nothing to
      -- retype.
      local s = rseq()
      patterns_cmdline.feed_history_recall(s, 'w somefile.txt', 'w', 'somefile.txt')
      local result = patterns_cmdline.feed_history_recall(s, 'w somefile.txt', 'w', 'somefile.txt')
      assert.equals('cmdline_history_recall', result.pattern)
      assert.equals('q:', result.cmd)
    end)
  end)

  -- feed_history_recall() cannot tell "manually retyped" apart from
  -- "recalled via <Up>/<Down> and resubmitted unchanged" from text alone --
  -- both look identical to vim.fn.getcmdline() at <CR> time, so the caller
  -- (logger.lua) tracks history-navigation separately and passes it here.
  describe('genuine history recall via <Up>/<Down> (#259) -- recalled_via_history param', function()
    it('does not fire when the identical command was recalled via history rather than retyped', function()
      local s = rseq()
      patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
      local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d', true)
      assert.is_nil(result)
    end)

    it('still fires when the identical command is manually retyped (recalled_via_history is falsy)', function()
      local s = rseq()
      patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d', false)
      local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d', false)
      assert.equals('cmdline_history_recall', result.pattern)
      assert.equals('q:', result.cmd)
    end)

    it(
      'does not count a recalled submission toward the 2-submission threshold -- a later manual retype still fires on its own merits',
      function()
        local s = rseq()
        patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d') -- manual, count = 1
        patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d', true) -- recalled, ignored entirely
        local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d') -- manual again, count = 2
        assert.equals('cmdline_history_recall', result.pattern)
      end
    )

    it('never fires purely from repeated recalls with no manual retyping at all', function()
      local s = rseq()
      patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d', true)
      local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d', true)
      assert.is_nil(result)
    end)
  end)
end)

-- A long session submitting many DISTINCT non-substitute/e/b/tabnew Ex
-- commands must not let state.entries grow without bound -- see
-- docs/adr/0110-cmdline-state-lru-eviction.md (#314).
describe('patterns_cmdline.feed_history_recall state growth bound (#314)', function()
  local function rseq()
    return patterns_cmdline.new_history_recall_state()
  end

  it('caps the number of tracked distinct command lines instead of growing without bound', function()
    local s = rseq()
    for i = 1, 200 do
      patterns_cmdline.feed_history_recall(s, string.format('echo "unique message %d"', i), 'echo', tostring(i))
    end
    local n = 0
    for _ in pairs(s.entries) do
      n = n + 1
    end
    assert.is_true(n <= 20, string.format('expected a bounded number of tracked command lines, got %d', n))
  end)

  it(
    'still fires cmdline_history_recall for an actively retyped command while eviction removes unrelated ones',
    function()
      local s = rseq()
      -- Push well past the cap with distinct one-off command lines so LRU
      -- eviction is actively removing entries by the time the retype below happens.
      for i = 1, 25 do
        patterns_cmdline.feed_history_recall(s, string.format('echo "unique message %d"', i), 'echo', tostring(i))
      end
      patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
      local result = patterns_cmdline.feed_history_recall(s, 'g/pattern/d', 'g', '/pattern/d')
      assert.equals('cmdline_history_recall', result.pattern)
      assert.equals('q:', result.cmd)
    end
  )
end)
