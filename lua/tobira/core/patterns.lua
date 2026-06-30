-- Pure pattern detection. No vim.* calls.
-- feed() mutates seq in place and returns a fired pattern or nil.

local M = {}

function M.new_seq()
  return {
    pending_f = nil,
    last_f = nil,
    pending_op = nil,
    last_op = nil,
    run = { key = nil, count = 0 },
    prev_key = nil,
    dd_streak = 0,
  }
end

-- Keys that enter insert mode directly (no operator). Used to detect the
-- "deleted a word, then retyped it" inefficiency where `cw` is faster.
local INSERT_KEYS = {
  i = true,
  I = true,
  a = true,
  A = true,
  o = true,
  O = true,
  s = true,
  S = true,
}

local function track_run(seq, key)
  if seq.run.key == key then
    seq.run.count = seq.run.count + 1
  else
    seq.run = { key = key, count = 1 }
  end
  return seq.run.count
end

local function inner_feed(seq, key, line)
  -- f / F / t / T: pend until the target character arrives
  if key == 'f' or key == 'F' or key == 't' or key == 'T' then
    seq.pending_f = key
    seq.pending_op = nil
    seq.run = { key = nil, count = 0 }
    return nil
  end

  if seq.pending_f then
    local op = seq.pending_f
    seq.pending_f = nil

    local fired = nil
    if seq.last_f and seq.last_f.line == line and seq.last_f.char == key and seq.last_f.op == op then
      fired = { pattern = 'f_repeat', cmd = ';' }
    end

    seq.last_f = { char = key, line = line, op = op }
    return fired
  end

  if seq.last_f and seq.last_f.line ~= line then
    seq.last_f = nil
  end

  -- Complete a pending text object (i/a + one more char → charwise).
  if seq.pending_text_obj then
    local op = seq.pending_text_obj
    seq.pending_text_obj = nil
    seq.last_op = op .. 'w'
    return nil
  end

  -- Complete a pending operator.
  if seq.pending_op then
    local op = seq.pending_op

    -- Count digits: keep waiting for the actual motion.
    if key:match('^[1-9]$') then
      return nil
    end

    seq.pending_op = nil

    if key == '\27' then
      return nil
    elseif key == op or key == 'j' or key == 'k' then
      -- linewise: dd / cc / dj / dk
      seq.last_op = 'dd'
      -- Track consecutive dd for dd_run detection.
      if key == op then
        seq.dd_streak = seq.dd_streak + 1
        if seq.dd_streak >= 3 then
          seq.dd_streak = 0
          return { pattern = 'dd_run', cmd = '{n}dd' }
        end
      else
        seq.dd_streak = 0
      end
    elseif key == 'i' or key == 'a' then
      seq.pending_text_obj = op
    else
      seq.last_op = op .. 'w'
    end
    return nil
  end

  -- d / c: start waiting for the motion character
  if key == 'd' or key == 'c' then
    seq.pending_op = key
    seq.run = { key = nil, count = 0 }
    return nil
  end

  -- dd → p (swap lines)
  if key == 'p' and seq.last_op == 'dd' then
    seq.last_op = nil
    seq.dd_streak = 0
    return { pattern = 'dd_then_p', cmd = 'ddp' }
  end

  -- 0 → w: first non-blank is faster
  if key == 'w' and seq.run.key == '0' then
    return { pattern = 'zero_then_w', cmd = '^' }
  end

  -- 0 or ^ → i: suggest I.
  -- run.key check guards against d^ followed by i (pending_op path doesn't update run).
  if key == 'i' and (seq.run.key == '0' or seq.run.key == '^') then
    return { pattern = 'zero_then_insert', cmd = 'I' }
  end

  -- $ → a: suggest A.
  if key == 'a' and seq.run.key == '$' then
    return { pattern = 'dollar_then_append', cmd = 'A' }
  end

  -- k → o (exactly one k preceding): suggest O (open line above).
  if key == 'o' and seq.run.key == 'k' and seq.run.count == 1 then
    return { pattern = 'k_then_o', cmd = 'O' }
  end

  -- D → insert: suggest C (change to end of line).
  if INSERT_KEYS[key] and seq.run.key == 'D' then
    return { pattern = 'D_then_insert', cmd = 'C' }
  end

  -- dw → insert: suggest cw (change word directly instead of delete-then-retype).
  if seq.last_op == 'dw' and INSERT_KEYS[key] then
    seq.last_op = nil
    return { pattern = 'dw_then_insert', cmd = 'cw' }
  end

  if key ~= 'p' then
    seq.last_op = nil
    seq.dd_streak = 0
  end

  -- Consecutive-run patterns.
  -- Use == (not >=) so each threshold fires exactly once; higher thresholds
  -- for the same key can coexist (e.g., j_repeat at 5 and j_many at 10).
  local count = track_run(seq, key)

  if key == 'x' and count == 3 then
    return { pattern = 'x_repeat', cmd = '{n}x' }
  elseif key == 'u' and count == 3 then
    return { pattern = 'u_repeat', cmd = '<C-r>' }
  elseif key == 'j' and count == 5 then
    return { pattern = 'j_repeat', cmd = '{n}j' }
  elseif key == 'j' and count == 10 then
    return { pattern = 'j_many', cmd = '}' }
  elseif key == 'k' and count == 5 then
    return { pattern = 'k_repeat', cmd = '{n}k' }
  elseif key == 'k' and count == 10 then
    return { pattern = 'k_many', cmd = '{' }
  elseif key == 'n' and count == 4 then
    return { pattern = 'n_repeat', cmd = 'cgn' }
  elseif key == 'l' and count == 5 then
    return { pattern = 'l_repeat', cmd = 'w' }
  elseif key == 'h' and count == 5 then
    return { pattern = 'h_repeat', cmd = 'b' }
  elseif key == 'w' and count == 5 then
    return { pattern = 'w_repeat', cmd = 'W' }
  elseif key == 'b' and count == 5 then
    return { pattern = 'b_repeat', cmd = 'B' }
  elseif key == 'p' and count == 3 then
    return { pattern = 'p_repeat', cmd = '{n}p' }
  elseif key == 'P' and count == 3 then
    return { pattern = 'P_repeat', cmd = '{n}P' }
  elseif key == '~' and count == 3 then
    return { pattern = 'tilde_repeat', cmd = '{n}~' }
  end

  return nil
end

function M.feed(seq, key, line)
  local result = inner_feed(seq, key, line)
  seq.prev_key = key
  return result
end

return M
