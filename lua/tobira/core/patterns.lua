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
    -- r-replacement tracking: r{char} l r{char} l r{char} → R
    pending_r = false,
    r_streak = 0,
    -- visual text-object tracking: v i {obj} c/d/y → c/d/yiw etc.
    pending_visual = false,
    visual_inner = nil,
    visual_obj = nil,
  }
end

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
  -- ── f / F / t / T ────────────────────────────────────────────────────────
  if key == 'f' or key == 'F' or key == 't' or key == 'T' then
    seq.pending_f = key
    seq.pending_op = nil
    seq.run = { key = nil, count = 0 }
    seq.r_streak = 0
    seq.visual_obj = nil
    seq.visual_inner = nil
    seq.pending_visual = false
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

  -- ── pending_r: consume replacement character ──────────────────────────────
  if seq.pending_r then
    seq.pending_r = false
    seq.r_streak = seq.r_streak + 1
    if seq.r_streak >= 3 then
      seq.r_streak = 0
      return { pattern = 'r_run', cmd = 'R' }
    end
    return nil
  end

  -- ── visual text-object tracking ───────────────────────────────────────────
  -- State: pending_visual → visual_inner → visual_obj → operator
  if seq.visual_obj then
    if key == 'c' or key == 'd' or key == 'y' then
      local cmd = key .. seq.visual_inner .. seq.visual_obj
      seq.visual_obj = nil
      seq.visual_inner = nil
      return { pattern = 'visual_textobj', cmd = cmd }
    end
    -- Non-operator: cancel and fall through
    seq.visual_obj = nil
    seq.visual_inner = nil
  end

  if seq.visual_inner then
    seq.visual_obj = key
    return nil
  end

  if seq.pending_visual then
    seq.pending_visual = false
    if key == 'i' or key == 'a' then
      seq.visual_inner = key
    end
    -- Whether accepted or cancelled, consume and return
    return nil
  end

  -- ── pending_text_obj ──────────────────────────────────────────────────────
  if seq.pending_text_obj then
    local op = seq.pending_text_obj
    seq.pending_text_obj = nil
    seq.last_op = op .. 'w'
    return nil
  end

  -- ── pending_op ────────────────────────────────────────────────────────────
  if seq.pending_op then
    local op = seq.pending_op
    if key:match('^[1-9]$') then
      return nil
    end
    seq.pending_op = nil
    if key == '\27' then
      return nil
    elseif key == op or key == 'j' or key == 'k' then
      seq.last_op = 'dd'
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

  -- ── d / c operator start ──────────────────────────────────────────────────
  if key == 'd' or key == 'c' then
    seq.pending_op = key
    seq.run = { key = nil, count = 0 }
    return nil
  end

  -- ── r: single-char replace ────────────────────────────────────────────────
  if key == 'r' then
    seq.pending_r = true
    return nil
  end

  -- ── v: start visual text-object tracking ─────────────────────────────────
  if key == 'v' then
    seq.pending_visual = true
    return nil
  end

  -- ── r_streak reset for keys that break the r-replacement flow ────────────
  -- h and l are safe navigation between replacements; everything else resets.
  if key ~= 'h' and key ~= 'l' then
    seq.r_streak = 0
  end

  -- ── dd → p (swap lines) ──────────────────────────────────────────────────
  if key == 'p' and seq.last_op == 'dd' then
    seq.last_op = nil
    seq.dd_streak = 0
    return { pattern = 'dd_then_p', cmd = 'ddp' }
  end

  -- ── dd → insert: suggest cc ──────────────────────────────────────────────
  if seq.last_op == 'dd' and INSERT_KEYS[key] then
    seq.last_op = nil
    seq.dd_streak = 0
    return { pattern = 'dd_then_insert', cmd = 'cc' }
  end

  -- ── 0 → w: first non-blank ───────────────────────────────────────────────
  if key == 'w' and seq.run.key == '0' then
    return { pattern = 'zero_then_w', cmd = '^' }
  end

  -- ── 0 / ^ → i: suggest I ────────────────────────────────────────────────
  if key == 'i' and (seq.run.key == '0' or seq.run.key == '^') then
    return { pattern = 'zero_then_insert', cmd = 'I' }
  end

  -- ── $ → a: suggest A ─────────────────────────────────────────────────────
  if key == 'a' and seq.run.key == '$' then
    return { pattern = 'dollar_then_append', cmd = 'A' }
  end

  -- ── k (exactly once) → o: suggest O ─────────────────────────────────────
  if key == 'o' and seq.run.key == 'k' and seq.run.count == 1 then
    return { pattern = 'k_then_o', cmd = 'O' }
  end

  -- ── x (exactly once) → insert: suggest s ─────────────────────────────────
  if INSERT_KEYS[key] and seq.run.key == 'x' and seq.run.count == 1 then
    return { pattern = 'x_then_insert', cmd = 's' }
  end

  -- ── D → insert: suggest C ────────────────────────────────────────────────
  if INSERT_KEYS[key] and seq.run.key == 'D' then
    return { pattern = 'D_then_insert', cmd = 'C' }
  end

  -- ── dw → insert: suggest cw ──────────────────────────────────────────────
  if seq.last_op == 'dw' and INSERT_KEYS[key] then
    seq.last_op = nil
    return { pattern = 'dw_then_insert', cmd = 'cw' }
  end

  if key ~= 'p' then
    seq.last_op = nil
    seq.dd_streak = 0
  end

  -- ── consecutive-run patterns ──────────────────────────────────────────────
  -- == (not >=): each threshold fires exactly once, enabling multi-threshold
  -- patterns like j_repeat(5) and j_many(10) for the same key.
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
