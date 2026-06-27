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

  -- d / c operators: wait for the motion
  if key == 'd' or key == 'c' then
    seq.pending_op = key
    seq.run = { key = nil, count = 0 }
    return nil
  end

  if seq.pending_op then
    local op = seq.pending_op
    seq.pending_op = nil

    if key == 'w' then
      seq.last_op = op .. 'w'
    elseif key == 'd' and op == 'd' then
      seq.last_op = 'dd'
    end
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
  end

  return nil
end

return M
