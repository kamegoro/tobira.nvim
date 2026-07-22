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
  { key = 'x', threshold = 3, pattern = 'x_repeat',     cmd = '{n}x'  },
  { key = 'u', threshold = 3, pattern = 'u_repeat',     cmd = '<C-r>' },
  { key = 'j', threshold = 5, pattern = 'j_repeat',     cmd = '{n}j'  },
  { key = 'k', threshold = 5, pattern = 'k_repeat',     cmd = '{n}k'  },
  { key = 'n', threshold = 4, pattern = 'n_repeat',     cmd = 'cgn'   },
  { key = 'w', threshold = 5, pattern = 'w_repeat',     cmd = 'W'     },
  { key = 'b', threshold = 5, pattern = 'b_repeat',     cmd = 'B'     },
  { key = 'P', threshold = 3, pattern = 'P_repeat',     cmd = '{n}P'  },
  { key = '~', threshold = 3, pattern = 'tilde_repeat', cmd = '{n}~'  },
  { key = '.', threshold = 3, pattern = 'dot_repeat',   cmd = '{n}.'  },
  { key = 'J', threshold = 3, pattern = 'J_repeat',     cmd = '{n}J'  },
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
    for _ = 1, 4 do patterns.feed(s, 'j', 1) end
    local at5 = patterns.feed(s, 'j', 1)
    assert.is_not_nil(at5)
    assert.equals('j_repeat', at5.pattern)
    for _ = 1, 4 do patterns.feed(s, 'j', 1) end
    local at10 = patterns.feed(s, 'j', 1)
    assert.is_not_nil(at10)
    assert.equals('j_many', at10.pattern)
    assert.equals('}', at10.cmd)
  end)

  it('does not fire j_many at 9 presses', function()
    local s = seq()
    for _ = 1, 9 do patterns.feed(s, 'j', 1) end
    -- press 9: nothing fires (j_repeat already fired at 5)
    -- just verify j_many hasn't fired (result may be nil, that's fine)
    -- re-feed 9th to capture return value
    local s2 = seq()
    for _ = 1, 8 do patterns.feed(s2, 'j', 1) end
    local result = patterns.feed(s2, 'j', 1)
    if result then
      assert.is_not_equal('j_many', result.pattern)
    end
  end)
end)

describe('when k is pressed 10 times in a row', function()
  it('fires k_repeat at 5 and then k_many at 10 suggesting {', function()
    local s = seq()
    for _ = 1, 4 do patterns.feed(s, 'k', 1) end
    local at5 = patterns.feed(s, 'k', 1)
    assert.is_not_nil(at5)
    assert.equals('k_repeat', at5.pattern)
    for _ = 1, 4 do patterns.feed(s, 'k', 1) end
    local at10 = patterns.feed(s, 'k', 1)
    assert.is_not_nil(at10)
    assert.equals('k_many', at10.pattern)
    assert.equals('{', at10.cmd)
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
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    -- 2nd dd
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    -- 3rd dd
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_not_nil(result)
    assert.equals('dd_run', result.pattern)
    assert.equals('{n}dd', result.cmd)
  end)

  it('does not fire after only 2 consecutive dd', function()
    local s = seq()
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by a non-delete key', function()
    local s = seq()
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    patterns.feed(s, 'j', 1)  -- interrupt
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when dd is followed by p (dd→p pattern)', function()
    local s = seq()
    -- dd → p: swap lines, not a deletion streak
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    patterns.feed(s, 'p', 1)
    -- Now two more dd: not enough for dd_run
    patterns.feed(s, 'd', 1) ; patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'd', 1)
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
    patterns.feed(s, 'x', 1)  -- x_repeat fires here
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
    patterns.feed(s, 'r', 1) ; patterns.feed(s, 'a', 1)  -- 1st replacement
    patterns.feed(s, 'l', 1)                               -- navigate
    patterns.feed(s, 'r', 1) ; patterns.feed(s, 'b', 1)  -- 2nd replacement
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'r', 1)                               -- 3rd r
    local result = patterns.feed(s, 'c', 1)               -- replacement char → fires
    assert.is_not_nil(result)
    assert.equals('r_run', result.pattern)
    assert.equals('R', result.cmd)
  end)

  it('does not fire after only 2 replacements', function()
    local s = seq()
    patterns.feed(s, 'r', 1) ; patterns.feed(s, 'a', 1)
    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'r', 1)
    local result = patterns.feed(s, 'b', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when a non-navigation key appears between replacements', function()
    local s = seq()
    patterns.feed(s, 'r', 1) ; patterns.feed(s, 'a', 1)  -- streak=1
    patterns.feed(s, 'r', 1) ; patterns.feed(s, 'b', 1)  -- streak=2
    patterns.feed(s, 'j', 1)  -- j resets streak to 0
    -- Only 2 more replacements after the reset: not enough to fire
    patterns.feed(s, 'r', 1) ; patterns.feed(s, 'c', 1)  -- streak=1
    patterns.feed(s, 'r', 1)
    local result = patterns.feed(s, 'd', 1)               -- streak=2, still below threshold
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
    patterns.feed(s, 'j', 1)  -- visual line-select, not a text object
    local result = patterns.feed(s, 'c', 1)
    assert.is_nil(result)
  end)

  it('cancels when a non-operator key follows v i w', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)  -- visual_obj is now set
    patterns.feed(s, 'j', 1)  -- not c/d/y → cancel
    local result = patterns.feed(s, 'c', 1)
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
    patterns.feed(s, '$', 1)  -- fires d_dollar, clears last_op
    local result = patterns.feed(s, 'a', 1)
    if result then
      assert.is_not_equal('dollar_then_append', result.pattern)
    end
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
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_not_nil(result)
    assert.equals('indent_run', result.pattern)
    assert.equals('{n}>>', result.cmd)
  end)

  it('does not fire after only 2 consecutive >>', function()
    local s = seq()
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by a non-indent key', function()
    local s = seq()
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, 'j', 1)
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_nil(result)
  end)

  it('resets the streak when > is followed by a non-> motion (e.g. >j)', function()
    local s = seq()
    -- Build up a streak of 2
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    -- >j: operator > but motion j, not >>  → resets streak
    patterns.feed(s, '>', 1) ; patterns.feed(s, 'j', 1)
    -- Two more >>: only 2, not enough for threshold
    patterns.feed(s, '>', 1) ; patterns.feed(s, '>', 1)
    patterns.feed(s, '>', 1)
    local result = patterns.feed(s, '>', 1)
    assert.is_nil(result)
  end)
end)

-- ── << × 3: suggest {n}<< ────────────────────────────────────────────────────

describe('when the user dedents the current line 3 or more times in a row', function()
  it('fires dedent_run suggesting {n}<<', function()
    local s = seq()
    patterns.feed(s, '<', 1) ; patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1) ; patterns.feed(s, '<', 1)
    patterns.feed(s, '<', 1)
    local result = patterns.feed(s, '<', 1)
    assert.is_not_nil(result)
    assert.equals('dedent_run', result.pattern)
    assert.equals('{n}<<', result.cmd)
  end)

  it('does not fire after only 2 consecutive <<', function()
    local s = seq()
    patterns.feed(s, '<', 1) ; patterns.feed(s, '<', 1)
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
  it("swallows the mark name so it cannot trigger k_then_o", function()
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
  -- Then a second 'c' matches key==op and sets last_op='dd', so 'p' fires
  -- dd_then_p. This is a false positive that pending_bracket must prevent.
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

-- ── key_consumed flag ─────────────────────────────────────────────────────────

describe('seq.key_consumed', function()
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
