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

function M.feed(seq, key, line)
  -- f / F: pend until the target character arrives
  if key == 'f' or key == 'F' then
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
      -- <Esc>: operator cancelled, nothing to record.
      return nil
    elseif key == op or key == 'j' or key == 'k' then
      -- linewise: dd / cc / dj / dk
      seq.last_op = 'dd'
    elseif key == 'i' or key == 'a' then
      -- text object prefix: wait for the object character (diw, da", …)
      seq.pending_text_obj = op
    else
      -- any other motion (w, b, e, $, ^, f, t, h, l, …): charwise
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

  -- dd → p
  if key == 'p' and seq.last_op == 'dd' then
    return { pattern = 'dd_then_p', cmd = 'ddp' }
  end

  -- 0 → w
  if key == 'w' and seq.run.key == '0' then
    return { pattern = 'zero_then_w', cmd = '^' }
  end

  -- dw → i/a/o/s (entering insert to retype the word) → cw is faster
  if seq.last_op == 'dw' and INSERT_KEYS[key] then
    seq.last_op = nil
    return { pattern = 'dw_then_insert', cmd = 'cw' }
  end

  if key ~= 'p' then
    seq.last_op = nil
  end

  -- Consecutive-run patterns
  local count = track_run(seq, key)

  if key == 'x' and count >= 3 then
    return { pattern = 'x_repeat', cmd = '{n}x' }
  elseif key == 'u' and count >= 3 then
    return { pattern = 'u_repeat', cmd = '<C-r>' }
  elseif key == 'j' and count >= 5 then
    return { pattern = 'j_repeat', cmd = '{n}j' }
  elseif key == 'k' and count >= 5 then
    return { pattern = 'k_repeat', cmd = '{n}k' }
  elseif key == 'n' and count >= 4 then
    return { pattern = 'n_repeat', cmd = 'cgn' }
  end

  return nil
end

return M
