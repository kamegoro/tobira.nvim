local M = {}

local data_dir = vim.fn.stdpath('data') .. '/tobira'
local data_file = data_dir .. '/usage.json'

local usage = {}

-- Cache current mode via ModeChanged to avoid vim.fn.mode() on every keystroke
local current_mode = 'n'

-- Key sequence tracking state
local seq = {
  pending_f = nil, -- "f" or "F" pressed, waiting for next char
  last_f = nil, -- { char, line, op } last used f-search
  pending_op = nil, -- "d" or "c" operator waiting for motion
  last_op = nil, -- last confirmed operator+motion (e.g. "dw")
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

local function handle_key(key)
  if current_mode ~= 'n' then
    seq.pending_f = nil
    seq.pending_op = nil
    return
  end

  local line = vim.fn.line('.')

  -- Waiting for char after f/F
  if key == 'f' or key == 'F' then
    seq.pending_f = key
    seq.pending_op = nil
    return
  end

  if seq.pending_f then
    local f_op = seq.pending_f
    seq.pending_f = nil
    increment(f_op)

    -- Same f{char} repeated on same line → user likely doesn't know ;
    if seq.last_f and seq.last_f.line == line and seq.last_f.char == key and seq.last_f.op == f_op then
      require('tobira.core.suggest').queue('f_repeat', ';')
    end

    seq.last_f = { char = key, line = line, op = f_op }
    return
  end

  -- Reset last_f when moving to a different line
  if seq.last_f and seq.last_f.line ~= line then
    seq.last_f = nil
  end

  -- Track d/c operators
  if key == 'd' or key == 'c' then
    seq.pending_op = key
    return
  end

  if seq.pending_op then
    local op = seq.pending_op
    seq.pending_op = nil
    if key == 'w' then
      local cmd = op .. 'w'
      increment(cmd)
      seq.last_op = cmd
    end
    return
  end

  -- Track ; and , (f-repeat commands)
  if key == ';' or key == ',' then
    increment(key)
  end
end

function M.setup(config)
  usage = load()

  -- Cache mode to avoid calling vim.fn.mode() on every keystroke
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = vim.api.nvim_create_augroup('tobira_mode', { clear = true }),
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

  -- Detect dw → i pattern via ModeChanged
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = vim.api.nvim_create_augroup('tobira_dw', { clear = true }),
    pattern = 'n:i',
    callback = function()
      if seq.last_op == 'dw' then
        require('tobira.core.suggest').queue('dw_then_insert', 'cw')
      end
      seq.last_op = nil
    end,
  })

  vim.api.nvim_create_autocmd('VimLeave', {
    callback = save,
  })
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
    table.insert(lines, string.format('%s %-10s %d times', mark, item.cmd, item.data.count))
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M
