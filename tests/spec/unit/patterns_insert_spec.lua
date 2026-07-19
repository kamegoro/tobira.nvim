-- Pure unit tests for insert-mode pattern detection (#58 / split out in #99).
-- No vim.* calls — patterns_insert.lua has zero Neovim dependencies.
--
-- A separate pure state machine from patterns.lua's normal-mode seq/feed:
-- logger.lua only calls feed_insert() while the mode cache says the user is
-- in insert mode, feeding it a canonical key name ('<BS>', '<Left>', '<Right>',
-- '<Esc>') or nil for an ordinary typed character.

local patterns_insert = require('tobira.core.patterns_insert')

local function iseq()
  return patterns_insert.new_insert_seq()
end

describe('when the user backspaces 5 times in a row in insert mode', function()
  it('fires insert_bs_repeat suggesting <C-w>', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    local result = patterns_insert.feed_insert(s, '<BS>')
    assert.is_not_nil(result)
    assert.equals('insert_bs_repeat', result.pattern)
    assert.equals('<C-w>', result.cmd)
  end)

  it('does not fire on the 4th backspace', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    local result = patterns_insert.feed_insert(s, '<BS>')
    assert.is_nil(result)
  end)

  it('resets the streak once an ordinary key is typed in between', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, '<BS>')
    patterns_insert.feed_insert(s, nil) -- ordinary character, breaks the streak
    patterns_insert.feed_insert(s, '<BS>')
    local result = patterns_insert.feed_insert(s, '<BS>')
    assert.is_nil(result, 'streak should have restarted, not reached 5 yet')
  end)

  it('fires again after a fresh streak once the counter has reset', function()
    local s = iseq()
    for _ = 1, 5 do
      patterns_insert.feed_insert(s, '<BS>')
    end
    for _ = 1, 4 do
      patterns_insert.feed_insert(s, '<BS>')
    end
    local result = patterns_insert.feed_insert(s, '<BS>')
    assert.is_not_nil(result, 'expected a second insert_bs_repeat after another 5-run')
    assert.equals('insert_bs_repeat', result.pattern)
  end)
end)

describe('when the user presses <Left> 5 times in a row in insert mode', function()
  it('fires insert_left_repeat suggesting b', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<Left>')
    patterns_insert.feed_insert(s, '<Left>')
    patterns_insert.feed_insert(s, '<Left>')
    patterns_insert.feed_insert(s, '<Left>')
    local result = patterns_insert.feed_insert(s, '<Left>')
    assert.is_not_nil(result)
    assert.equals('insert_left_repeat', result.pattern)
    assert.equals('b', result.cmd)
  end)
end)

describe('when the user presses <Right> 5 times in a row in insert mode', function()
  it('fires insert_right_repeat suggesting w', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<Right>')
    patterns_insert.feed_insert(s, '<Right>')
    patterns_insert.feed_insert(s, '<Right>')
    patterns_insert.feed_insert(s, '<Right>')
    local result = patterns_insert.feed_insert(s, '<Right>')
    assert.is_not_nil(result)
    assert.equals('insert_right_repeat', result.pattern)
    assert.equals('w', result.cmd)
  end)
end)

describe('when <Left> and <Right> streaks are interleaved', function()
  it('does not let a <Left> streak count towards <Right> (and vice versa)', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<Left>')
    patterns_insert.feed_insert(s, '<Left>')
    patterns_insert.feed_insert(s, '<Right>')
    patterns_insert.feed_insert(s, '<Right>')
    patterns_insert.feed_insert(s, '<Right>')
    local result = patterns_insert.feed_insert(s, '<Right>')
    assert.is_nil(result, 'only 4 consecutive <Right> so far — the 2 <Left> presses must not count')
  end)
end)

describe('when the user enters and immediately leaves insert mode with no input, twice in a row', function()
  it('fires insert_bounce suggesting A on the second empty bounce', function()
    local s = iseq()
    -- First bounce: enter insert (implicit — insert_seq starts fresh), leave
    -- immediately with nothing typed.
    local first = patterns_insert.feed_insert(s, '<Esc>')
    assert.is_nil(first, 'a single empty bounce should not fire yet')
    -- Second bounce: same thing again.
    local second = patterns_insert.feed_insert(s, '<Esc>')
    assert.is_not_nil(second)
    assert.equals('insert_bounce', second.pattern)
    assert.equals('A', second.cmd)
  end)

  it('does not fire when the user typed something before leaving', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<Esc>') -- first empty bounce
    patterns_insert.feed_insert(s, 'x') -- ordinary typing this time
    local result = patterns_insert.feed_insert(s, '<Esc>')
    assert.is_nil(result, 'the second insert session had real input, so it is not a bounce')
  end)

  it('resets the bounce streak after a non-empty escape', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<Esc>') -- 1st empty bounce
    patterns_insert.feed_insert(s, 'x')
    patterns_insert.feed_insert(s, '<Esc>') -- non-empty, resets streak
    local result = patterns_insert.feed_insert(s, '<Esc>') -- only 1st empty bounce again
    assert.is_nil(result, 'streak should have been reset by the non-empty escape')
  end)
end)

describe('insert-mode streaks vs. the bounce counter', function()
  it('pressing <BS>/<Left>/<Right> counts as input, so it does not count as an empty bounce', function()
    local s = iseq()
    patterns_insert.feed_insert(s, '<Esc>') -- 1st empty bounce
    patterns_insert.feed_insert(s, '<BS>') -- counts as real input this session
    local result = patterns_insert.feed_insert(s, '<Esc>')
    assert.is_nil(result, 'a session with a <BS> press is not an empty bounce')
  end)
end)
