-- Pure unit tests for pattern detection.
-- No vim.* calls — patterns.lua has zero Neovim dependencies.

local patterns = require('tobira.core.patterns')

local function seq()
  return patterns.new_seq()
end

local function feed(s, keys, line)
  local result
  for _, k in ipairs(keys) do
    result = patterns.feed(s, k, line or 1)
  end
  return result
end

-- ── f / F repeat ─────────────────────────────────────────────────────────────

describe('when the user searches the same character twice on the same line', function()
  it('fires f_repeat suggesting ;', function()
    local s = seq()
    patterns.feed(s, 'f', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'f', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_not_nil(result)
    assert.equals('f_repeat', result.pattern)
    assert.equals(';', result.cmd)
  end)

  it('does not fire when the second search is a different character', function()
    local s = seq()
    patterns.feed(s, 'f', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'f', 1)
    local result = patterns.feed(s, 'x', 1)
    assert.is_nil(result)
  end)

  it('does not fire when the second search is on a different line', function()
    local s = seq()
    patterns.feed(s, 'f', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'f', 2)
    local result = patterns.feed(s, 'o', 2)
    assert.is_nil(result)
  end)
end)

-- ── x consecutive (delete char) ──────────────────────────────────────────────

describe('when the user presses x three or more times in a row', function()
  it('fires x_repeat suggesting {n}x', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'x', 1)
    local result = patterns.feed(s, 'x', 1)
    assert.is_not_nil(result)
    assert.equals('x_repeat', result.pattern)
    assert.equals('{n}x', result.cmd)
  end)

  it('does not fire after only two x presses', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    local result = patterns.feed(s, 'x', 1)
    assert.is_nil(result)
  end)

  it('resets the run when a different key is pressed', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'j', 1)
    patterns.feed(s, 'x', 1)
    local result = patterns.feed(s, 'x', 1)
    assert.is_nil(result)
  end)
end)

-- ── u consecutive (undo) ─────────────────────────────────────────────────────

describe('when the user presses u three or more times in a row', function()
  it('fires u_repeat suggesting <C-r>', function()
    local s = seq()
    patterns.feed(s, 'u', 1)
    patterns.feed(s, 'u', 1)
    local result = patterns.feed(s, 'u', 1)
    assert.is_not_nil(result)
    assert.equals('u_repeat', result.pattern)
    assert.equals('<C-r>', result.cmd)
  end)
end)

-- ── j consecutive (line movement) ────────────────────────────────────────────

describe('when the user presses j five or more times in a row', function()
  it('fires j_repeat suggesting {n}j', function()
    local s = seq()
    feed(s, { 'j', 'j', 'j', 'j' }, 1)
    local result = patterns.feed(s, 'j', 1)
    assert.is_not_nil(result)
    assert.equals('j_repeat', result.pattern)
    assert.equals('{n}j', result.cmd)
  end)

  it('does not fire after only four j presses', function()
    local s = seq()
    feed(s, { 'j', 'j', 'j' }, 1)
    local result = patterns.feed(s, 'j', 1)
    assert.is_nil(result)
  end)
end)

-- ── dd → p (swap lines) ──────────────────────────────────────────────────────

describe('when the user deletes a line and immediately pastes it below', function()
  it('fires dd_then_p suggesting ddp', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_not_nil(result)
    assert.equals('dd_then_p', result.pattern)
    assert.equals('ddp', result.cmd)
  end)
end)

-- ── 0 → w (go to first non-blank) ────────────────────────────────────────────

describe('when the user goes to column 0 then jumps forward a word', function()
  it('fires zero_then_w suggesting ^', function()
    local s = seq()
    patterns.feed(s, '0', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_not_nil(result)
    assert.equals('zero_then_w', result.pattern)
    assert.equals('^', result.cmd)
  end)
end)
