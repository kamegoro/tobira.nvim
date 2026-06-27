local M = {}

local data_dir = vim.fn.stdpath('data') .. '/tobira'
local data_file = data_dir .. '/usage.json'

local usage = {}
local _initialized = false

-- Callback wired by init.lua. logger has no direct dependency on suggest.
M.on_pattern = nil

-- Cache current mode via ModeChanged to avoid vim.fn.mode() on every keystroke
local current_mode = 'n'

local seq = {
  pending_f = nil,
  last_f = nil,
  pending_op = nil,
  last_op = nil,
  run = {},
}

local function ensure_dir()
  vim.fn.mkdir(data_dir, 'p')
end

local function load()
  local f = io.open(data_file, 'r')
  if not f then
    return {}
  end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return (ok and type(data) == 'table') and data or {}
end

local function save()
  ensure_dir()
  local f = io.open(data_file, 'w')
  if not f then
    return
  end
  f:write(vim.json.encode(usage))
  f:close()
end

local function increment(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, shown = 0, adopted = false }
  end
  usage[cmd].count = usage[cmd].count + 1
end

local function fire(pattern, cmd)
  if M.on_pattern then
    M.on_pattern(pattern, cmd)
  end
end

local function track_run(key)
  if seq.run.key == key then
    seq.run.count = seq.run.count + 1
  else
    seq.run = { key = key, count = 1 }
  end
  return seq.run.count
end

local function handle_key(key)
  if current_mode ~= 'n' then
    seq.pending_f = nil
    seq.pending_op = nil
    seq.run = {}
    return
  end

  local line = vim.fn.line('.')

  -- f/F: wait for the target character
  if key == 'f' or key == 'F' then
    seq.pending_f = key
    seq.pending_op = nil
    seq.run = {}
    return
  end

  if seq.pending_f then
    local f_op = seq.pending_f
    seq.pending_f = nil
    increment(f_op)

    if seq.last_f and seq.last_f.line == line and seq.last_f.char == key and seq.last_f.op == f_op then
      fire('f_repeat', ';')
    end

    seq.last_f = { char = key, line = line, op = f_op }
    return
  end

  if seq.last_f and seq.last_f.line ~= line then
    seq.last_f = nil
  end

  -- d/c operators
  if key == 'd' or key == 'c' then
    seq.pending_op = key
    seq.run = {}
    return
  end

  if seq.pending_op then
    local op = seq.pending_op
    seq.pending_op = nil

    if key == 'w' then
      local cmd = op .. 'w'
      increment(cmd)
      seq.last_op = cmd
    elseif key == 'd' and op == 'd' then
      increment('dd')
      seq.last_op = 'dd'
    end
    return
  end

  -- dd → p: swap lines
  if key == 'p' and seq.last_op == 'dd' then
    fire('dd_then_p', 'ddp')
  end

  -- 0 → w: suggest ^
  if key == 'w' and seq.run.key == '0' then
    fire('zero_then_w', '^')
  end

  if key ~= 'p' then
    seq.last_op = nil
  end

  -- Consecutive-run patterns
  local run_count = track_run(key)

  if key == 'x' and run_count >= 3 then
    fire('x_repeat', '{n}x')
  elseif key == 'u' and run_count >= 3 then
    fire('u_repeat', '<C-r>')
  elseif key == 'j' and run_count >= 5 then
    fire('j_repeat', '{n}j')
  end

  if key == ';' or key == ',' or key == 'n' or key == '0' then
    increment(key)
  end
end

function M.setup(config)
  if _initialized then
    return
  end
  _initialized = true

  usage = load()

  local mode_group = vim.api.nvim_create_augroup('tobira_mode', { clear = true })

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = mode_group,
    callback = function()
      current_mode = vim.fn.mode()
    end,
  })

  local ns = vim.api.nvim_create_namespace('tobira_logger')
  vim.on_key(function(key, typed)
    local k = (typed ~= nil and typed ~= '') and typed or key
    if #k == 0 then
      return
    end
    handle_key(k)
  end, ns)

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = vim.api.nvim_create_augroup('tobira_dw', { clear = true }),
    pattern = 'n:i',
    callback = function()
      if seq.last_op == 'dw' then
        fire('dw_then_insert', 'cw')
      end
      seq.last_op = nil
    end,
  })

  vim.api.nvim_create_autocmd('VimLeave', {
    group = mode_group,
    callback = save,
  })
end

-- Test helper: feed keys directly into the state machine
function M.simulate_keys(keys)
  for _, k in ipairs(keys) do
    handle_key(k)
  end
end

function M.get(cmd)
  return usage[cmd] or { count = 0, shown = 0, adopted = false }
end

function M.get_all()
  return usage
end

function M.mark_shown(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, shown = 0, adopted = false }
  end
  usage[cmd].shown = usage[cmd].shown + 1
  save()
end

function M.mark_adopted(cmd)
  if usage[cmd] then
    usage[cmd].adopted = true
    save()
  end
end

function M.reset()
  usage = {}
  _initialized = false
  save()
  vim.notify('tobira: usage log reset', vim.log.levels.INFO)
end

function M.stats()
  local lines = { 'tobira — usage stats', string.rep('─', 28) }
  local sorted = {}
  for cmd, data in pairs(usage) do
    table.insert(sorted, { cmd = cmd, data = data })
  end
  table.sort(sorted, function(a, b)
    return a.data.count > b.data.count
  end)
  for _, item in ipairs(sorted) do
    local mark = item.data.adopted and '✅' or '  '
    table.insert(lines, string.format('%s %-12s %d times', mark, item.cmd, item.data.count))
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M
