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

-- ── t / T repeat (stop-before-char) ──────────────────────────────────────────

describe('when the user uses t-search on the same character twice on the same line', function()
  it('fires f_repeat suggesting ; (t repeats with ; just like f)', function()
    local s = seq()
    patterns.feed(s, 't', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 't', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_not_nil(result)
    assert.equals('f_repeat', result.pattern)
    assert.equals(';', result.cmd)
  end)

  it('does not fire when direction changes from t to T', function()
    local s = seq()
    patterns.feed(s, 't', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'T', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_nil(result)
  end)

  it('does not fire on a different line', function()
    local s = seq()
    patterns.feed(s, 't', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 't', 2)
    local result = patterns.feed(s, 'o', 2)
    assert.is_nil(result)
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
    patterns.feed(s, 'f', 1)
    patterns.feed(s, 'o', 1)
    patterns.feed(s, 'j', 2)
    patterns.feed(s, 'f', 2)
    local result = patterns.feed(s, 'o', 2)
    assert.is_nil(result)
  end)
end)

-- ── consecutive-run patterns ──────────────────────────────────────────────────
-- x, u, j, k, n all share the same "fire after N presses" structure.

local run_cases = {
  { key = 'x', threshold = 3, pattern = 'x_repeat', cmd = '{n}x' },
  { key = 'u', threshold = 3, pattern = 'u_repeat', cmd = '<C-r>' },
  { key = 'j', threshold = 5, pattern = 'j_repeat', cmd = '{n}j' },
  { key = 'k', threshold = 5, pattern = 'k_repeat', cmd = '{n}k' },
  { key = 'n', threshold = 4, pattern = 'n_repeat', cmd = 'cgn' },
  { key = 'w', threshold = 5, pattern = 'w_repeat', cmd = 'W' },
  { key = 'b', threshold = 5, pattern = 'b_repeat', cmd = 'B' },
  { key = 'e', threshold = 5, pattern = 'e_repeat', cmd = 'ge' },
  { key = 'P', threshold = 3, pattern = 'P_repeat', cmd = '{n}P' },
  { key = '~', threshold = 3, pattern = 'tilde_repeat', cmd = '{n}~' },
  { key = '.', threshold = 3, pattern = 'dot_repeat', cmd = '{n}.' },
  { key = 'J', threshold = 3, pattern = 'J_repeat', cmd = '{n}J' },
}

for _, tc in ipairs(run_cases) do
  describe('when ' .. tc.key .. ' is pressed ' .. tc.threshold .. ' or more times in a row', function()
    it('fires ' .. tc.pattern .. ' suggesting ' .. tc.cmd, function()
      local s = seq()
      for _ = 1, tc.threshold - 1 do
        patterns.feed(s, tc.key, 1)
      end
      local result = patterns.feed(s, tc.key, 1)
      assert.is_not_nil(result)
      assert.equals(tc.pattern, result.pattern)
      assert.equals(tc.cmd, result.cmd)
    end)

    it('does not fire after only ' .. (tc.threshold - 1) .. ' presses', function()
      local s = seq()
      for _ = 1, tc.threshold - 2 do
        patterns.feed(s, tc.key, 1)
      end
      local result = patterns.feed(s, tc.key, 1)
      assert.is_nil(result)
    end)
  end)
end

-- ── j / k higher-threshold: paragraph jump ────────────────────────────────────

describe('when j is pressed 10 times in a row', function()
  it('fires j_repeat at 5 and then j_many at 10 suggesting }', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, 'j', 1)
    end
    local at5 = patterns.feed(s, 'j', 1)
    assert.is_not_nil(at5)
    assert.equals('j_repeat', at5.pattern)
    for _ = 1, 4 do
      patterns.feed(s, 'j', 1)
    end
    local at10 = patterns.feed(s, 'j', 1)
    assert.is_not_nil(at10)
    assert.equals('j_many', at10.pattern)
    assert.equals('}', at10.cmd)
  end)

  it('does not fire j_many at 9 presses', function()
    local s = seq()
    for _ = 1, 9 do
      patterns.feed(s, 'j', 1)
    end
    -- press 9: nothing fires (j_repeat already fired at 5)
    -- just verify j_many hasn't fired (result may be nil, that's fine)
    -- re-feed 9th to capture return value
    local s2 = seq()
    for _ = 1, 8 do
      patterns.feed(s2, 'j', 1)
    end
    local result = patterns.feed(s2, 'j', 1)
    if result then
      assert.is_not_equal('j_many', result.pattern)
    end
  end)
end)

describe('when k is pressed 10 times in a row', function()
  it('fires k_repeat at 5 and then k_many at 10 suggesting {', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1)
    end
    local at5 = patterns.feed(s, 'k', 1)
    assert.is_not_nil(at5)
    assert.equals('k_repeat', at5.pattern)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1)
    end
    local at10 = patterns.feed(s, 'k', 1)
    assert.is_not_nil(at10)
    assert.equals('k_many', at10.pattern)
    assert.equals('{', at10.cmd)
  end)
end)

-- ── j / k in diff mode: prefer ]c / [c hunk navigation over }/{ (#111) ────────
-- feed()'s 4th argument is the caller-supplied "is &diff set on this window?"
-- flag. patterns.lua stays vim.*-free (see lua/tobira/CLAUDE.md's module
-- dependency rules), so it never reads vim.wo.diff itself — logger.lua reads
-- it and passes the boolean in. These tests inject that flag directly,
-- exactly as patterns_spec.lua's own template for unit-testing pure functions
-- prescribes (see tests/CLAUDE.md).

describe('when j is pressed 10 times in a row while &diff is set', function()
  it('fires j_many_diff at 10 suggesting ]c instead of }', function()
    local s = seq()
    for _ = 1, 9 do
      patterns.feed(s, 'j', 1, true)
    end
    local at10 = patterns.feed(s, 'j', 1, true)
    assert.is_not_nil(at10)
    assert.equals('j_many_diff', at10.pattern)
    assert.equals(']c', at10.cmd)
  end)
end)

describe('when k is pressed 10 times in a row while &diff is set', function()
  it('fires k_many_diff at 10 suggesting [c instead of {', function()
    local s = seq()
    for _ = 1, 9 do
      patterns.feed(s, 'k', 1, true)
    end
    local at10 = patterns.feed(s, 'k', 1, true)
    assert.is_not_nil(at10)
    assert.equals('k_many_diff', at10.pattern)
    assert.equals('[c', at10.cmd)
  end)
end)

describe('when j is pressed 10 times in a row outside diff mode', function()
  it('still fires j_many suggesting } (regression check against gating logic)', function()
    local s = seq()
    for _ = 1, 9 do
      patterns.feed(s, 'j', 1, false)
    end
    local at10 = patterns.feed(s, 'j', 1, false)
    assert.is_not_nil(at10)
    assert.equals('j_many', at10.pattern)
    assert.equals('}', at10.cmd)
  end)
end)

-- ── D → insert (delete to EOL then re-enter insert) ──────────────────────────

describe('when the user deletes to end of line then enters insert mode', function()
  it('fires D_then_insert suggesting C', function()
    local s = seq()
    patterns.feed(s, 'D', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('D_then_insert', result.pattern)
    assert.equals('C', result.cmd)
  end)

  it('also fires for A after D', function()
    local s = seq()
    patterns.feed(s, 'D', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_not_nil(result)
    assert.equals('D_then_insert', result.pattern)
  end)

  it('does not fire when another key separates D and the insert key', function()
    local s = seq()
    patterns.feed(s, 'D', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_nil(result)
  end)
end)

-- ── dd × 3 (delete multiple lines) → {n}dd ────────────────────────────────────

describe('when the user presses dd 3 or more times in a row', function()
  it('fires dd_run suggesting {n}dd', function()
    local s = seq()
    -- 1st dd
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    -- 2nd dd
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    -- 3rd dd
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_not_nil(result)
    assert.equals('dd_run', result.pattern)
    assert.equals('{n}dd', result.cmd)
  end)

  it('does not fire after only 2 consecutive dd', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by a non-delete key', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'j', 1) -- interrupt
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when dd is followed by p (dd→p pattern)', function()
    local s = seq()
    -- dd → p: swap lines, not a deletion streak
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'p', 1)
    -- Now two more dd: not enough for dd_run
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_nil(result)
  end)
end)

-- ── cc (change line) → last_op tracking ──────────────────────────────────────
-- Regression tests for #118: patterns.lua's operator-pending branch used to
-- hardcode seq.last_op = 'dd' regardless of the actual operator, so cc was
-- silently recorded (and streak-tracked) as dd.

describe('when the user presses cc (change line)', function()
  it('records last_op = cc, not the hardcoded dd', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'c', 1)
    assert.equals('cc', s.last_op)
  end)

  it('does not disturb dd: dd still records last_op = dd', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    assert.equals('dd', s.last_op)
  end)

  it('does not fire dd_run ({n}dd) when cc is pressed 3 times in a row', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, 'c', 1)
    assert.is_nil(result)
  end)

  it('does not fire dd_then_p when cc is followed by p', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_nil(result)
  end)
end)

describe('when x is interrupted by a different key', function()
  it('resets the run so subsequent x presses start fresh', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'j', 1)
    patterns.feed(s, 'x', 1)
    local result = patterns.feed(s, 'x', 1)
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

-- ── l / h repeat (move by character instead of word) ─────────────────────────

local lh_cases = {
  { key = 'l', threshold = 5, pattern = 'l_repeat', cmd = 'w' },
  { key = 'h', threshold = 5, pattern = 'h_repeat', cmd = 'b' },
}

for _, tc in ipairs(lh_cases) do
  describe('when ' .. tc.key .. ' is pressed ' .. tc.threshold .. ' or more times in a row', function()
    it('fires ' .. tc.pattern .. ' suggesting ' .. tc.cmd, function()
      local s = seq()
      for _ = 1, tc.threshold - 1 do
        patterns.feed(s, tc.key, 1)
      end
      local result = patterns.feed(s, tc.key, 1)
      assert.is_not_nil(result)
      assert.equals(tc.pattern, result.pattern)
      assert.equals(tc.cmd, result.cmd)
    end)

    it('does not fire after only ' .. (tc.threshold - 1) .. ' presses', function()
      local s = seq()
      for _ = 1, tc.threshold - 2 do
        patterns.feed(s, tc.key, 1)
      end
      local result = patterns.feed(s, tc.key, 1)
      assert.is_nil(result)
    end)
  end)
end

-- ── p repeat (paste multiple times) ──────────────────────────────────────────

describe('when p is pressed 3 or more times in a row without a preceding dd', function()
  it('fires p_repeat suggesting {n}p', function()
    local s = seq()
    patterns.feed(s, 'p', 1)
    patterns.feed(s, 'p', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_not_nil(result)
    assert.equals('p_repeat', result.pattern)
    assert.equals('{n}p', result.cmd)
  end)

  it('does not fire after only 2 presses', function()
    local s = seq()
    patterns.feed(s, 'p', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_nil(result)
  end)
end)

-- ── p / P → rightward motion (cursor skips past paste) → gp / gP (#106) ──────
-- Same "remember the last operation, decide on the next key" design as
-- yy_then_p / dd_then_p, but the decision spans several following keys
-- instead of just one — closer in shape to dd_run / r_run's streak tracking.

describe('when the user pastes then moves the cursor right several times', function()
  it('fires p_then_rightward suggesting gp after p followed by l x3', function()
    local s = seq()
    patterns.feed(s, 'p', 1)
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_not_nil(result)
    assert.equals('p_then_rightward', result.pattern)
    assert.equals('gp', result.cmd)
  end)

  it('does not fire after only 2 rightward moves', function()
    local s = seq()
    patterns.feed(s, 'p', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_nil(result)
  end)

  it('fires with a mix of rightward keys (l, w, $)', function()
    local s = seq()
    patterns.feed(s, 'p', 1)
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, '$', 1)
    assert.is_not_nil(result)
    assert.equals('p_then_rightward', result.pattern)
    assert.equals('gp', result.cmd)
  end)

  it('does not fire when a non-motion key interrupts the streak', function()
    local s = seq()
    patterns.feed(s, 'p', 1)
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'j', 1) -- interrupt: not a rightward motion
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_nil(result)
  end)

  it('does not fire for l x3 with no preceding paste', function()
    local s = seq()
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    -- l_repeat has a threshold of 5, so 3 plain l presses fire nothing
    assert.is_nil(result)
  end)
end)

describe('when the user pastes before the cursor then moves the cursor right several times', function()
  it('fires P_then_rightward suggesting gP after P followed by l x3', function()
    local s = seq()
    patterns.feed(s, 'P', 1)
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_not_nil(result)
    assert.equals('P_then_rightward', result.pattern)
    assert.equals('gP', result.cmd)
  end)

  it('does not fire after only 2 rightward moves', function()
    local s = seq()
    patterns.feed(s, 'P', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_nil(result)
  end)
end)

-- ── $ → a (append at end of line) ────────────────────────────────────────────

describe('when the user moves to end of line then appends', function()
  it('fires dollar_then_append suggesting A', function()
    local s = seq()
    patterns.feed(s, '$', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_not_nil(result)
    assert.equals('dollar_then_append', result.pattern)
    assert.equals('A', result.cmd)
  end)

  it('does not fire dollar_then_append when $ is used as a d motion (d$)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, '$', 1)
    local result = patterns.feed(s, 'a', 1)
    -- dw_then_insert may fire, but dollar_then_append must not
    if result then
      assert.is_not_equal('dollar_then_append', result.pattern)
    end
  end)

  it('does not fire when another key comes between $ and a', function()
    local s = seq()
    patterns.feed(s, '$', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)
end)

-- ── 0 / ^ → i (insert at beginning of line) ──────────────────────────────────

describe('when the user goes to true column 0 then enters insert mode', function()
  it('fires zero_col_then_insert suggesting gI', function()
    local s = seq()
    patterns.feed(s, '0', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('zero_col_then_insert', result.pattern)
    assert.equals('gI', result.cmd)
  end)
end)

describe('when the user goes to first non-blank then enters insert mode', function()
  it('fires zero_then_insert suggesting I', function()
    local s = seq()
    patterns.feed(s, '^', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('zero_then_insert', result.pattern)
    assert.equals('I', result.cmd)
  end)

  it('does not fire zero_then_insert when ^ is used as a d motion (d^)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, '^', 1)
    local result = patterns.feed(s, 'i', 1)
    -- dw_then_insert may fire, but zero_then_insert must not
    if result then
      assert.is_not_equal('zero_then_insert', result.pattern)
    end
  end)
end)

-- ── k → o (open line above current position) ─────────────────────────────────

describe('when the user goes up one line then opens a line below', function()
  it('fires k_then_o suggesting O', function()
    local s = seq()
    patterns.feed(s, 'k', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_not_nil(result)
    assert.equals('k_then_o', result.pattern)
    assert.equals('O', result.cmd)
  end)

  it('does not fire when k is pressed more than once (deliberate navigation)', function()
    local s = seq()
    patterns.feed(s, 'k', 1)
    patterns.feed(s, 'k', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_nil(result)
  end)

  it('does not fire when another key separates k and o', function()
    local s = seq()
    patterns.feed(s, 'k', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_nil(result)
  end)

  it('fires k_then_o again when the same round trip happens twice in a row', function()
    local s = seq()
    patterns.feed(s, 'k', 1)
    local first = patterns.feed(s, 'o', 1)
    assert.is_not_nil(first)
    assert.equals('k_then_o', first.pattern)
    assert.equals('O', first.cmd)

    patterns.feed(s, 'k', 1)
    local second = patterns.feed(s, 'o', 1)
    assert.is_not_nil(second)
    assert.equals('k_then_o', second.pattern)
    assert.equals('O', second.cmd)
  end)
end)

-- ── x (once) → i: suggest s (substitute = delete char + enter insert) ────────

describe('when the user deletes one character then enters insert mode', function()
  it('fires x_then_insert suggesting s', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('x_then_insert', result.pattern)
    assert.equals('s', result.cmd)
  end)

  it('also fires for a / o after x', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_not_nil(result)
    assert.equals('x_then_insert', result.pattern)
  end)

  it('does not fire after x x x (x_repeat territory)', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'x', 1) -- x_repeat fires here
    local result = patterns.feed(s, 'i', 1)
    assert.is_nil(result)
  end)

  it('does not fire when another key comes between x and insert', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_nil(result)
  end)

  it('fires x_then_insert again when the same round trip happens twice in a row', function()
    local s = seq()
    patterns.feed(s, 'x', 1)
    local first = patterns.feed(s, 'i', 1)
    assert.is_not_nil(first)
    assert.equals('x_then_insert', first.pattern)
    assert.equals('s', first.cmd)

    -- A second, separate x -> i round trip (e.g. two typo fixes back to back).
    -- Without resetting seq.run after the first fire, seq.run.count becomes 2
    -- here, so the second 'i' would fail the count==1 guard and patterns.feed
    -- would wrongly return nil instead of firing x_then_insert again.
    patterns.feed(s, 'x', 1)
    local second = patterns.feed(s, 'i', 1)
    assert.is_not_nil(second)
    assert.equals('x_then_insert', second.pattern)
    assert.equals('s', second.cmd)
  end)
end)

-- ── dd → insert: suggest cc (change line instead of delete + re-enter) ────────

describe('when the user deletes a line then enters insert mode', function()
  it('fires dd_then_insert suggesting cc', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'i', 1)
    assert.is_not_nil(result)
    assert.equals('dd_then_insert', result.pattern)
    assert.equals('cc', result.cmd)
  end)

  it('also fires for a and o after dd', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_not_nil(result)
    assert.equals('dd_then_insert', result.pattern)
  end)
end)

-- ── r × 3: suggest R (replace mode) ──────────────────────────────────────────

describe('when the user replaces individual characters 3 or more times', function()
  it('fires r_run suggesting R after r{char} × 3', function()
    local s = seq()
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'a', 1) -- 1st replacement
    patterns.feed(s, 'l', 1) -- navigate
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'b', 1) -- 2nd replacement
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'r', 1) -- 3rd r
    local result = patterns.feed(s, 'c', 1) -- replacement char → fires
    assert.is_not_nil(result)
    assert.equals('r_run', result.pattern)
    assert.equals('R', result.cmd)
  end)

  it('does not fire after only 2 replacements', function()
    local s = seq()
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'a', 1)
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'r', 1)
    local result = patterns.feed(s, 'b', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when a non-navigation key appears between replacements', function()
    local s = seq()
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'a', 1) -- streak=1
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'b', 1) -- streak=2
    patterns.feed(s, 'j', 1) -- j resets streak to 0
    -- Only 2 more replacements after the reset: not enough to fire
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'c', 1) -- streak=1
    patterns.feed(s, 'r', 1)
    local result = patterns.feed(s, 'd', 1) -- streak=2, still below threshold
    assert.is_nil(result)
  end)
end)

-- ── <C-a> → j/k → <C-a> × 3: suggest g<C-a> (#108) ───────────────────────────
-- Raw byte for Ctrl-A (ASCII 1 / 0x01), same convention as ctrl_w below.

describe('when the user increments a number, moves down, and repeats 3 or more times', function()
  local ctrl_a = '\1'

  it('fires ca_run suggesting g<C-a> after <C-a> j <C-a> j <C-a>', function()
    local s = seq()
    patterns.feed(s, ctrl_a, 1) -- 1st increment
    patterns.feed(s, 'j', 1)
    patterns.feed(s, ctrl_a, 1) -- 2nd increment
    patterns.feed(s, 'j', 1)
    local result = patterns.feed(s, ctrl_a, 1) -- 3rd increment → fires
    assert.is_not_nil(result)
    assert.equals('ca_run', result.pattern)
    assert.equals('g<C-a>', result.cmd)
  end)

  it('also fires when k is used as the connecting motion instead of j', function()
    local s = seq()
    patterns.feed(s, ctrl_a, 1)
    patterns.feed(s, 'k', 1)
    patterns.feed(s, ctrl_a, 1)
    patterns.feed(s, 'k', 1)
    local result = patterns.feed(s, ctrl_a, 1)
    assert.is_not_nil(result)
    assert.equals('ca_run', result.pattern)
    assert.equals('g<C-a>', result.cmd)
  end)

  it('does not fire after only 2 increments', function()
    local s = seq()
    patterns.feed(s, ctrl_a, 1)
    patterns.feed(s, 'j', 1)
    local result = patterns.feed(s, ctrl_a, 1)
    assert.is_nil(result)
  end)

  it('resets the streak when an unrelated key separates the increments', function()
    local s = seq()
    patterns.feed(s, ctrl_a, 1)
    patterns.feed(s, 'j', 1)
    patterns.feed(s, ctrl_a, 1)
    patterns.feed(s, 'x', 1) -- unrelated key: not j/k, breaks the streak
    patterns.feed(s, ctrl_a, 1)
    patterns.feed(s, 'j', 1)
    local result = patterns.feed(s, ctrl_a, 1)
    assert.is_nil(result)
  end)
end)

-- ── v i {obj} c/d/y → c/d/y + i + {obj} text object shortcut ────────────────

describe('when the user selects an inner text object visually then operates', function()
  it('fires visual_textobj ciw for v i w c', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'c', 1)
    assert.is_not_nil(result)
    assert.equals('visual_textobj', result.pattern)
    assert.equals('ciw', result.cmd)
  end)

  it('fires visual_textobj yiw for v i w y', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'y', 1)
    assert.is_not_nil(result)
    assert.equals('yiw', result.cmd)
  end)

  it('fires visual_textobj diw for v i w d', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_not_nil(result)
    assert.equals('diw', result.cmd)
  end)

  it('fires ci" for v i " c', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, '"', 1)
    local result = patterns.feed(s, 'c', 1)
    assert.is_not_nil(result)
    assert.equals('ci"', result.cmd)
  end)

  it('cancels when a non-i/a key follows v', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'j', 1) -- visual line-select, not a text object
    local result = patterns.feed(s, 'c', 1)
    assert.is_nil(result)
  end)

  it('cancels when a non-operator key follows v i w', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1) -- visual_obj is now set
    patterns.feed(s, 'j', 1) -- not c/d/y → cancel
    local result = patterns.feed(s, 'c', 1)
    assert.is_nil(result)
  end)
end)

-- ── v <Esc> v <Esc> v → gv (reselect last visual selection, #55) ────────────

describe('when the user enters and immediately leaves visual mode 3 times in a row', function()
  it('fires v_repeat suggesting gv on the 3rd clean <Esc>, not the 3rd v', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- <Esc>, 1st clean tap
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- <Esc>, 2nd clean tap
    local third_v = patterns.feed(s, 'v', 1)
    -- The 3rd v must NOT fire yet — whether it's another clean tap or the
    -- start of genuine visual usage (viw, v$, ...) isn't known until the
    -- next key arrives (#55 follow-up: firing on the v itself misfired on
    -- v<Esc>v<Esc>viw).
    assert.is_nil(third_v)
    local result = patterns.feed(s, '\27', 1) -- <Esc> confirms the 3rd tap was also clean
    assert.is_not_nil(result)
    assert.equals('v_repeat', result.pattern)
    assert.equals('gv', result.cmd)
  end)

  it('does not fire after only 2 clean taps', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1)
    local result = patterns.feed(s, 'v', 1)
    assert.is_nil(result)
  end)

  it('does not fire when the 3rd v turns out to be genuine visual usage (v<Esc>v<Esc>viw)', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- 1st clean tap
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- 2nd clean tap
    local third_v = patterns.feed(s, 'v', 1) -- 3rd v — must not fire eagerly
    assert.is_nil(third_v)
    local after_i = patterns.feed(s, 'i', 1) -- genuine text-object selection starts
    assert.is_nil(after_i)
    local after_w = patterns.feed(s, 'w', 1)
    assert.is_nil(after_w)
    -- ciw should still fire on its own merits (visual_textobj), but v_repeat
    -- must never have fired for this sequence.
    local result = patterns.feed(s, 'c', 1)
    assert.is_not_nil(result)
    assert.equals('visual_textobj', result.pattern)
    assert.equals('ciw', result.cmd)
  end)

  it('does not fire when a real visual text-object selection happens between taps', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- 1st clean tap
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    patterns.feed(s, 'c', 1) -- real usage (ciw) breaks the streak
    patterns.feed(s, 'v', 1)
    local result = patterns.feed(s, '\27', 1) -- only 1 clean tap since the break
    assert.is_nil(result)
  end)

  it('does not fire when an unrelated key interrupts the taps', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- 1st clean tap
    patterns.feed(s, 'x', 1) -- unrelated key breaks the streak
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1)
    local result = patterns.feed(s, 'v', 1) -- only 2 clean taps since the break
    assert.is_nil(result)
  end)

  it('does not confuse 3 genuine v-then-text-object actions with 3 bare taps', function()
    local s = seq()
    for _ = 1, 3 do
      patterns.feed(s, 'v', 1)
      patterns.feed(s, 'i', 1)
      patterns.feed(s, 'w', 1)
      patterns.feed(s, 'c', 1) -- ciw each time, never an <Esc> tap
    end
    local result = patterns.feed(s, 'v', 1)
    assert.is_nil(result)
  end)
end)

-- ── ci" / ci' × 3 (direct, non-visual) → suggest ya" / ya' (#53) ────────────
-- Distinct from visual_textobj above: this fires from the plain Normal-mode
-- c + i + "/' operator-pending sequence, never from v i " c. Streaks are
-- tracked separately per quote char, mirroring dd_streak/cc_streak's
-- per-operator split (#118).

describe('when the user changes inside double quotes (ci") 3 times in a row', function()
  it('fires ci_dquote_repeat suggesting ya" on the 3rd ci"', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1) -- 1st
    feed(s, { 'c', 'i', '"' }, 1) -- 2nd
    local result = feed(s, { 'c', 'i', '"' }, 1) -- 3rd → fires
    assert.is_not_nil(result)
    assert.equals('ci_dquote_repeat', result.pattern)
    assert.equals('ya"', result.cmd)
  end)

  it('does not fire after only 2 repeats', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_nil(result)
  end)

  it('resets the streak when an unrelated key interrupts the repeats', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'j', 1) -- unrelated key: interrupts
    feed(s, { 'c', 'i', '"' }, 1)
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_nil(result)
  end)

  it('does not count ca" (around, not inside) toward the streak', function()
    local s = seq()
    feed(s, { 'c', 'a', '"' }, 1)
    feed(s, { 'c', 'a', '"' }, 1)
    local result = feed(s, { 'c', 'a', '"' }, 1)
    assert.is_nil(result)
  end)

  it('does not count di" (delete, not change) toward the streak', function()
    local s = seq()
    feed(s, { 'd', 'i', '"' }, 1)
    feed(s, { 'd', 'i', '"' }, 1)
    local result = feed(s, { 'd', 'i', '"' }, 1)
    assert.is_nil(result)
  end)

  it("resets when a ci' lands in between (different quote char)", function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    feed(s, { 'c', 'i', "'" }, 1) -- different quote: resets the dquote streak
    feed(s, { 'c', 'i', '"' }, 1)
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_nil(result)
  end)
end)

describe("when the user changes inside single quotes (ci') 3 times in a row", function()
  it("fires ci_squote_repeat suggesting ya' on the 3rd ci'", function()
    local s = seq()
    feed(s, { 'c', 'i', "'" }, 1)
    feed(s, { 'c', 'i', "'" }, 1)
    local result = feed(s, { 'c', 'i', "'" }, 1)
    assert.is_not_nil(result)
    assert.equals('ci_squote_repeat', result.pattern)
    assert.equals("ya'", result.cmd)
  end)

  it('does not fire after only 2 repeats', function()
    local s = seq()
    feed(s, { 'c', 'i', "'" }, 1)
    local result = feed(s, { 'c', 'i', "'" }, 1)
    assert.is_nil(result)
  end)
end)

describe('when the user alternates between ci" and ci\' repeatedly', function()
  it('never fires either streak, since each completion resets the other', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    feed(s, { 'c', 'i', "'" }, 1)
    feed(s, { 'c', 'i', '"' }, 1)
    local result = feed(s, { 'c', 'i', "'" }, 1)
    assert.is_nil(result)
  end)
end)

describe('when a visual-mode ci" (v i " c) happens alongside direct ci" presses', function()
  it('does not let the visual_textobj completion count toward the direct-path streak', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, '"', 1)
    local visual_result = patterns.feed(s, 'c', 1) -- fires visual_textobj, unrelated state
    assert.equals('visual_textobj', visual_result.pattern)
    feed(s, { 'c', 'i', '"' }, 1) -- 1st direct
    local result = feed(s, { 'c', 'i', '"' }, 1) -- 2nd direct — not enough to fire
    assert.is_nil(result)
  end)
end)

-- ── c$ → C (change to end of line) ──────────────────────────────────────────

describe('when the user changes to end of line with c$', function()
  it('fires c_dollar suggesting C', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, '$', 1)
    assert.is_not_nil(result)
    assert.equals('c_dollar', result.pattern)
    assert.equals('C', result.cmd)
  end)

  it('does not fire when c is followed by a word motion', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
  end)
end)

-- ── d$ → D (delete to end of line) ──────────────────────────────────────────

describe('when the user deletes to end of line with d$', function()
  it('fires d_dollar suggesting D', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, '$', 1)
    assert.is_not_nil(result)
    assert.equals('d_dollar', result.pattern)
    assert.equals('D', result.cmd)
  end)

  it('does not fire dollar_then_append when $ follows an insert after d$', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, '$', 1) -- fires d_dollar, clears last_op
    local result = patterns.feed(s, 'a', 1)
    if result then
      assert.is_not_equal('dollar_then_append', result.pattern)
    end
  end)
end)

-- ── y$ → Y (yank to end of line) ─────────────────────────────────────────────

describe('when the user yanks to end of line with y$', function()
  it('fires y_dollar suggesting Y', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    local result = patterns.feed(s, '$', 1)
    assert.is_not_nil(result)
    assert.equals('y_dollar', result.pattern)
    assert.equals('Y', result.cmd)
  end)

  it('does not fire when y is followed by a word motion', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
  end)
end)

-- ── yy → p (duplicate line) ──────────────────────────────────────────────────

describe('when the user yanks a whole line then pastes it', function()
  it('fires yy_then_p suggesting yyp', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'y', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_not_nil(result)
    assert.equals('yy_then_p', result.pattern)
    assert.equals('yyp', result.cmd)
  end)

  it('does not fire when yy is followed by a non-paste key', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'y', 1)
    local result = patterns.feed(s, 'j', 1)
    assert.is_nil(result)
  end)

  it('does not fire for yw → p (only whole-line yank qualifies)', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'w', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_nil(result)
  end)
end)

-- ── >> × 3: suggest {n}>> ────────────────────────────────────────────────────

describe('when the user indents the current line 3 or more times in a row', function()
  it('fires indent_run suggesting {n}>>', function()
    local s = seq()
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_not_nil(result)
    assert.equals('indent_run', result.pattern)
    assert.equals('{n}>>', result.cmd)
  end)

  it('does not fire after only 2 consecutive >>', function()
    local s = seq()
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by a non-indent key', function()
    local s = seq()
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, 'j', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when > is followed by a non-> motion (e.g. >j)', function()
    local s = seq()
    -- Build up a streak of 2
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    -- >j: operator > but motion j, not >>  → resets streak
    patterns.feed(s, '>', 1)
    patterns.feed(s, 'j', 1)
    -- Two more >>: only 2, not enough for threshold
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_nil(result)
  end)
end)

-- ── << × 3: suggest {n}<< ────────────────────────────────────────────────────

describe('when the user dedents the current line 3 or more times in a row', function()
  it('fires dedent_run suggesting {n}<<', function()
    local s = seq()
    patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    local result = patterns.feed(s, '<', 1)
    assert.is_not_nil(result)
    assert.equals('dedent_run', result.pattern)
    assert.equals('{n}<<', result.cmd)
  end)

  it('does not fire after only 2 consecutive <<', function()
    local s = seq()
    patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    local result = patterns.feed(s, '<', 1)
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

-- ── " / @ register/macro prefix ───────────────────────────────────────────────

describe('when the user specifies a register with "', function()
  it('swallows the register name so it cannot trigger other patterns', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)

  it('does not fire dollar_then_append when $ then " then a', function()
    local s = seq()
    patterns.feed(s, '$', 1)
    patterns.feed(s, '"', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)
end)

-- ── "+y system-clipboard yank compound (#59) ──────────────────────────────────
-- Tracked as its own compound (distinct from the generic "consume and forget
-- the register name" behavior above) so graph.is_register_underused() has a
-- real "+y count == 0" signal to gate on instead of never knowing this
-- ever happened.

describe('when the user yanks to the system clipboard with "+y', function()
  it('tracks "+y as a completed compound', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, '+', 1)
    local result = patterns.feed(s, 'y', 1)
    assert.is_nil(result)
    assert.equals('"+y', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('does not consume the y key (still countable as a standalone y elsewhere)', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, '+', 1)
    patterns.feed(s, 'y', 1)
    assert.is_false(s.key_consumed)
  end)
end)

describe('when "+yy completes (register-select, then a full linewise yank)', function()
  it('does not leave a dangling pending_op that swallows the next keystroke', function()
    -- Regression test: the trailing y of "+yy used to fall through to the
    -- generic "d/c/y operator start" branch and set pending_op = 'y', which
    -- then silently consumed the very next keystroke as if it were y's
    -- motion. That swallowed keystroke never reached run-tracking, so
    -- j_repeat (count == 5) needed a 6th j instead of 5.
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, '+', 1)
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'y', 1)

    local result
    for _ = 1, 4 do
      result = patterns.feed(s, 'j', 1)
      assert.is_nil(result)
    end
    result = patterns.feed(s, 'j', 1)
    assert.equals('j_repeat', result.pattern)
    assert.equals('{n}j', result.cmd)
  end)

  it('still registers "+y as the completed compound, unaffected by the trailing y', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, '+', 1)
    patterns.feed(s, 'y', 1)
    assert.equals('"+y', s.last_op)
    assert.is_true(s.op_completed)

    local result = patterns.feed(s, 'y', 1)
    assert.is_nil(result)
    assert.is_nil(s.pending_op)
    assert.equals('"+y', s.last_op)
  end)
end)

describe('when "+ is followed by something other than y', function()
  it('does not track a "+y compound', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, '+', 1)
    patterns.feed(s, 'p', 1)
    assert.is_nil(s.last_op)
    assert.is_false(s.op_completed)
  end)
end)

describe('when a register other than + is selected before y', function()
  it('does not track a "+y compound for "ay', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, 'a', 1)
    local result = patterns.feed(s, 'y', 1)
    assert.is_nil(result)
    assert.is_nil(s.last_op)
  end)
end)

describe('when the user executes a macro with @', function()
  it('swallows the register name so it cannot trigger other patterns', function()
    local s = seq()
    patterns.feed(s, '@', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)
end)

-- ── m / ' / ` mark prefix ─────────────────────────────────────────────────────

describe('when the user sets a mark with m', function()
  it('swallows the mark name so it cannot trigger other patterns', function()
    local s = seq()
    patterns.feed(s, 'm', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)
end)

describe("when the user jumps to a mark with '", function()
  it('swallows the mark name so it cannot trigger k_then_o', function()
    local s = seq()
    patterns.feed(s, 'k', 1)
    patterns.feed(s, "'", 1)
    local result = patterns.feed(s, 'o', 1)
    assert.is_nil(result)
  end)
end)

describe('when the user jumps to a mark with `', function()
  it('swallows the mark name so it cannot trigger other patterns', function()
    local s = seq()
    patterns.feed(s, '`', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)
end)

-- ── [ / ] navigation prefix ───────────────────────────────────────────────────

describe('when the user uses [ or ] navigation', function()
  -- Without a pending_bracket guard, ]c incorrectly sets pending_op='c'.
  -- Then a second 'c' matches key==op and sets last_op='cc', so 'p' would
  -- fall through (no cc_then_p pattern exists) and stay nil either way; the
  -- pending_bracket guard is what prevents ]c from ever becoming pending_op
  -- in the first place, which this test verifies.
  it('does not fire dd_then_p for ]cc p (] c is navigation, not an operator)', function()
    local s = seq()
    patterns.feed(s, ']', 1)
    patterns.feed(s, 'c', 1) -- navigation target, must be swallowed by pending_bracket
    patterns.feed(s, 'c', 1) -- in correct code: starts a fresh change operator
    local result = patterns.feed(s, 'p', 1)
    assert.is_nil(result)
  end)

  it('swallows the following key after [', function()
    local s = seq()
    patterns.feed(s, '[', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_nil(result)
  end)
end)

-- ── g / pending_g two-key compound tracking ───────────────────────────────────

describe('when the user presses g followed by a motion key', function()
  local cases = {
    { key = 'g', last_op = 'gg' },
    { key = 'j', last_op = 'gj' },
    { key = 'k', last_op = 'gk' },
    { key = 'e', last_op = 'ge' },
    { key = 'd', last_op = 'gd' },
    { key = 'n', last_op = 'gn' },
    { key = 'x', last_op = 'gx' },
    { key = '0', last_op = 'g0' },
    -- #120: change-list nav / paste-without-jump / case-operator chains
    { key = ';', last_op = 'g;' },
    { key = 'p', last_op = 'gp' },
    { key = 'u', last_op = 'gu' },
  }

  for _, tc in ipairs(cases) do
    it('records last_op = ' .. tc.last_op, function()
      local s = seq()
      patterns.feed(s, 'g', 1)
      patterns.feed(s, tc.key, 1)
      assert.equals(tc.last_op, s.last_op)
    end)
  end

  it('does not set last_op for an unrecognised g-target', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    assert.is_nil(s.last_op)
  end)

  it('clears pending_g after the second key', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'j', 1)
    assert.is_false(s.pending_g)
  end)

  -- key_consumed is intentionally NOT set for g compounds so that external
  -- g key events from plugins cannot suppress the following key's TRACK count.
  it('does not set key_consumed on the second key', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'j', 1)
    assert.is_false(s.key_consumed)
  end)

  it('records last_op = gf (pending_g runs before the f-search handler)', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'f', 1)
    assert.equals('gf', s.last_op)
  end)
end)

-- ── g-compounds must reset consecutive-run tracking for their 2nd key (#30 QA) ─
-- Bug: adopting e_repeat's own suggestion (typing ge) did not reset the e-streak,
-- unlike w_repeat/W and b_repeat/B — a genuine "ge" completion left an e×4 streak
-- alive, so one more bare e re-fired e_repeat immediately. Root cause: the
-- pending_g dispatch above resolves and returns nil without ever calling
-- track_run(), so seq.run is simply frozen mid-streak rather than reset — this
-- is a property of the pending_g block itself, not something specific to 'e', so
-- it silently affects every g_targets entry whose second character also has its
-- own consecutive-run tracking (gj/gk/gn/gx/gp/gu, and the zero_then_w/g0 pair
-- below), not just ge.
describe('when a bare key streak is interrupted by a deliberate g-compound using the same key', function()
  it('does not fire e_repeat on the e right after a genuine ge completion', function()
    local s = seq()
    patterns.feed(s, 'e', 1)
    patterns.feed(s, 'e', 1)
    patterns.feed(s, 'e', 1)
    patterns.feed(s, 'e', 1) -- e x4, one short of firing
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'e', 1) -- forms ge: a genuine, deliberate use of the remedy
    local result = patterns.feed(s, 'e', 1) -- would have been the "5th" e pre-fix
    assert.is_nil(result)
  end)

  -- e/j/k/n/x/p/u all share the run_cases consecutive-run structure above AND are
  -- reachable as a pending_g target's 2nd key (g_targets: ge/gj/gk/gn/gx/gp/gu) —
  -- so they all share this same exposure. threshold matches run_cases above.
  local reset_cases = {
    { key = 'e', threshold = 5, pattern = 'e_repeat', cmd = 'ge' },
    { key = 'j', threshold = 5, pattern = 'j_repeat', cmd = '{n}j' },
    { key = 'k', threshold = 5, pattern = 'k_repeat', cmd = '{n}k' },
    { key = 'n', threshold = 4, pattern = 'n_repeat', cmd = 'cgn' },
    { key = 'x', threshold = 3, pattern = 'x_repeat', cmd = '{n}x' },
    { key = 'p', threshold = 3, pattern = 'p_repeat', cmd = '{n}p' },
    { key = 'u', threshold = 3, pattern = 'u_repeat', cmd = '<C-r>' },
  }

  for _, tc in ipairs(reset_cases) do
    it(
      'requires a full fresh streak of '
        .. tc.key
        .. ' before refiring '
        .. tc.pattern
        .. ' after an intervening g'
        .. tc.key,
      function()
        local s = seq()
        for _ = 1, tc.threshold - 1 do
          patterns.feed(s, tc.key, 1)
        end
        patterns.feed(s, 'g', 1)
        patterns.feed(s, tc.key, 1) -- forms g<key>: a genuine, different action
        local immediate = patterns.feed(s, tc.key, 1)
        assert.is_nil(immediate)
        for _ = 1, tc.threshold - 2 do
          patterns.feed(s, tc.key, 1)
        end
        local after_full_streak = patterns.feed(s, tc.key, 1)
        assert.is_not_nil(after_full_streak)
        assert.equals(tc.pattern, after_full_streak.pattern)
        assert.equals(tc.cmd, after_full_streak.cmd)
      end
    )
  end

  -- g0 shares the same pending_g exposure, but 0 is presence-tracked
  -- (zero_then_w checks seq.run.key == '0' directly, no count threshold), so it
  -- needs its own case rather than fitting the reset_cases table above.
  it('does not fire zero_then_w on the w right after a genuine g0 completion', function()
    local s = seq()
    patterns.feed(s, '0', 1)
    patterns.feed(s, 'g', 1)
    patterns.feed(s, '0', 1) -- forms g0: a genuine, deliberate use of true-column-0
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
  end)
end)

-- ── z / pending_z two-key compound tracking ───────────────────────────────────

describe('when the user presses z followed by a view command key', function()
  local cases = {
    { key = 'z', last_op = 'zz' },
    { key = 't', last_op = 'zt' },
    { key = 'b', last_op = 'zb' },
    { key = 'a', last_op = 'za' },
    { key = 'c', last_op = 'zc' },
    { key = 'o', last_op = 'zo' },
    { key = 'j', last_op = 'zj' },
    { key = 'k', last_op = 'zk' },
    { key = 'M', last_op = 'zM' },
    { key = 'R', last_op = 'zR' },
    { key = 'd', last_op = 'zd' },
  }

  for _, tc in ipairs(cases) do
    it('records last_op = ' .. tc.last_op, function()
      local s = seq()
      patterns.feed(s, 'z', 1)
      patterns.feed(s, tc.key, 1)
      assert.equals(tc.last_op, s.last_op)
    end)
  end

  it('does not set last_op for an unrecognised z-target', function()
    local s = seq()
    patterns.feed(s, 'z', 1)
    patterns.feed(s, 'q', 1)
    assert.is_nil(s.last_op)
  end)

  it('clears pending_z after the second key', function()
    local s = seq()
    patterns.feed(s, 'z', 1)
    patterns.feed(s, 'z', 1)
    assert.is_false(s.pending_z)
  end)

  it('does not set key_consumed on the second key', function()
    local s = seq()
    patterns.feed(s, 'z', 1)
    patterns.feed(s, 'z', 1)
    assert.is_false(s.key_consumed)
  end)
end)

-- ── <C-w> / pending_ctrl_w two-key compound tracking (#120) ───────────────────
-- Raw byte for Ctrl-W is ASCII 23 ('\23'), matching the byte vim.on_key
-- delivers and the literal used in patterns.lua — see logger_spec.lua's
-- integration-level coverage for the vim.api.nvim_replace_termcodes version.

describe('when the user presses <C-w> followed by a window-command key', function()
  local ctrl_w = '\23'
  local cases = {
    { key = 's', last_op = '<C-w>s' },
    { key = 'v', last_op = '<C-w>v' },
    { key = 'w', last_op = '<C-w>w' },
    { key = 'h', last_op = '<C-w>h' },
    { key = 'j', last_op = '<C-w>j' },
    { key = 'k', last_op = '<C-w>k' },
    { key = 'l', last_op = '<C-w>l' },
    { key = 'q', last_op = '<C-w>q' },
    { key = 'c', last_op = '<C-w>c' },
    { key = '=', last_op = '<C-w>=' },
  }

  for _, tc in ipairs(cases) do
    it('records last_op = ' .. tc.last_op, function()
      local s = seq()
      patterns.feed(s, ctrl_w, 1)
      patterns.feed(s, tc.key, 1)
      assert.equals(tc.last_op, s.last_op)
    end)
  end

  it('does not set last_op for an unrecognised window-command target', function()
    local s = seq()
    patterns.feed(s, ctrl_w, 1)
    patterns.feed(s, 'p', 1)
    assert.is_nil(s.last_op)
  end)

  it('clears pending_ctrl_w after the second key', function()
    local s = seq()
    patterns.feed(s, ctrl_w, 1)
    patterns.feed(s, 'w', 1)
    assert.is_false(s.pending_ctrl_w)
  end)

  it('does not set key_consumed on the second key', function()
    local s = seq()
    patterns.feed(s, ctrl_w, 1)
    patterns.feed(s, 'w', 1)
    assert.is_false(s.key_consumed)
  end)

  it('does not confuse a second <C-w> byte with the literal w target', function()
    -- <C-w><C-w> is a valid Vim window command (cycle window) but uses two
    -- raw Ctrl-W bytes, not <C-w> + literal 'w'. This case is intentionally
    -- not in ctrl_w_targets — see logger_spec.lua's assertion that repeated
    -- <C-w> must never be conflated with the insert-mode <C-w> command.
    local s = seq()
    patterns.feed(s, ctrl_w, 1)
    patterns.feed(s, ctrl_w, 1)
    assert.is_nil(s.last_op)
  end)
end)

-- ── gq operator (format) + jump-back → suggest gw ─────────────────────────────
-- gq is a real Vim operator: unlike gg/gj/gd (simple two-key pending_g targets
-- that complete immediately), gq needs a further motion (gqq, gqap, gq}) before
-- it's "done". A completed gq followed immediately by a jump-back (`` ` ` `` or
-- <C-o>) means the user formatted text, then manually returned to where they
-- started — exactly what gw already does for free by leaving the cursor in place.

describe('when the user completes a gq format operation', function()
  it('records last_op = gq for the linewise gqq form', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    local result = patterns.feed(s, 'q', 1)
    assert.is_nil(result)
    assert.equals('gq', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('records last_op = gq for the gqap text-object form', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, 'a', 1)
    local result = patterns.feed(s, 'p', 1)
    assert.is_nil(result)
    assert.equals('gq', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('records last_op = gq for the gq} motion form', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    local result = patterns.feed(s, '}', 1)
    assert.is_nil(result)
    assert.equals('gq', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('does not complete gq on just g q (still pending a motion)', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    assert.is_nil(s.last_op)
    assert.is_false(s.op_completed)
  end)

  it('supports a count prefix before the motion (gq3j)', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, '3', 1)
    patterns.feed(s, 'j', 1)
    assert.equals('gq', s.last_op)
  end)

  it('cancels a pending gq with Escape', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, '\27', 1) -- <Esc>
    assert.is_nil(s.last_op)
  end)
end)

describe('when the user completes gq then jumps back with ` `', function()
  it('fires gq_then_jumpback suggesting gw', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, 'a', 1)
    patterns.feed(s, 'p', 1) -- gqap completes
    patterns.feed(s, '`', 1)
    local result = patterns.feed(s, '`', 1)
    assert.is_not_nil(result)
    assert.equals('gq_then_jumpback', result.pattern)
    assert.equals('gw', result.cmd)
  end)

  it('fires for the linewise gqq form too', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, 'q', 1) -- gqq completes
    patterns.feed(s, '`', 1)
    local result = patterns.feed(s, '`', 1)
    assert.is_not_nil(result)
    assert.equals('gq_then_jumpback', result.pattern)
    assert.equals('gw', result.cmd)
  end)
end)

describe('when the user completes gq then jumps back with <C-o>', function()
  it('fires gq_then_jumpback suggesting gw', function()
    local ctrl_o = '\15'
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, 'q', 1) -- gqq completes
    local result = patterns.feed(s, ctrl_o, 1)
    assert.is_not_nil(result)
    assert.equals('gq_then_jumpback', result.pattern)
    assert.equals('gw', result.cmd)
  end)
end)

describe('when a jump-back is not preceded by a completed gq', function()
  it('does not fire gq_then_jumpback for backtick-backtick on its own', function()
    local s = seq()
    patterns.feed(s, '`', 1)
    local result = patterns.feed(s, '`', 1)
    assert.is_nil(result)
  end)

  it('does not fire gq_then_jumpback for <C-o> on its own', function()
    local ctrl_o = '\15'
    local s = seq()
    local result = patterns.feed(s, ctrl_o, 1)
    assert.is_nil(result)
  end)

  it('does not fire when gq is followed by a mark jump other than backtick (`a)', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, 'q', 1) -- gqq completes
    patterns.feed(s, '`', 1)
    local result = patterns.feed(s, 'a', 1)
    assert.is_nil(result)
  end)

  it('does not fire when another key separates gq from the jump-back', function()
    local ctrl_o = '\15'
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'q', 1)
    patterns.feed(s, 'q', 1) -- gqq completes
    patterns.feed(s, 'j', 1) -- unrelated key clears last_op
    local result = patterns.feed(s, ctrl_o, 1)
    assert.is_nil(result)
  end)
end)

-- ── <C-w>q / <C-w>c repeated → <C-w>o (#107) ──────────────────────────────────
-- Closing windows one at a time with <C-w>q or <C-w>c, repeated (or alternated)
-- 2+ times in a row, means the user wants to get back down to a single window —
-- <C-w>o (close all other windows) does that in one step.

describe('when the user closes windows one at a time', function()
  local ctrl_w = '\23'

  local function press(s, key)
    patterns.feed(s, ctrl_w, 1)
    return patterns.feed(s, key, 1)
  end

  it('fires ctrl_w_close_repeat suggesting <C-w>o after two <C-w>q in a row', function()
    local s = seq()
    press(s, 'q')
    local result = press(s, 'q')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_close_repeat', result.pattern)
    assert.equals('<C-w>o', result.cmd)
  end)

  it('fires ctrl_w_close_repeat suggesting <C-w>o after two <C-w>c in a row', function()
    local s = seq()
    press(s, 'c')
    local result = press(s, 'c')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_close_repeat', result.pattern)
    assert.equals('<C-w>o', result.cmd)
  end)

  it('fires when <C-w>q is followed by <C-w>c (mixed close actions count together)', function()
    local s = seq()
    press(s, 'q')
    local result = press(s, 'c')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_close_repeat', result.pattern)
    assert.equals('<C-w>o', result.cmd)
  end)

  it('fires when <C-w>c is followed by <C-w>q (mixed close actions count together)', function()
    local s = seq()
    press(s, 'c')
    local result = press(s, 'q')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_close_repeat', result.pattern)
    assert.equals('<C-w>o', result.cmd)
  end)

  it('does not fire after only a single <C-w>q', function()
    local s = seq()
    local result = press(s, 'q')
    assert.is_nil(result)
  end)

  it('does not fire after only a single <C-w>c', function()
    local s = seq()
    local result = press(s, 'c')
    assert.is_nil(result)
  end)

  it('resets the streak after firing, so a 3rd close does not immediately refire', function()
    local s = seq()
    press(s, 'q')
    press(s, 'q') -- fires here
    local result = press(s, 'q')
    assert.is_nil(result)
  end)

  it('fires again once 2 more closes accumulate after a previous fire', function()
    local s = seq()
    press(s, 'q')
    press(s, 'q') -- fires here
    press(s, 'q')
    local result = press(s, 'q')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_close_repeat', result.pattern)
  end)

  it('resets the streak when interrupted by a different window command (<C-w>s)', function()
    local s = seq()
    press(s, 'q')
    press(s, 's') -- interrupt: not a close action
    local result = press(s, 'q')
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by an unrelated normal-mode key', function()
    local s = seq()
    press(s, 'q')
    patterns.feed(s, 'j', 1) -- interrupt: unrelated key, no <C-w> prefix
    local result = press(s, 'q')
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by an unrecognised window-command target', function()
    local s = seq()
    press(s, 'q')
    press(s, 'p') -- interrupt: not in ctrl_w_targets at all
    local result = press(s, 'q')
    assert.is_nil(result)
  end)
end)

-- ── key_consumed flag ─────────────────────────────────────────────────────────

describe('when a key is consumed as part of a preceding register, mark, or [ / ] prefix', function()
  it('is false after a plain navigation key', function()
    local s = seq()
    patterns.feed(s, 'j', 1)
    assert.is_false(s.key_consumed)
  end)

  it('is false after the g starter key itself', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    assert.is_false(s.key_consumed)
  end)

  it('is false after the second char of a g compound', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'j', 1)
    assert.is_false(s.key_consumed)
  end)

  it('is false after the second char of a z compound', function()
    local s = seq()
    patterns.feed(s, 'z', 1)
    patterns.feed(s, 'z', 1)
    assert.is_false(s.key_consumed)
  end)

  it('is true after the register name following "', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, 'a', 1)
    assert.is_true(s.key_consumed)
  end)

  it('is true after the register name following @', function()
    local s = seq()
    patterns.feed(s, '@', 1)
    patterns.feed(s, 'q', 1)
    assert.is_true(s.key_consumed)
  end)

  it('is true after the mark name following m', function()
    local s = seq()
    patterns.feed(s, 'm', 1)
    patterns.feed(s, 'a', 1)
    assert.is_true(s.key_consumed)
  end)

  it("is true after the mark name following '", function()
    local s = seq()
    patterns.feed(s, "'", 1)
    patterns.feed(s, 'a', 1)
    assert.is_true(s.key_consumed)
  end)

  it('is true after the target following [', function()
    local s = seq()
    patterns.feed(s, '[', 1)
    patterns.feed(s, 'c', 1)
    assert.is_true(s.key_consumed)
  end)

  it('is true after the target following ]', function()
    local s = seq()
    patterns.feed(s, ']', 1)
    patterns.feed(s, 'c', 1)
    assert.is_true(s.key_consumed)
  end)

  it('is reset to false at the start of every feed call', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, 'a', 1)
    assert.is_true(s.key_consumed)
    patterns.feed(s, 'j', 1)
    assert.is_false(s.key_consumed)
  end)
end)

-- ── op_completed flag (#119) ────────────────────────────────────────────────
-- seq.op_completed is true only on the exact feed() call that freshly assigns
-- seq.last_op. logger.lua increments usage from this flag rather than from a
-- value-change comparison, so two identical compounds back-to-back (dd dd,
-- dw dw, …) are each counted once — a value-change comparison cannot tell
-- "the same compound completed twice" from "nothing happened".

describe('when an operator command freshly completes, as opposed to merely repeating the same one', function()
  it('is false after only the first key of a pending operator', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    assert.is_false(s.op_completed)
  end)

  it('is true on the exact key that completes dd', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    assert.is_true(s.op_completed)
  end)

  it('is true again when a second, identical dd completes right after the first', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    assert.is_true(s.op_completed) -- 1st dd
    patterns.feed(s, 'd', 1)
    assert.is_false(s.op_completed) -- pending again, not yet completed
    patterns.feed(s, 'd', 1)
    assert.is_true(s.op_completed) -- 2nd dd, same value as last_op but freshly completed
  end)

  it('is true on the exact key that completes dw', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'w', 1)
    assert.is_true(s.op_completed)
  end)

  it('is true again when a second, identical dw completes right after the first', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'w', 1)
    assert.is_true(s.op_completed)
    patterns.feed(s, 'd', 1)
    assert.is_false(s.op_completed)
    patterns.feed(s, 'w', 1)
    assert.is_true(s.op_completed)
  end)

  -- #120's pending_ctrl_w dispatch table was added after op_completed (#119)
  -- already existed elsewhere in this file (pending_g / pending_z), so its
  -- last_op assignment needed the same flag added by hand during the merge —
  -- this guards against that path silently regressing to the #119 bug.
  it('is true again when a second, identical <C-w>j completes right after the first', function()
    local ctrl_w = '\23'
    local s = seq()
    patterns.feed(s, ctrl_w, 1)
    patterns.feed(s, 'j', 1)
    assert.is_true(s.op_completed)
    patterns.feed(s, ctrl_w, 1)
    assert.is_false(s.op_completed)
    patterns.feed(s, 'j', 1)
    assert.is_true(s.op_completed)
  end)

  -- #107 adds <C-w>c to the pending_ctrl_w dispatch table (it was not tracked
  -- at all before). Guard against the same #119 undercounting bug reappearing
  -- on this newly-added entry.
  it('is true again when a second, identical <C-w>c completes right after the first', function()
    local ctrl_w = '\23'
    local s = seq()
    patterns.feed(s, ctrl_w, 1)
    patterns.feed(s, 'c', 1)
    assert.is_true(s.op_completed)
    patterns.feed(s, ctrl_w, 1)
    assert.is_false(s.op_completed)
    patterns.feed(s, 'c', 1)
    assert.is_true(s.op_completed)
  end)

  it('is false on the p that consumes dd_then_p (last_op cleared, not freshly set)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'p', 1)
    assert.is_false(s.op_completed)
  end)

  it('is false on the insert key that consumes dw_then_insert (last_op cleared, not freshly set)', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'w', 1)
    patterns.feed(s, 'i', 1)
    assert.is_false(s.op_completed)
  end)

  it('is reset to false at the start of every feed call', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    assert.is_true(s.op_completed)
    patterns.feed(s, 'j', 1)
    assert.is_false(s.op_completed)
  end)
end)

-- ── jumplist underuse: G / gg / search → manual scroll back → <C-o> (#61) ────
-- patterns.feed's 4th argument is a caller-supplied clock reading (ms); real
-- callers pass vim.loop.now(), these tests pass fixed numbers so the
-- tolerance-window boundary is deterministic instead of depending on how
-- fast the test itself runs.

describe('when the user jumps to end of file then scrolls back manually', function()
  it('fires manual_return suggesting <C-o> after G then 5 k presses', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals('<C-o>', result.cmd)
  end)

  it('has fired manual_return by the time 10 k presses have happened', function()
    -- Plain k_repeat / k_many (5-in-a-row / 10-in-a-row, no jump context
    -- required) are also legitimately true of this exact keystroke sequence
    -- and may fire on later presses once manual_return has already reset
    -- its own streak — this only asserts manual_return fired at least once,
    -- not that it was the only thing that fired.
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    local saw_manual_return = false
    for _ = 1, 10 do
      local result = patterns.feed(s, 'k', 1, nil, 0)
      if result and result.pattern == 'manual_return' then
        saw_manual_return = true
        assert.equals('<C-o>', result.cmd)
      end
    end
    assert.is_true(saw_manual_return)
  end)

  it('does not fire after only 2 k presses — not enough evidence', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_nil(result)
  end)

  it('does not fire once the tolerance window has expired (30s later)', function()
    -- k_repeat is still a legitimate, unrelated fire here (5 k's in a row
    -- regardless of context) — only manual_return must not have fired.
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 30000)
    end
    local result = patterns.feed(s, 'k', 1, nil, 30000)
    if result then
      assert.is_not_equal('manual_return', result.pattern)
    end
  end)

  it('does not fire without a preceding significant jump', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    -- k_repeat legitimately fires here — 5 k's in a row is true regardless
    -- of jump context; manual_return specifically must not.
    if result then
      assert.is_not_equal('manual_return', result.pattern)
    end
  end)

  it('is suppressed once the user has already pressed <C-o> this session', function()
    -- k_repeat is still a legitimate, unrelated fire here — only
    -- manual_return must not have fired.
    local ctrl_o = '\15'
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, ctrl_o, 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    if result then
      assert.is_not_equal('manual_return', result.pattern)
    end
  end)

  it('also fires after gg (jump to start of file)', function()
    local s = seq()
    patterns.feed(s, 'g', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'j', 1, nil, 0)
    end
    local result = patterns.feed(s, 'j', 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals('<C-o>', result.cmd)
  end)

  it('counts a mix of j / k / <C-e> / <C-y> toward the same streak', function()
    local ctrl_e = '\5'
    local ctrl_y = '\25'
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, ctrl_e, 1, nil, 0)
    patterns.feed(s, 'j', 1, nil, 0)
    patterns.feed(s, ctrl_y, 1, nil, 0)
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
  end)

  it('resets the streak when a non-return key interrupts it', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, 'l', 1, nil, 0) -- interrupt: not a return motion
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_nil(result)
  end)

  local significant_motion_cases = {
    { key = 'n', label = 'n' },
    { key = 'N', label = 'N' },
    { key = '\4', label = '<C-d>' },
    { key = '\21', label = '<C-u>' },
    { key = '\6', label = '<C-f>' },
    { key = '\2', label = '<C-b>' },
  }

  for _, tc in ipairs(significant_motion_cases) do
    it('also treats ' .. tc.label .. ' as a significant jump motion', function()
      local s = seq()
      patterns.feed(s, tc.key, 1, nil, 0)
      for _ = 1, 4 do
        patterns.feed(s, 'k', 1, nil, 0)
      end
      local result = patterns.feed(s, 'k', 1, nil, 0)
      assert.is_not_nil(result)
      assert.equals('manual_return', result.pattern)
    end)
  end
end)

-- ── changelist underuse: edit A, move, edit B, scroll back → g; (#61) ────────

describe('when the user edits two different places then scrolls back', function()
  local function two_edits(s, at)
    patterns.feed(s, 'i', 1, nil, at) -- edit #1
    patterns.feed(s, '\27', 1, nil, at) -- <Esc>
    patterns.feed(s, 'j', 1, nil, at) -- move away from it
    patterns.feed(s, 'i', 1, nil, at) -- edit #2, at a different spot
    patterns.feed(s, '\27', 1, nil, at)
  end

  it('fires changelist_return suggesting g; after 5 line motions back', function()
    local s = seq()
    two_edits(s, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('changelist_return', result.pattern)
    assert.equals('g;', result.cmd)
  end)

  it('does not fire after only 2 line motions', function()
    local s = seq()
    two_edits(s, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_nil(result)
  end)

  it('does not fire once the tolerance window has expired', function()
    -- k_repeat is still a legitimate, unrelated fire here (5 k's in a row
    -- regardless of context) — only changelist_return must not have fired.
    local s = seq()
    two_edits(s, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 30000)
    end
    local result = patterns.feed(s, 'k', 1, nil, 30000)
    if result then
      assert.is_not_equal('changelist_return', result.pattern)
    end
  end)

  it('does not fire after only a single edit — no second, elsewhere edit yet', function()
    local s = seq()
    patterns.feed(s, 'i', 1, nil, 0)
    patterns.feed(s, '\27', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    if result then
      assert.is_not_equal('changelist_return', result.pattern)
    end
  end)

  it('does not fire when the second edit is at the same spot (no motion in between)', function()
    local s = seq()
    patterns.feed(s, 'i', 1, nil, 0)
    patterns.feed(s, '\27', 1, nil, 0)
    patterns.feed(s, 'i', 1, nil, 0) -- re-enters insert immediately, nothing moved in between
    patterns.feed(s, '\27', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    if result then
      assert.is_not_equal('changelist_return', result.pattern)
    end
  end)

  it('is suppressed once the user has already pressed g; this session', function()
    local s = seq()
    two_edits(s, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    patterns.feed(s, ';', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    if result then
      assert.is_not_equal('changelist_return', result.pattern)
    end
  end)

  it('also fires via x — a direct edit that never enters insert mode', function()
    local s = seq()
    patterns.feed(s, 'x', 1, nil, 0) -- edit #1
    patterns.feed(s, 'j', 1, nil, 0) -- move away
    patterns.feed(s, 'x', 1, nil, 0) -- edit #2, at a different spot
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('changelist_return', result.pattern)
    assert.equals('g;', result.cmd)
  end)

  it('resets the streak when a non-line-motion key interrupts it', function()
    local s = seq()
    two_edits(s, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, 'l', 1, nil, 0) -- interrupt: not a line motion
    patterns.feed(s, 'k', 1, nil, 0)
    patterns.feed(s, 'k', 1, nil, 0)
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.is_nil(result)
  end)
end)

-- ── arbitration when both preconditions are true at once (#61 regression) ───
-- Reported by live QA: 10G → x (edit) → 40G → x (edit) → k×5 back always
-- suggested <C-o>, never g;, because the jumplist check ran first in
-- inner_feed and returned early — changelist_return never even got
-- evaluated on that keystroke. The fix is to evaluate both conditions before
-- deciding, and let the more recent "away" event win.

describe('when both the jumplist and changelist preconditions are true on the same keystroke', function()
  it('fires changelist_return, not manual_return, when the second edit is more recent than the jump', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0) -- jump #1 (e.g. 10G)
    patterns.feed(s, 'x', 1, nil, 0) -- edit #1
    patterns.feed(s, 'G', 1, nil, 0) -- jump #2 (e.g. 40G) — most recent jump
    patterns.feed(s, 'x', 1, nil, 10) -- edit #2, elsewhere, more recent than the jump
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 20)
    end
    local result = patterns.feed(s, 'k', 1, nil, 20)
    assert.is_not_nil(result)
    assert.equals('changelist_return', result.pattern)
    assert.equals('g;', result.cmd)
  end)

  it('fires manual_return, not changelist_return, when the jump is more recent than the second edit', function()
    local s = seq()
    patterns.feed(s, 'x', 1, nil, 0) -- edit #1
    patterns.feed(s, 'j', 1, nil, 0) -- move away
    patterns.feed(s, 'x', 1, nil, 0) -- edit #2, elsewhere — most recent edit
    patterns.feed(s, 'G', 1, nil, 10) -- jump, more recent than the second edit
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 20)
    end
    local result = patterns.feed(s, 'k', 1, nil, 20)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals('<C-o>', result.cmd)
  end)
end)

-- ── macro opportunity detection: repeated edit sequence → qq...q / @q (#60) ──
--
-- M.feed_macro(seq, token, now) is a separate entry point from M.feed(), fed
-- by logger.lua from BOTH the normal- and insert-mode branches of
-- handle_key() (unlike everything else in this file, which is normal-mode
-- only) — see patterns.lua's own header comment on M.feed_macro for why.
-- These tests call it directly with each character of the literal keystroke
-- sequence, exactly the same "expose a pure function, call it directly"
-- approach the rest of this file uses (see tests/CLAUDE.md).

local function feed_macro_seq(s, keys, now_start)
  local result
  local now = now_start
  for _, k in ipairs(keys) do
    result = patterns.feed_macro(s, k, now)
    if now then
      now = now + 1
    end
  end
  return result
end

-- The literal issue-#60 example: cwFooBar<Esc> contains a lowercase 'w' and
-- an uppercase 'B' — both members of the same naive "motion key" set a wrong
-- implementation would use to classify gap characters. This is the pitfall
-- regression test: it must fire correctly despite S itself containing keys
-- that look like navigation.
local CW_FOOBAR_ESC = { 'c', 'w', 'F', 'o', 'o', 'B', 'a', 'r', '<Esc>' }

describe('when the user manually repeats an identical edit sequence 3 times', function()
  it(
    'fires macro_opportunity suggesting @q for cwFooBar<Esc> repeated 3x with j navigation between (#60 pitfall regression: S itself contains w/B, both classified as motion keys)',
    function()
      local s = seq()
      feed_macro_seq(s, CW_FOOBAR_ESC)
      feed_macro_seq(s, { 'j' })
      feed_macro_seq(s, CW_FOOBAR_ESC)
      feed_macro_seq(s, { 'j' })
      local result = feed_macro_seq(s, CW_FOOBAR_ESC)
      assert.is_not_nil(result)
      assert.equals('macro_opportunity', result.pattern)
      assert.equals('@q', result.cmd)
    end
  )

  it('fires when the 3 occurrences are back-to-back with no navigation gap at all', function()
    local s = seq()
    feed_macro_seq(s, { 'a', 'b', 'c' })
    feed_macro_seq(s, { 'a', 'b', 'c' })
    local result = feed_macro_seq(s, { 'a', 'b', 'c' })
    assert.is_not_nil(result)
    assert.equals('macro_opportunity', result.pattern)
    assert.equals('@q', result.cmd)
  end)
end)

describe('when the user repeats an identical edit sequence only twice', function()
  it('does not fire macro_opportunity (needs 3+ repetitions)', function()
    local s = seq()
    feed_macro_seq(s, CW_FOOBAR_ESC)
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, CW_FOOBAR_ESC)
    assert.is_nil(result)
  end)
end)

describe('when the user types an edit sequence only once', function()
  it('does not fire macro_opportunity', function()
    local s = seq()
    local result = feed_macro_seq(s, CW_FOOBAR_ESC)
    assert.is_nil(result)
  end)
end)

describe('when the repeated sequence itself contains a register/macro key', function()
  it('does not fire macro_opportunity when S contains q', function()
    local s = seq()
    feed_macro_seq(s, { 'x', 'q', 'y' })
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'x', 'q', 'y' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'x', 'q', 'y' })
    assert.is_nil(result)
  end)

  it('does not fire macro_opportunity when S contains @', function()
    local s = seq()
    feed_macro_seq(s, { 'x', '@', 'y' })
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'x', '@', 'y' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'x', '@', 'y' })
    assert.is_nil(result)
  end)
end)

describe('when 3 repetitions span more than the 30-second detection window', function()
  it('does not fire macro_opportunity', function()
    local s = seq()
    -- rep1 @ t=0..2, gap @ t=3, rep2 @ t=4..6, gap @ t=7, rep3 @ t=40000..40002
    -- (40002 - 0 = 40002ms, over the 30000ms window).
    patterns.feed_macro(s, 'a', 0)
    patterns.feed_macro(s, 'b', 1)
    patterns.feed_macro(s, 'c', 2)
    patterns.feed_macro(s, 'j', 3)
    patterns.feed_macro(s, 'a', 4)
    patterns.feed_macro(s, 'b', 5)
    patterns.feed_macro(s, 'c', 6)
    patterns.feed_macro(s, 'j', 7)
    patterns.feed_macro(s, 'a', 40000)
    patterns.feed_macro(s, 'b', 40001)
    local result = patterns.feed_macro(s, 'c', 40002)
    assert.is_nil(result)
  end)
end)

describe('when 3 repetitions all fall within the 30-second detection window', function()
  it('fires macro_opportunity', function()
    local s = seq()
    patterns.feed_macro(s, 'a', 0)
    patterns.feed_macro(s, 'b', 1)
    patterns.feed_macro(s, 'c', 2)
    patterns.feed_macro(s, 'j', 3)
    patterns.feed_macro(s, 'a', 4)
    patterns.feed_macro(s, 'b', 5)
    patterns.feed_macro(s, 'c', 6)
    patterns.feed_macro(s, 'j', 7)
    patterns.feed_macro(s, 'a', 8000)
    patterns.feed_macro(s, 'b', 8001)
    local result = patterns.feed_macro(s, 'c', 8002)
    assert.is_not_nil(result)
    assert.equals('macro_opportunity', result.pattern)
  end)
end)

describe('when the repeated window S is pure navigation (#60 follow-up bug)', function()
  it(
    'does not fire macro_opportunity for 12x repeated bare j (holding j to scroll is not a macro candidate)',
    function()
      local s = seq()
      local result
      for _ = 1, 12 do
        result = patterns.feed_macro(s, 'j')
      end
      assert.is_nil(result)
    end
  )

  it('does not fire macro_opportunity for 0fh repeated 4x back-to-back (multi-key pure navigation)', function()
    local s = seq()
    local result
    for _ = 1, 4 do
      result = feed_macro_seq(s, { '0', 'f', 'h' })
    end
    assert.is_nil(result)
  end)

  it('still fires macro_opportunity when a nav-only-looking window also contains a real edit key', function()
    -- Sanity check for the fix's own boundary: 'x' (a direct-edit key, see
    -- EDIT_OP_KEYS) sitting among otherwise-navigation keys is enough to
    -- qualify S — the fix requires an edit ANYWHERE in S, not that S is
    -- edit-only.
    local s = seq()
    local result
    for _ = 1, 3 do
      result = feed_macro_seq(s, { 'h', 'x', 'l' })
    end
    assert.is_not_nil(result)
    assert.equals('macro_opportunity', result.pattern)
    assert.equals('@q', result.cmd)
  end)
end)

describe("seq.macro_buf's bounded growth", function()
  it('trims back down to the soft cap once the hard cap is exceeded', function()
    local s = seq()
    for i = 1, 151 do
      patterns.feed_macro(s, 'TOK' .. tostring(i % 5))
    end
    assert.equals(100, #s.macro_buf)
  end)
end)

-- ── gg ↔ G double-jump: suggest '' (jump back to previous position) (#52) ────
-- Unlike manual_return above, this pattern requires the opposite jump to be
-- the very NEXT resolved action — no tolerance window, no streak. Any other
-- resolved key in between cancels it (see patterns.lua's inner_feed for how
-- last_op is reused, rather than a dedicated field, to get this for free).

describe('when the user jumps to the end of the file then back to the start', function()
  it("fires jump_back suggesting '' after G then gg", function()
    local s = seq()
    patterns.feed(s, 'G', 1)
    patterns.feed(s, 'g', 1)
    local result = patterns.feed(s, 'g', 1)
    assert.is_not_nil(result)
    assert.equals('jump_back', result.pattern)
    assert.equals("''", result.cmd)
  end)

  it('still records last_op = gg so the gg keystroke itself is counted as used', function()
    local s = seq()
    patterns.feed(s, 'G', 1)
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'g', 1)
    assert.equals('gg', s.last_op)
  end)

  it('still sets op_completed so logger.lua counts this gg (usage-tracking contract)', function()
    local s = seq()
    patterns.feed(s, 'G', 1)
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'g', 1)
    assert.is_true(s.op_completed)
  end)

  it('does not fire when an unrelated key happens between G and gg', function()
    local s = seq()
    patterns.feed(s, 'G', 1)
    patterns.feed(s, 'x', 1) -- unrelated key breaks the back-to-back requirement
    patterns.feed(s, 'g', 1)
    local result = patterns.feed(s, 'g', 1)
    if result then
      assert.is_not_equal('jump_back', result.pattern)
    end
  end)

  it('does not fire for gg on its own (no preceding G)', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    local result = patterns.feed(s, 'g', 1)
    assert.is_nil(result)
  end)

  it('does not fire for a different g-compound between G and gg (G then gd then gg)', function()
    local s = seq()
    patterns.feed(s, 'G', 1)
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'd', 1) -- resolves to gd, not gg
    patterns.feed(s, 'g', 1)
    local result = patterns.feed(s, 'g', 1)
    if result then
      assert.is_not_equal('jump_back', result.pattern)
    end
  end)
end)

describe('when the user jumps to the start of the file then back to the end', function()
  it("fires jump_back suggesting '' after gg then G", function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'g', 1)
    local result = patterns.feed(s, 'G', 1)
    assert.is_not_nil(result)
    assert.equals('jump_back', result.pattern)
    assert.equals("''", result.cmd)
  end)

  it('does not fire for G on its own (no preceding gg)', function()
    local s = seq()
    local result = patterns.feed(s, 'G', 1)
    assert.is_nil(result)
  end)

  it('does not fire when an unrelated key happens between gg and G', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'x', 1) -- unrelated key breaks the back-to-back requirement
    local result = patterns.feed(s, 'G', 1)
    if result then
      assert.is_not_equal('jump_back', result.pattern)
    end
  end)

  it('allows the round trip to fire again on a further gg ↔ G alternation', function()
    local s = seq()
    patterns.feed(s, 'g', 1)
    patterns.feed(s, 'g', 1)
    local first = patterns.feed(s, 'G', 1)
    patterns.feed(s, 'g', 1)
    local second = patterns.feed(s, 'g', 1)
    assert.equals('jump_back', first.pattern)
    assert.equals('jump_back', second.pattern)
  end)
end)

-- ── regression: jump_back firing must not skip jumplist bookkeeping ─────────
-- jump_back and manual_return (#61) share seq.jump_last_at. Both firing paths
-- above must leave it exactly as fresh as an ordinary G/gg keystroke would --
-- otherwise a later, entirely unrelated manual_return check reads a stale
-- timestamp and fires k_repeat instead. See patterns.lua's inner_feed: each
-- jump_back path now runs its jumplist bookkeeping BEFORE returning the
-- jump_back result, instead of returning early and skipping it.

describe('when a bare G fires jump_back via the gg -> G check (last_op already "gg")', function()
  it('refreshes jump_last_at so a real k-streak right after still fires manual_return', function()
    local s = seq()
    -- A bare, non-firing gg (no preceding G) leaves last_op == 'gg', exactly
    -- the leftover state the bug exploited.
    patterns.feed(s, 'g', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    local fired = patterns.feed(s, 'G', 1, nil, 1000)
    assert.equals('jump_back', fired.pattern)
    assert.equals(1000, s.jump_last_at)

    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 1100)
    end
    local result = patterns.feed(s, 'k', 1, nil, 1100)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals('<C-o>', result.cmd)
  end)

  it('reproduces the reported bug: earlier G -> gg fire, idle/paste gap, then a real G -> k-streak', function()
    local s = seq()
    -- First, a legitimate G -> gg round trip fires jump_back via the
    -- pending_g dispatch path. last_op is deliberately left as 'gg'
    -- afterwards (by design, so a further alternation can still fire).
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    local first = patterns.feed(s, 'g', 1, nil, 0)
    assert.equals('jump_back', first.pattern)

    -- Long idle gap (well past JUMP_TOLERANCE_MS from t=0), then a paste --
    -- neither clears last_op == 'gg' by design -- then an entirely ordinary,
    -- unrelated bare G: "check the end of the file", not part of any
    -- alternation. Deliberately timed so a k-streak shortly after this G
    -- only stays within tolerance of THIS G's timestamp, not the stale one
    -- from the first jump_back -- proving jump_last_at was truly refreshed
    -- rather than merely still coincidentally within range of the old value.
    patterns.feed(s, 'p', 1, nil, 3000)
    local second = patterns.feed(s, 'G', 1, nil, 20000)
    assert.equals('jump_back', second.pattern)

    -- A real k-streak right after that real G must be read against ITS
    -- timestamp, not the stale one from the first jump_back.
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 20100)
    end
    local result = patterns.feed(s, 'k', 1, nil, 20100)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals('<C-o>', result.cmd)
  end)
end)

describe('when gg fires jump_back via the G -> gg check (pending_g dispatch)', function()
  it('refreshes jump_last_at to the firing keystroke (confirmed already-correct, now covered)', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 500)
    local fired = patterns.feed(s, 'g', 1, nil, 500)
    assert.equals('jump_back', fired.pattern)
    assert.equals(500, s.jump_last_at)
  end)

  it('lets a real k-streak right after fire manual_return, not k_repeat', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 500)
    local fired = patterns.feed(s, 'g', 1, nil, 500)
    assert.equals('jump_back', fired.pattern)

    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 600)
    end
    local result = patterns.feed(s, 'k', 1, nil, 600)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals('<C-o>', result.cmd)
  end)
end)

-- ── design decision: jump_back's own last_op reuse stays keystroke-only ─────
-- Deliberately NOT given a JUMP_TOLERANCE_MS-style time bound, unlike
-- jump_last_at/manual_return above. Issue #52's acceptance criteria and the
-- existing "no tolerance window, no streak" comment above (see the "gg <->
-- G double-jump" section header) only ever describe back-to-back
-- KEYSTROKES, never elapsed time -- adding a bound here would be new scope,
-- not a fix for the reported bug (which is fully resolved by keeping
-- jump_last_at itself fresh, covered above). This test pins the existing,
-- intentional behavior down so a future change doesn't silently alter it.
describe("jump_back's last_op sentinel has no time bound (intentional, see above)", function()
  it('still fires after a long idle gap with no intervening key', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    local result = patterns.feed(s, 'g', 1, nil, 60000) -- 60s later, no other key
    assert.equals('jump_back', result.pattern)
  end)
end)
