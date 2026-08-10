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
  -- n_repeat is intent-neutral (like j_repeat/k_repeat): a bare n-streak is
  -- equally likely to be browsing as editing, so it suggests the count-prefix
  -- jump {n}n, not cgn — see docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
  { key = 'n', threshold = 4, pattern = 'n_repeat', cmd = '{n}n' },
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

-- ── ~ higher thresholds: text-object-scoped case toggle ──────────────────────
-- see docs/adr/0101-tilde-repeat-text-object-refinement.md

describe('when ~ is repeated across consecutive character positions', function()
  it('still fires tilde_repeat suggesting {n}~ at 3 (existing behavior preserved)', function()
    local s = seq()
    patterns.feed(s, '~', 1)
    patterns.feed(s, '~', 1)
    local result = patterns.feed(s, '~', 1)
    assert.is_not_nil(result)
    assert.equals('tilde_repeat', result.pattern)
    assert.equals('{n}~', result.cmd)
  end)

  it('does not refire between 3 and 6 presses', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, '~', 1)
    end
    local result = patterns.feed(s, '~', 1) -- 5th press
    assert.is_nil(result)
  end)

  it('fires tilde_word_repeat suggesting g~iw at 6, superseding {n}~', function()
    local s = seq()
    for _ = 1, 5 do
      patterns.feed(s, '~', 1)
    end
    local result = patterns.feed(s, '~', 1)
    assert.is_not_nil(result)
    assert.equals('tilde_word_repeat', result.pattern)
    assert.equals('g~iw', result.cmd)
  end)

  it('fires tilde_line_repeat suggesting g~$ at 12', function()
    local s = seq()
    for _ = 1, 11 do
      patterns.feed(s, '~', 1)
    end
    local result = patterns.feed(s, '~', 1)
    assert.is_not_nil(result)
    assert.equals('tilde_line_repeat', result.pattern)
    assert.equals('g~$', result.cmd)
  end)

  it('resets the streak when interrupted, so the word threshold needs a fresh run', function()
    local s = seq()
    for _ = 1, 3 do
      patterns.feed(s, '~', 1)
    end
    patterns.feed(s, 'l', 1) -- interrupt
    for _ = 1, 4 do
      patterns.feed(s, '~', 1)
    end
    local result = patterns.feed(s, '~', 1) -- only 5 since the interrupt
    assert.is_nil(result)
  end)
end)

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

-- ── j / k in diff mode: prefer ]c / [c hunk navigation over }/{ ──────────────
-- feed()'s 4th argument is the caller-supplied "is &diff set on this window?"
-- flag (patterns.lua stays vim.*-free, so it never reads vim.wo.diff itself —
-- logger.lua does and passes the boolean in). These tests inject it directly.

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

-- ── diff hunk jump → insert: suggest do / dp ──────────────────────────────────
-- see docs/adr/0099-diff-obtain-put-after-hunk-jump.md

describe('when the user edits immediately after jumping to a diff hunk', function()
  it('fires diff_jump_then_insert_next suggesting do after ]c then entering insert', function()
    local s = seq()
    patterns.feed(s, ']', 1, true)
    patterns.feed(s, 'c', 1, true)
    local result = patterns.feed(s, 'i', 1, true)
    assert.is_not_nil(result)
    assert.equals('diff_jump_then_insert_next', result.pattern)
    assert.equals('do', result.cmd)
  end)

  it('fires diff_jump_then_insert_prev suggesting dp after [c then entering insert', function()
    local s = seq()
    patterns.feed(s, '[', 1, true)
    patterns.feed(s, 'c', 1, true)
    local result = patterns.feed(s, 'a', 1, true)
    assert.is_not_nil(result)
    assert.equals('diff_jump_then_insert_prev', result.pattern)
    assert.equals('dp', result.cmd)
  end)

  it('does not fire when &diff is not set', function()
    local s = seq()
    patterns.feed(s, ']', 1, false)
    patterns.feed(s, 'c', 1, false)
    local result = patterns.feed(s, 'i', 1, false)
    assert.is_nil(result)
  end)

  it('does not fire when another key interrupts between the hunk jump and insert', function()
    local s = seq()
    patterns.feed(s, ']', 1, true)
    patterns.feed(s, 'c', 1, true)
    patterns.feed(s, 'l', 1, true) -- interrupt
    local result = patterns.feed(s, 'i', 1, true)
    assert.is_nil(result)
  end)

  it('does not fire for a bracket pair other than ]c', function()
    local s = seq()
    patterns.feed(s, ']', 1, true)
    patterns.feed(s, ']', 1, true) -- ]] not ]c
    local result = patterns.feed(s, 'i', 1, true)
    assert.is_nil(result)
  end)

  it('still consumes the bracket-target key as key_consumed, like any other bracket pair', function()
    local s = seq()
    patterns.feed(s, ']', 1, true)
    patterns.feed(s, 'c', 1, true)
    assert.is_true(s.key_consumed)
  end)
end)

-- ── n-streak → change the match: suggest cgn ──────────────────────────────────
-- see docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md

describe('when the user changes the word under the cursor shortly after an n-streak', function()
  it('does not fire (or show any suggestion) merely from arming the watch at 2 n presses', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    local result = patterns.feed(s, 'n', 1)
    assert.is_nil(result)
  end)

  it('fires n_then_change suggesting cgn for cw after n n', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_not_nil(result)
    assert.equals('n_then_change', result.pattern)
    assert.equals('cgn', result.cmd)
  end)

  it('fires n_then_change for a text-object change (ciw) too', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_not_nil(result)
    assert.equals('n_then_change', result.pattern)
    assert.equals('cgn', result.cmd)
  end)

  it('fires n_then_change for a count-prefixed change (c3w) too', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, '3', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_not_nil(result)
    assert.equals('n_then_change', result.pattern)
    assert.equals('cgn', result.cmd)
  end)

  it('does not arm the watch after only a single n press', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
  end)

  it('does not fire for a delete (dw) — only a change operator counts as evidence', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'd', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
  end)

  it('does not fire when an unrelated motion breaks the streak before the change', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'j', 1) -- unrelated motion: expires the watch
    patterns.feed(s, 'c', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
  end)

  it('does not fire a second time without a fresh n-streak', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'c', 1)
    local first = patterns.feed(s, 'w', 1)
    assert.equals('n_then_change', first.pattern)

    patterns.feed(s, 'c', 1)
    local second = patterns.feed(s, 'w', 1)
    assert.is_nil(second)
  end)

  it('n_repeat at 4 presses still fires independently, suggesting the count-prefix, not cgn', function()
    local s = seq()
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    patterns.feed(s, 'n', 1)
    local result = patterns.feed(s, 'n', 1)
    assert.is_not_nil(result)
    assert.equals('n_repeat', result.pattern)
    assert.equals('{n}n', result.cmd)
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
-- Regression tests: patterns.lua's operator-pending branch used to hardcode
-- seq.last_op = 'dd' regardless of the actual operator, so cc was silently
-- recorded (and streak-tracked) as dd.

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

-- ── yiw (yank + text-object) routes into pending_text_obj like d/c ───────────
-- Before the fix, the y-operator branch in pending_op only special-cased
-- yy/y$; any other following key (including the i/a text-object prefixes)
-- fell through as an ordinary standalone keystroke instead of routing into
-- pending_text_obj the way d/c already do. See
-- docs/adr/0106-text-object-variant-own-usage-tracking.md.

describe('when the user yanks with a text object (yiw) inside a pending y operator', function()
  it('routes i/w into pending_text_obj the same way d/c do', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'i', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
    assert.equals('yw', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('also routes ya( (outer paren text object) the same way', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'a', 1)
    local result = patterns.feed(s, '(', 1)
    assert.is_nil(result)
    assert.equals('yw', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('does not leak the w of yiw into the bare-motion run streak used by w_repeat (regression #253)', function()
    -- Before the fix, since pending_op/pending_text_obj were both cleared
    -- without being routed, the final w of yiw fell all the way through to
    -- the bottom of inner_feed and got counted by track_run() exactly like
    -- a genuine bare w press — corrupting seq.run. d/c-based diw/ciw never
    -- reach that code path (pending_text_obj returns before track_run), so
    -- this must match their behavior: run must stay untouched.
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    assert.is_nil(s.run.key)
    assert.equals(0, s.run.count)
  end)

  it('still fires yy for a genuine yy (unaffected by the i/a routing change)', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'y', 1)
    assert.equals('yy', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('still fires y_dollar suggesting Y for y$ (unaffected by the i/a routing change)', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    local result = patterns.feed(s, '$', 1)
    assert.is_not_nil(result)
    assert.equals('y_dollar', result.pattern)
    assert.equals('Y', result.cmd)
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

-- ── p / P → rightward motion (cursor skips past paste) → gp / gP ─────────────
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

-- ── gp/gP still arms after yy_then_p / dd_then_p fires on the same p ─────────
-- Before the fix, yy_then_p/dd_then_p both returned immediately on p, so the
-- pending_paste arming code that p_then_rightward depends on was never
-- reached for that same paste.

describe('when the user duplicates a line (yyp) then moves the cursor right several times', function()
  it('fires yy_then_p on the p, and still arms pending_paste for a later p_then_rightward', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'y', 1)
    local first = patterns.feed(s, 'p', 1)
    assert.is_not_nil(first)
    assert.equals('yy_then_p', first.pattern)

    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_not_nil(result)
    assert.equals('p_then_rightward', result.pattern)
    assert.equals('gp', result.cmd)
  end)
end)

describe('when the user swaps lines (ddp) then moves the cursor right several times', function()
  it('fires dd_then_p on the p, and still arms pending_paste for a later p_then_rightward', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'd', 1)
    local first = patterns.feed(s, 'p', 1)
    assert.is_not_nil(first)
    assert.equals('dd_then_p', first.pattern)

    patterns.feed(s, 'l', 1)
    patterns.feed(s, 'l', 1)
    local result = patterns.feed(s, 'l', 1)
    assert.is_not_nil(result)
    assert.equals('p_then_rightward', result.pattern)
    assert.equals('gp', result.cmd)
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

-- ── <C-a> → j/k → <C-a> × 3: suggest g<C-a> ───────────────────────────────────
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

-- ── v <Esc> v <Esc> v → gv (reselect last visual selection) ──────────────────

describe('when the user enters and immediately leaves visual mode 3 times in a row', function()
  it('fires v_repeat suggesting gv on the 3rd clean <Esc>, not the 3rd v', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- <Esc>, 1st clean tap
    patterns.feed(s, 'v', 1)
    patterns.feed(s, '\27', 1) -- <Esc>, 2nd clean tap
    local third_v = patterns.feed(s, 'v', 1)
    -- The 3rd v must NOT fire yet — see
    -- docs/adr/0021-visual-repeat-gv-detection.md
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

-- ── ci" / ci' × 3 (direct, non-visual) → suggest ya" / ya' ───────────────────
-- see docs/adr/0020-ci-quote-streak-and-tolerance.md

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

  it('resets the streak when an unrelated edit interrupts the repeats', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'x', 1) -- unrelated edit: interrupts (not a tolerated nav key, see below)
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

-- ── ci_dquote_streak / ci_squote_streak tolerate plain navigation between ──
-- completions — see docs/adr/0020-ci-quote-streak-and-tolerance.md

describe('when plain single-key navigation connects ci" completions on different strings', function()
  it('fires ci_dquote_repeat suggesting ya" for the realistic ci"..<Esc> w w ci"..<Esc> w w ci" flow', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1) -- 1st, on string A
    patterns.feed(s, 'w', 1)
    patterns.feed(s, 'w', 1)
    feed(s, { 'c', 'i', '"' }, 1) -- 2nd, on string B (reached via w w)
    patterns.feed(s, 'w', 1)
    patterns.feed(s, 'w', 1)
    local result = feed(s, { 'c', 'i', '"' }, 1) -- 3rd, on string C (reached via w w) → fires
    assert.is_not_nil(result)
    assert.equals('ci_dquote_repeat', result.pattern)
    assert.equals('ya"', result.cmd)
  end)

  it('tolerates b/e/h/l/0/^/$/j/k the same way w is tolerated, without breaking the streak', function()
    local s = seq()
    local nav_keys = { 'b', 'e', 'h', 'l', '0', '^', '$', 'j', 'k' }
    feed(s, { 'c', 'i', '"' }, 1)
    for _, k in ipairs(nav_keys) do
      patterns.feed(s, k, 1)
    end
    feed(s, { 'c', 'i', '"' }, 1)
    for _, k in ipairs(nav_keys) do
      patterns.feed(s, k, 1)
    end
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_not_nil(result)
    assert.equals('ci_dquote_repeat', result.pattern)
    assert.equals('ya"', result.cmd)
  end)

  it('still resets the streak when an unrelated edit interrupts, even though w is tolerated', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'w', 1)
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'x', 1) -- unrelated edit operation: still breaks the streak
    feed(s, { 'c', 'i', '"' }, 1)
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_nil(result)
  end)

  it('still lets f"-navigation connect completions the same as before this fix', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'f', 1)
    patterns.feed(s, '"', 1)
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'f', 1)
    patterns.feed(s, '"', 1)
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_not_nil(result)
    assert.equals('ci_dquote_repeat', result.pattern)
    assert.equals('ya"', result.cmd)
  end)

  it('still fires for the same-quote-pair re-edit case (no navigation at all) as before this fix', function()
    local s = seq()
    feed(s, { 'c', 'i', '"' }, 1)
    feed(s, { 'c', 'i', '"' }, 1)
    local result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_not_nil(result)
    assert.equals('ci_dquote_repeat', result.pattern)
    assert.equals('ya"', result.cmd)
  end)
end)

describe("when plain single-key navigation connects ci' completions on different strings", function()
  it("fires ci_squote_repeat suggesting ya' with w navigation between three different strings", function()
    local s = seq()
    feed(s, { 'c', 'i', "'" }, 1)
    patterns.feed(s, 'w', 1)
    feed(s, { 'c', 'i', "'" }, 1)
    patterns.feed(s, 'w', 1)
    local result = feed(s, { 'c', 'i', "'" }, 1)
    assert.is_not_nil(result)
    assert.equals('ci_squote_repeat', result.pattern)
    assert.equals("ya'", result.cmd)
  end)

  it('keeps the dquote and squote streaks independently trackable across navigation', function()
    local s = seq()
    -- Build a squote streak to completion first, tolerating w navigation.
    feed(s, { 'c', 'i', "'" }, 1)
    patterns.feed(s, 'w', 1)
    feed(s, { 'c', 'i', "'" }, 1)
    patterns.feed(s, 'w', 1)
    local squote_result = feed(s, { 'c', 'i', "'" }, 1)
    assert.is_not_nil(squote_result)
    assert.equals('ci_squote_repeat', squote_result.pattern)

    -- Then build a fresh dquote streak from scratch, also tolerating w
    -- navigation — confirms the squote streak firing/resetting above left
    -- the dquote counter untouched.
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'w', 1)
    feed(s, { 'c', 'i', '"' }, 1)
    patterns.feed(s, 'w', 1)
    local dquote_result = feed(s, { 'c', 'i', '"' }, 1)
    assert.is_not_nil(dquote_result)
    assert.equals('ci_dquote_repeat', dquote_result.pattern)
    assert.equals('ya"', dquote_result.cmd)
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

-- ── text-object variants get their own tracked usage, not just the shared ───
-- ── op..'w' bucket ───────────────────────────────────────────────────────────
-- Before the fix, pending_text_obj always set last_op = op .. 'w', collapsing
-- every ciw/ci"/ci'/cib/ciB/cit/cip/diw press into the shared cw/dw counter —
-- each variant's OWN usage bucket never incremented, so commands.lua's
-- requires-gated chain for these entries could never become eligible. The fix
-- additionally sets seq.last_op_variant to the exact variant key (e.g. 'ci"')
-- so logger.lua can increment it alongside the shared bucket, without
-- replacing it. See docs/adr/0106-text-object-variant-own-usage-tracking.md.

describe('when the user completes a text-object variant directly (ciw, ci", cib, ...)', function()
  local variant_cases = {
    { op = 'c', inner = 'i', char = 'w', last_op = 'cw', variant = 'ciw' },
    { op = 'c', inner = 'i', char = '"', last_op = 'cw', variant = 'ci"' },
    { op = 'c', inner = 'i', char = "'", last_op = 'cw', variant = "ci'" },
    { op = 'c', inner = 'i', char = 'b', last_op = 'cw', variant = 'cib' },
    { op = 'c', inner = 'i', char = 'B', last_op = 'cw', variant = 'ciB' },
    { op = 'c', inner = 'i', char = 't', last_op = 'cw', variant = 'cit' },
    { op = 'c', inner = 'i', char = 'p', last_op = 'cw', variant = 'cip' },
    { op = 'd', inner = 'i', char = 'w', last_op = 'dw', variant = 'diw' },
  }

  for _, tc in ipairs(variant_cases) do
    it(
      'tracks ' .. tc.variant .. ' under its own last_op_variant, alongside the shared ' .. tc.last_op .. ' bucket',
      function()
        local s = seq()
        patterns.feed(s, tc.op, 1)
        patterns.feed(s, tc.inner, 1)
        patterns.feed(s, tc.char, 1)
        assert.equals(tc.last_op, s.last_op)
        assert.is_true(s.op_completed)
        assert.equals(tc.variant, s.last_op_variant)
      end
    )
  end

  it('does not set last_op_variant for a text-object char with no dedicated variant (e.g. iW)', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'W', 1)
    assert.equals('cw', s.last_op) -- shared bucket still tracked as before
    assert.is_nil(s.last_op_variant)
  end)

  it('resets last_op_variant on the very next call so it is never double-counted later', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 'w', 1)
    assert.equals('ciw', s.last_op_variant)
    patterns.feed(s, 'j', 1) -- an unrelated later keystroke
    assert.is_nil(s.last_op_variant)
  end)

  it('does not confuse ciw with diw — each variant is keyed by its own operator', function()
    local s_c = seq()
    patterns.feed(s_c, 'c', 1)
    patterns.feed(s_c, 'i', 1)
    patterns.feed(s_c, 'w', 1)
    assert.equals('ciw', s_c.last_op_variant)

    local s_d = seq()
    patterns.feed(s_d, 'd', 1)
    patterns.feed(s_d, 'i', 1)
    patterns.feed(s_d, 'w', 1)
    assert.equals('diw', s_d.last_op_variant)
  end)
end)

-- ── pending_text_obj's completing key must not double-count as a bare ────────
-- ── keystroke too ─────────────────────────────────────────────────────────────
-- yiw's completing key left key_consumed unset, unlike
-- pending_register/pending_mark/pending_bracket, so usage['w'].count kept
-- inflating on every diw/ciw/yiw completion; see
-- docs/adr/0026-state-machine-bookkeeping-invariants.md.
describe('when a text object completes (independent QA: key_consumed must be set)', function()
  it('sets key_consumed on the completing key of ciw, matching pending_register/mark/bracket', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
    assert.is_true(s.key_consumed)
  end)

  it('sets key_consumed on the completing key of diw', function()
    local s = seq()
    patterns.feed(s, 'd', 1)
    patterns.feed(s, 'i', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
    assert.is_true(s.key_consumed)
  end)

  it('sets key_consumed on the completing key of yiw (#253 regression)', function()
    local s = seq()
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'i', 1)
    local result = patterns.feed(s, 'w', 1)
    assert.is_nil(result)
    assert.is_true(s.key_consumed)
  end)

  it('still sets key_consumed on the ci-dquote direct-path streak-firing call too', function()
    local s = seq()
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, '"', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, '"', 1)
    patterns.feed(s, 'c', 1)
    patterns.feed(s, 'i', 1)
    local result = patterns.feed(s, '"', 1) -- 3rd direct completion — fires ci_dquote_repeat
    assert.equals('ci_dquote_repeat', result.pattern)
    assert.is_true(s.key_consumed)
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

-- ── = auto-indent operator tracking ────────────────────────────────────────────
-- Before the fix, '=' was never one of pending_op's trigger characters, so
-- the raw == keystroke was never counted and it could never be marked
-- mastered regardless of actual usage. Nothing else uses '==' as a `requires`
-- target, so this is display-accuracy only — no cascading suggestion chain
-- depends on it.

describe('when the user auto-indents the current line with ==', function()
  it('records last_op = == as a completed compound', function()
    local s = seq()
    patterns.feed(s, '=', 1)
    local result = patterns.feed(s, '=', 1)
    assert.is_nil(result)
    assert.equals('==', s.last_op)
    assert.is_true(s.op_completed)
  end)

  it('does not set last_op for = followed by an unrelated key', function()
    local s = seq()
    patterns.feed(s, '=', 1)
    local result = patterns.feed(s, 'G', 1)
    assert.is_nil(result)
    assert.equals('=w', s.last_op)
    assert.is_true(s.op_completed)
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

-- ── "+y system-clipboard yank compound ─────────────────────────────────────────
-- see docs/adr/0023-register-mark-bracket-prefix-consumers.md

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
    -- Regression test: the trailing y of "+yy used to swallow the next
    -- keystroke, so j_repeat (count == 5) needed a 6th j — see
    -- docs/adr/0023-register-mark-bracket-prefix-consumers.md
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

-- ── register/mark names that collide with f/F/t/T ─────────────────────────────
-- Before the fix, the f/F/t/T search-start handler ran BEFORE
-- pending_register/pending_mark consumed their expected next character, so
-- "tyy / mt / `t (register or mark named f/F/t/T) corrupted seq.pending_f
-- instead of being consumed as the register/mark name — silently eating the
-- next real keystroke. See docs/adr/0026-state-machine-bookkeeping-invariants.md
-- (track_run() must run unconditionally) for the invariant this violated.

describe('when a register name happens to be f, F, t, or T', function()
  for _, name in ipairs({ 'f', 'F', 't', 'T' }) do
    it('consumes "' .. name .. ' as the register name instead of starting an f/t search', function()
      local s = seq()
      patterns.feed(s, '"', 1)
      local result = patterns.feed(s, name, 1)
      assert.is_nil(result)
      assert.is_nil(s.pending_f)
      assert.is_true(s.key_consumed)
    end)
  end

  it('does not undercount a j-streak when preceded by "tyy (regression #257)', function()
    local s = seq()
    patterns.feed(s, '"', 1)
    patterns.feed(s, 't', 1)
    patterns.feed(s, 'y', 1)
    patterns.feed(s, 'y', 1)
    for _ = 1, 4 do
      local mid = patterns.feed(s, 'j', 1)
      assert.is_nil(mid)
    end
    local result = patterns.feed(s, 'j', 1)
    assert.is_not_nil(result)
    assert.equals('j_repeat', result.pattern)
    assert.equals('{n}j', result.cmd)
  end)
end)

describe('when a mark name happens to be f, F, t, or T', function()
  for _, name in ipairs({ 'f', 'F', 't', 'T' }) do
    it('consumes m' .. name .. ' as the mark name instead of starting an f/t search', function()
      local s = seq()
      patterns.feed(s, 'm', 1)
      local result = patterns.feed(s, name, 1)
      assert.is_nil(result)
      assert.is_nil(s.pending_f)
      assert.is_true(s.key_consumed)
    end)

    it('consumes `' .. name .. ' as the mark target instead of starting an f/t search', function()
      local s = seq()
      patterns.feed(s, '`', 1)
      local result = patterns.feed(s, name, 1)
      assert.is_nil(result)
      assert.is_nil(s.pending_f)
      assert.is_true(s.key_consumed)
    end)
  end

  it('does not undercount a j-streak when preceded by mt (regression #257)', function()
    local s = seq()
    patterns.feed(s, 'm', 1)
    patterns.feed(s, 't', 1)
    for _ = 1, 4 do
      local mid = patterns.feed(s, 'j', 1)
      assert.is_nil(mid)
    end
    local result = patterns.feed(s, 'j', 1)
    assert.is_not_nil(result)
    assert.equals('j_repeat', result.pattern)
  end)
end)

-- ── r-replacement character that happens to be f/F/t/T ────────────────────────
-- pending_r is the same shape of "single-char prefix that consumes exactly
-- one following character" as pending_register/pending_mark. Before this fix,
-- r/f/t/T's f/F/t/T search-start handler ran before pending_r consumed its
-- replacement character, silently swallowing two real keystrokes instead of
-- one. See docs/adr/0026-state-machine-bookkeeping-invariants.md.

describe('when the replacement character for r happens to be f, F, t, or T', function()
  for _, char in ipairs({ 'f', 'F', 't', 'T' }) do
    it('consumes r' .. char .. ' as the replacement instead of starting an f/t search', function()
      local s = seq()
      patterns.feed(s, 'r', 1)
      local result = patterns.feed(s, char, 1)
      assert.is_nil(result)
      assert.is_nil(s.pending_f)
      assert.is_false(s.pending_r)
    end)
  end

  it('does not undercount a j-streak when preceded by rf (regression)', function()
    local s = seq()
    patterns.feed(s, 'r', 1)
    patterns.feed(s, 'f', 1)
    for _ = 1, 4 do
      local mid = patterns.feed(s, 'j', 1)
      assert.is_nil(mid)
    end
    local result = patterns.feed(s, 'j', 1)
    assert.is_not_nil(result)
    assert.equals('j_repeat', result.pattern)
    assert.equals('{n}j', result.cmd)
  end)
end)

-- ── visual inner/around tag text object collides with f/F/t/T ────────────────
-- v/visual_inner's text-object-character consumer is the same shape of
-- prefix-continuation state as pending_text_obj, but the visual (v i {obj})
-- path was left out of that fix: 'vit'/'vat' had their 't' hijacked by the
-- f/F/t/T search-start handler instead of completing visual_obj.

describe('when the visual text-object character happens to be t (tag object)', function()
  it('fires visual_textobj cit for v i t c', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 't', 1)
    local result = patterns.feed(s, 'c', 1)
    assert.is_not_nil(result)
    assert.equals('visual_textobj', result.pattern)
    assert.equals('cit', result.cmd)
  end)

  it('fires visual_textobj dit for v i t d', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'i', 1)
    patterns.feed(s, 't', 1)
    local result = patterns.feed(s, 'd', 1)
    assert.is_not_nil(result)
    assert.equals('dit', result.cmd)
  end)

  it('fires visual_textobj yat for v a t y', function()
    local s = seq()
    patterns.feed(s, 'v', 1)
    patterns.feed(s, 'a', 1)
    patterns.feed(s, 't', 1)
    local result = patterns.feed(s, 'y', 1)
    assert.is_not_nil(result)
    assert.equals('yat', result.cmd)
  end)
end)

-- ── [ / ] navigation prefix ───────────────────────────────────────────────────

describe('when the user uses [ or ] navigation', function()
  -- Without a pending_bracket guard, ]c would incorrectly set pending_op='c'.
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
    -- change-list nav / paste-without-jump / case-operator chains
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

-- ── g-compounds must reset consecutive-run tracking for their 2nd key ────────
-- Bug: adopting e_repeat's own suggestion (typing ge) did not reset the
-- e-streak, re-firing e_repeat immediately — see
-- docs/adr/0019-jumplist-changelist-underuse-detection.md
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

  -- e/j/k/n/x/p/u are all reachable as a pending_g target's 2nd key, so they
  -- all share this same exposure (threshold matches run_cases above).
  local reset_cases = {
    { key = 'e', threshold = 5, pattern = 'e_repeat', cmd = 'ge' },
    { key = 'j', threshold = 5, pattern = 'j_repeat', cmd = '{n}j' },
    { key = 'k', threshold = 5, pattern = 'k_repeat', cmd = '{n}k' },
    { key = 'n', threshold = 4, pattern = 'n_repeat', cmd = '{n}n' },
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
    -- zf: z_targets omitted 'f' (unlike sibling zd), so zf's own
    -- raw keystroke was never counted and it could never be marked mastered
    -- regardless of actual usage.
    { key = 'f', last_op = 'zf' },
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

-- ── <C-w> / pending_ctrl_w two-key compound tracking ───────────────────────────
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
-- see docs/adr/0022-gq-operator-pending-and-post-format-jumpback.md

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

-- ── <C-w>q / <C-w>c repeated → <C-w>o ───────────────────────────────────────────
-- see docs/adr/0024-ctrl-w-window-compound-and-close-streak.md

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

-- ── <C-w>+ / <C-w>- / <C-w>< / <C-w>> repeated → <C-w>= ────────────────────────
-- see docs/adr/0096-ctrl-w-resize-streak.md

describe('when the user resizes windows one keystroke at a time', function()
  local ctrl_w = '\23'

  local function press(s, key)
    patterns.feed(s, ctrl_w, 1)
    return patterns.feed(s, key, 1)
  end

  it('fires ctrl_w_resize_repeat suggesting <C-w>= after two <C-w>+ in a row', function()
    local s = seq()
    press(s, '+')
    local result = press(s, '+')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_resize_repeat', result.pattern)
    assert.equals('<C-w>=', result.cmd)
  end)

  it('fires after two <C-w>- in a row', function()
    local s = seq()
    press(s, '-')
    local result = press(s, '-')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_resize_repeat', result.pattern)
    assert.equals('<C-w>=', result.cmd)
  end)

  it('fires when <C-w>+ is followed by <C-w>< (mixed resize actions count together)', function()
    local s = seq()
    press(s, '+')
    local result = press(s, '<')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_resize_repeat', result.pattern)
  end)

  it('fires when <C-w>> is followed by <C-w>- (mixed resize actions count together)', function()
    local s = seq()
    press(s, '>')
    local result = press(s, '-')
    assert.is_not_nil(result)
    assert.equals('ctrl_w_resize_repeat', result.pattern)
  end)

  it('does not fire after only a single <C-w>+', function()
    local s = seq()
    local result = press(s, '+')
    assert.is_nil(result)
  end)

  it('resets the streak after firing, so a 3rd resize does not immediately refire', function()
    local s = seq()
    press(s, '+')
    press(s, '+') -- fires here
    local result = press(s, '+')
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by an unrelated window command (<C-w>s)', function()
    local s = seq()
    press(s, '+')
    press(s, 's') -- interrupt: not a resize action
    local result = press(s, '+')
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by an unrelated normal-mode key', function()
    local s = seq()
    press(s, '+')
    patterns.feed(s, 'j', 1) -- interrupt: unrelated key, no <C-w> prefix
    local result = press(s, '+')
    assert.is_nil(result)
  end)

  it('does not share state with ctrl_w_close_streak — a resize in between resets the close count', function()
    local s = seq()
    press(s, 'q') -- close streak = 1
    press(s, '+') -- resize streak = 1, resets close streak
    local result = press(s, 'q') -- close streak = 1 again, not 2
    assert.is_nil(result)
  end)

  it('does not share state with ctrl_w_close_streak — a close in between resets the resize count', function()
    local s = seq()
    press(s, '+') -- resize streak = 1
    press(s, 'q') -- close streak = 1, resets resize streak
    local result = press(s, '+') -- resize streak = 1 again, not 2
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

-- ── op_completed flag ────────────────────────────────────────────────────────
-- see docs/adr/0026-state-machine-bookkeeping-invariants.md

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

  -- pending_ctrl_w's dispatch table was added after op_completed already
  -- existed elsewhere in this file (pending_g / pending_z), so its last_op
  -- assignment needed the same flag added by hand during the merge — this
  -- guards against that path silently regressing to the undercounting bug.
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

  -- <C-w>c is in the pending_ctrl_w dispatch table; guard against the same
  -- undercounting bug reappearing on this entry.
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

-- ── jumplist underuse: G / gg / search → manual scroll back → <C-o> ──────────
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

-- ── zz cursor-centering streak: <C-e>/<C-y> repeated → zz ────────────────────
-- see docs/adr/0097-cursor-centering-streak.md

describe('when the user repeatedly scrolls with <C-e>/<C-y> to reposition the cursor line', function()
  local ctrl_e = '\5'
  local ctrl_y = '\25'

  it('fires cursor_center_repeat suggesting zz after 5 <C-e> presses with no preceding jump', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, ctrl_e, 1, nil, 0)
    end
    local result = patterns.feed(s, ctrl_e, 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('cursor_center_repeat', result.pattern)
    assert.equals('zz', result.cmd)
  end)

  it('fires after 5 <C-y> presses', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, ctrl_y, 1, nil, 0)
    end
    local result = patterns.feed(s, ctrl_y, 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('cursor_center_repeat', result.pattern)
    assert.equals('zz', result.cmd)
  end)

  it('fires for a mix of <C-e> and <C-y>', function()
    local s = seq()
    patterns.feed(s, ctrl_e, 1, nil, 0)
    patterns.feed(s, ctrl_y, 1, nil, 0)
    patterns.feed(s, ctrl_e, 1, nil, 0)
    patterns.feed(s, ctrl_y, 1, nil, 0)
    local result = patterns.feed(s, ctrl_e, 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('cursor_center_repeat', result.pattern)
  end)

  it('does not fire after only 4 presses', function()
    local s = seq()
    for _ = 1, 3 do
      patterns.feed(s, ctrl_e, 1, nil, 0)
    end
    local result = patterns.feed(s, ctrl_e, 1, nil, 0)
    assert.is_nil(result)
  end)

  it('resets the streak when interrupted by an unrelated key', function()
    local s = seq()
    patterns.feed(s, ctrl_e, 1, nil, 0)
    patterns.feed(s, ctrl_e, 1, nil, 0)
    patterns.feed(s, 'l', 1, nil, 0) -- interrupt
    patterns.feed(s, ctrl_e, 1, nil, 0)
    patterns.feed(s, ctrl_e, 1, nil, 0)
    local result = patterns.feed(s, ctrl_e, 1, nil, 0)
    assert.is_nil(result)
  end)

  it('does not fire manual_return for a plain 5x <C-e> streak with no preceding jump', function()
    local s = seq()
    for _ = 1, 4 do
      patterns.feed(s, ctrl_e, 1, nil, 0)
    end
    local result = patterns.feed(s, ctrl_e, 1, nil, 0)
    assert.is_not_equal('manual_return', result.pattern)
  end)

  it('fires manual_return instead of cursor_center_repeat when a significant jump precedes the streak', function()
    -- Both manual_return's jump_return_streak and cursor_center_repeat's
    -- zz_streak reach their threshold on this same 5th <C-e> — manual_return
    -- is the more specific, contextual suggestion and wins. See
    -- docs/adr/0097-cursor-centering-streak.md
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    for _ = 1, 4 do
      patterns.feed(s, ctrl_e, 1, nil, 0)
    end
    local result = patterns.feed(s, ctrl_e, 1, nil, 0)
    assert.is_not_nil(result)
    assert.equals('manual_return', result.pattern)
    assert.equals(0, s.zz_streak)
  end)

  it('does not increment zz_streak from the manual_return-relevant j/k keys, only <C-e>/<C-y>', function()
    local s = seq()
    for _ = 1, 10 do
      patterns.feed(s, 'k', 1, nil, 0)
    end
    assert.equals(0, s.zz_streak)
  end)
end)

-- ── changelist underuse: edit A, move, edit B, scroll back → g; ──────────────

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

-- ── arbitration when both preconditions are true at once ─────────────────────
-- Reported by live QA: 10G → x (edit) → 40G → x (edit) → k×5 back always
-- suggested <C-o>, never g; — see docs/adr/0019-jumplist-changelist-underuse-detection.md

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

-- ── named-mark opportunity: repeated returns to the same line → ma ───────────
-- see docs/adr/0100-named-mark-repeated-line-return.md
-- 'l' is used as the connecting/leaving motion below (not j/k/G/<C-e>/<C-y>)
-- so these tests never touch jump_return_streak/change_return_streak/
-- zz_streak, isolating them from the jumplist/changelist/zz patterns above.

describe('when the cursor returns to the same line 3 times with real edits elsewhere in between', function()
  local function leave_edit_return(s, away_line, anchor_line, edit_key)
    patterns.feed(s, 'l', away_line) -- leave the anchor
    patterns.feed(s, edit_key, away_line) -- genuine edit away from the anchor
    return patterns.feed(s, 'l', anchor_line) -- return to the anchor
  end

  it('fires named_mark_opportunity suggesting ma on the 3rd genuine return', function()
    local s = seq()
    patterns.feed(s, 'i', 10)
    patterns.feed(s, '\27', 10)
    leave_edit_return(s, 20, 10, 'i') -- return #1
    local second = leave_edit_return(s, 30, 10, 'x') -- return #2
    assert.is_nil(second)
    local third = leave_edit_return(s, 40, 10, 'x') -- return #3
    assert.is_not_nil(third)
    assert.equals('named_mark_opportunity', third.pattern)
    assert.equals('ma', third.cmd)
  end)

  it('does not fire after only 2 genuine returns', function()
    local s = seq()
    patterns.feed(s, 'i', 10)
    patterns.feed(s, '\27', 10)
    leave_edit_return(s, 20, 10, 'i')
    local result = leave_edit_return(s, 30, 10, 'x')
    assert.is_nil(result)
  end)

  it(
    're-anchors to the real reference line instead of getting stuck on the '
      .. 'line the cursor happened to start the session on (live-QA regression)',
    function()
      -- Live QA caught this: a session's very first navigation "leaves" line
      -- 1 (wherever the cursor happened to be, e.g. right after opening the
      -- file), which used to permanently lock mark_anchor_line onto that
      -- accidental line forever, since nothing ever reset it again.
      -- Real work then happens around line 5, but named_mark_opportunity
      -- would never fire for it — line 1 was never legitimately a reference
      -- point. See docs/adr/0100-named-mark-repeated-line-return.md.
      local s = seq()
      patterns.feed(s, 'l', 1) -- session opens on line 1
      patterns.feed(s, 'l', 5) -- first navigation: 1 -> 5 (no return yet)
      -- Anchor is provisionally line 1 here, but no return has confirmed it —
      -- moving on to line 10 must re-anchor to line 5, the line just left.
      local second = leave_edit_return(s, 10, 5, 'i')
      assert.is_nil(second)
      local third = leave_edit_return(s, 20, 5, 'x')
      assert.is_nil(third)
      local fourth = leave_edit_return(s, 30, 5, 'x')
      assert.is_not_nil(fourth)
      assert.equals('named_mark_opportunity', fourth.pattern)
      assert.equals('ma', fourth.cmd)
    end
  )

  it('does not count a return with no genuine edit while away as progress', function()
    local s = seq()
    patterns.feed(s, 'i', 10)
    patterns.feed(s, '\27', 10)
    -- leave and return 3 times with no edit at all while away
    for _ = 1, 3 do
      patterns.feed(s, 'l', 20)
      patterns.feed(s, 'l', 10)
    end
    -- a 4th leave+edit+return still only counts as the FIRST genuine return,
    -- since none of the prior bare bounces advanced mark_return_count
    local result = leave_edit_return(s, 20, 10, 'i')
    assert.is_nil(result)
  end)

  it('resets after firing, so a 4th return alone does not immediately refire', function()
    local s = seq()
    patterns.feed(s, 'i', 10)
    patterns.feed(s, '\27', 10)
    leave_edit_return(s, 20, 10, 'i')
    leave_edit_return(s, 30, 10, 'x')
    leave_edit_return(s, 40, 10, 'x') -- fires here
    local result = leave_edit_return(s, 50, 10, 'x')
    assert.is_nil(result)
  end)

  it('does not fire manual_return/changelist_return for the same event (disjoint trigger shapes)', function()
    -- manual_return/changelist_return need 5 CONSECUTIVE return-motion keys
    -- with no edit in between; named_mark_opportunity needs a genuine edit
    -- between every return. The two cannot fire from the same keystrokes.
    local s = seq()
    patterns.feed(s, 'i', 10)
    patterns.feed(s, '\27', 10)
    leave_edit_return(s, 20, 10, 'i')
    leave_edit_return(s, 30, 10, 'x')
    local result = leave_edit_return(s, 40, 10, 'x')
    assert.equals('named_mark_opportunity', result.pattern)
    assert.is_not_equal('manual_return', result.pattern)
    assert.is_not_equal('changelist_return', result.pattern)
  end)

  it('does not increment mark_return_count from a tight manual_return-triggering streak (coexistence)', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0) -- jump
    for _ = 1, 4 do
      patterns.feed(s, 'k', 1, nil, 0) -- line never changes in this test
    end
    local result = patterns.feed(s, 'k', 1, nil, 0)
    assert.equals('manual_return', result.pattern)
    assert.equals(0, s.mark_return_count)
  end)
end)

-- ── macro opportunity detection: repeated edit sequence → qq...q / @q ────────
-- M.feed_macro(seq, token, now) is a separate entry point from M.feed() — see
-- docs/adr/0018-macro-opportunity-detection.md

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

-- A literal example from the docs (see docs/adr/0018-macro-opportunity-detection.md):
-- cwFooBar<Esc> contains a lowercase 'w' and an uppercase 'B', both
-- classified as motion keys — the pitfall regression test below.
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

-- ── visual-block edit streak: same single-line edit on 3+ consecutive ────────
-- ── lines → suggest <C-v> ────────────────────────────────────────────────────
-- see docs/adr/0098-visual-block-edit-streak.md

describe('when the user repeats the same single-line edit on consecutive lines', function()
  it('fires visual_block_opportunity suggesting <C-v> for A;<Esc> repeated 3x with single-line gaps', function()
    local s = seq()
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'A', ';', '<Esc>' })
    assert.is_not_nil(result)
    assert.equals('visual_block_opportunity', result.pattern)
    assert.equals('<C-v>', result.cmd)
  end)

  it('fires for I//<Esc> repeated 3x (comment-out-line shape)', function()
    local s = seq()
    feed_macro_seq(s, { 'I', '/', '/', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'I', '/', '/', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'I', '/', '/', '<Esc>' })
    assert.is_not_nil(result)
    assert.equals('visual_block_opportunity', result.pattern)
  end)

  it('does not fire after only 2 repetitions', function()
    local s = seq()
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'A', ';', '<Esc>' })
    assert.is_nil(result)
  end)

  it('falls back to macro_opportunity when the gap between repeats is more than one line', function()
    local s = seq()
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j', 'j' })
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j', 'j' })
    local result = feed_macro_seq(s, { 'A', ';', '<Esc>' })
    assert.is_not_nil(result)
    assert.equals('macro_opportunity', result.pattern)
  end)

  it(
    'still fires macro_opportunity, not visual_block_opportunity, for operator+motion edits like cwFooBar<Esc> (regression)',
    function()
      local s = seq()
      feed_macro_seq(s, CW_FOOBAR_ESC)
      feed_macro_seq(s, { 'j' })
      feed_macro_seq(s, CW_FOOBAR_ESC)
      feed_macro_seq(s, { 'j' })
      local result = feed_macro_seq(s, CW_FOOBAR_ESC)
      assert.is_not_nil(result)
      assert.equals('macro_opportunity', result.pattern)
    end
  )

  it('does not fire when the repeated content contains a register/macro key', function()
    local s = seq()
    feed_macro_seq(s, { 'i', 'q', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'i', 'q', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'i', 'q', '<Esc>' })
    assert.is_not_equal('visual_block_opportunity', (result or {}).pattern)
  end)

  it('does not fire when only 2 occurrences fit before the buffer start (no room for a 3rd)', function()
    local s = seq()
    -- A leading 'j' with nothing before it: only 2 full occurrences of
    -- A;<Esc> can possibly exist in the buffer, so the search for a 3rd,
    -- earlier occurrence runs out of room.
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'A', ';', '<Esc>' })
    assert.is_not_equal('visual_block_opportunity', (result or {}).pattern)
  end)

  it('does not fire when the earliest occurrence has different content than the other two', function()
    local s = seq()
    feed_macro_seq(s, { 'B', ';', '<Esc>' }) -- earliest occurrence: different content
    feed_macro_seq(s, { 'j' })
    feed_macro_seq(s, { 'A', ';', '<Esc>' })
    feed_macro_seq(s, { 'j' })
    local result = feed_macro_seq(s, { 'A', ';', '<Esc>' })
    assert.is_not_equal('visual_block_opportunity', (result or {}).pattern)
  end)
end)

-- ── gg ↔ G double-jump: suggest '' (jump back to previous position) ──────────
-- see docs/adr/0019-jumplist-changelist-underuse-detection.md

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
-- jump_back and manual_return share seq.jump_last_at — see
-- docs/adr/0019-jumplist-changelist-underuse-detection.md

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
    -- First, a legitimate G -> gg round trip fires jump_back (last_op is
    -- deliberately left as 'gg' afterwards, by design).
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    local first = patterns.feed(s, 'g', 1, nil, 0)
    assert.equals('jump_back', first.pattern)

    -- Long idle gap, then a paste (neither clears last_op == 'gg'), then an
    -- unrelated bare G — timed so a k-streak after it only stays in
    -- tolerance of THIS G's timestamp, proving jump_last_at was refreshed.
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
-- jump_last_at/manual_return above (this behavior only ever describes
-- back-to-back keystrokes, never elapsed time). Pins this down so a future
-- change doesn't silently alter it.
describe("jump_back's last_op sentinel has no time bound (intentional, see above)", function()
  it('still fires after a long idle gap with no intervening key', function()
    local s = seq()
    patterns.feed(s, 'G', 1, nil, 0)
    patterns.feed(s, 'g', 1, nil, 0)
    local result = patterns.feed(s, 'g', 1, nil, 60000) -- 60s later, no other key
    assert.equals('jump_back', result.pattern)
  end)
end)
