local patterns = require('tobira.core.patterns')

local M = {}

local data_dir = vim.fn.stdpath('data') .. '/tobira'
local data_file = data_dir .. '/usage.json'

local usage = {}
local meta = { guide_seen = false }
local _initialized = false
local seq = patterns.new_seq()

-- Wired by init.lua — logger has no direct dependency on suggest.
M.on_pattern = nil

local current_mode = 'n'

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
  if not (ok and type(data) == 'table') then
    return {}
  end
  if data._meta then
    meta = vim.tbl_extend('force', meta, data._meta)
    data._meta = nil
  end
  return data
end

local function save()
  ensure_dir()
  local f = io.open(data_file, 'w')
  if not f then
    return
  end
  local payload = vim.deepcopy(usage)
  payload._meta = meta
  f:write(vim.json.encode(payload))
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
    seq = patterns.new_seq()
    return
  end

  local line = vim.fn.line('.')
  local result = patterns.feed(seq, key, line)

  if result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  end

  local TRACK = {
    f = true,
    F = true,
    [';'] = true,
    [','] = true,
    n = true,
    ['0'] = true,
    h = true,
    j = true,
    k = true,
    l = true,
    w = true,
    b = true,
    x = true,
    p = true,
    u = true,
    i = true,
    a = true,
    o = true,
    g = true,
    G = true,
    v = true,
    ['*'] = true,
  }
  if TRACK[key] then
    increment(key)
  end
end

function M.setup()
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

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = vim.api.nvim_create_augroup('tobira_dw', { clear = true }),
    pattern = 'n:i',
    callback = function()
      if seq.last_op == 'dw' then
        if M.on_pattern then
          M.on_pattern('dw_then_insert', 'cw')
        end
      end
      seq = patterns.new_seq()
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

  vim.api.nvim_create_autocmd('VimLeave', {
    group = mode_group,
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
  seq = patterns.new_seq()
  _initialized = false
  vim.notify('tobira: usage log reset', vim.log.levels.INFO)
end

function M.save()
  save()
end

function M.is_guide_seen()
  return meta.guide_seen == true
end

function M.mark_guide_seen()
  meta.guide_seen = true
  save()
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
