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

-- ── F backward search repeat ─────────────────────────────────────────────────

describe('when the user searches the same character backwards twice on the same line', function()
  it('fires f_repeat suggesting ;', function()
    local s = seq()
    patterns.feed(s, 'F', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'F', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_not_nil(result)
    assert.equals('f_repeat', result.pattern)
    assert.equals(';', result.cmd)
  end)
end)

describe('when the user switches search direction between two searches', function()
  it('does not fire f_repeat when direction changes from f to F', function()
    local s = seq()
    patterns.feed(s, 'f', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'F', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_nil(result)
  end)
end)

describe('when the cursor leaves the line where an f-search happened', function()
  it('forgets the search so a later identical search is not a repeat', function()
    local s = seq()
    -- Search for 'o' on line 1.
    patterns.feed(s, 'f', 1)
    patterns.feed(s, 'o', 1)
    -- Move down to line 2 with a plain motion: this clears the f context.
    patterns.feed(s, 'j', 2)
    -- Repeat the same search on line 2 — must not count as a repeat.
    patterns.feed(s, 'f', 2)
    local result = patterns.feed(s, 'o', 2)
    assert.is_nil(result)
  end)
end)

-- ── dw / cw operator + word motion ───────────────────────────────────────────

describe('when the user deletes a word then pastes', function()
  it('does not suggest ddp because only dd-then-p swaps lines', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_nil(result)
  end)
end)

describe('when the user deletes a word then enters insert mode to retype it', function()
  it('fires dw_then_insert suggesting cw', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('dw_then_insert', result.pattern)
    assert.equals('cw', result.cmd)
  end)

  it('also fires when the user appends with a instead of i', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_not_nil(result)
    assert.equals('dw_then_insert', result.pattern)
  end)

  it('fires when count prefix is used (d3w → i)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, '3', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('dw_then_insert', result.pattern)
  end)

  it('fires for diw (inner word text object)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('dw_then_insert', result.pattern)
  end)

  it('fires for daw (around word text object)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'a', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('dw_then_insert', result.pattern)
  end)

  it('fires for di" (inner quote text object)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, '"', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('dw_then_insert', result.pattern)
  end)
end)

-- ── linewise delete variants ──────────────────────────────────────────────────

describe('when the user deletes a line downward (dj) then pastes', function()
  it('fires dd_then_p suggesting ddp', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'j', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_not_nil(result)
    assert.equals('dd_then_p', result.pattern)
  end)
end)

-- ── k consecutive (line movement up) ────────────────────────────────────────

describe('when the user presses k five or more times in a row', function()
  it('fires k_repeat suggesting {n}k', function()
    local s = seq()
    feed(s, { 'k', 'k', 'k', 'k' }, 1)
    local result = patterns.feed(s, 'k', 1)
    assert.is_not_nil(result)
    assert.equals('k_repeat', result.pattern)
    assert.equals('{n}k', result.cmd)
  end)

  it('does not fire after only four k presses', function()
    local s = seq()
    feed(s, { 'k', 'k', 'k' }, 1)
    local result = patterns.feed(s, 'k', 1)
    assert.is_nil(result)
  end)
end)

-- ── n consecutive (search navigation) ────────────────────────────────────────

describe('when the user presses n four or more times in a row', function()
  it('fires n_repeat suggesting cgn', function()
    local s = seq()
    feed(s, { 'n', 'n', 'n' }, 1)
    local result = patterns.feed(s, 'n', 1)
    assert.is_not_nil(result)
    assert.equals('n_repeat', result.pattern)
    assert.equals('cgn', result.cmd)
  end)

  it('does not fire after only three n presses', function()
    local s = seq()
    feed(s, { 'n', 'n' }, 1)
    local result = patterns.feed(s, 'n', 1)
    assert.is_nil(result)
  end)
end)

-- ── operator cancel ───────────────────────────────────────────────────────────

describe('when the user cancels a pending operator with Escape', function()
  it('does not fire any pattern', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, '\27', 1) -- <Esc>
    assert.is_nil(result)
  end)

  it('allows a fresh operator sequence after cancel', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, '\27', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_not_nil(result)
    assert.equals('dd_then_p', result.pattern)
  end)
end)
