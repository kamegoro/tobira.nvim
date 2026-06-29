local patterns = require('tobira.core.patterns')
local commands = require('tobira.commands')

local M = {}

local data_dir = vim.fn.stdpath('data') .. '/tobira'
local data_file = data_dir .. '/usage.json'

local usage = {}
local meta = { guide_seen = false }
local _initialized = false
local seq = patterns.new_seq()
local session_counts = {}

-- Wired by init.lua — logger has no direct dependency on suggest.
M.on_pattern = nil

local current_mode = 'n'

local MAX_SESSIONS = 10

local function ensure_dir()
  vim.fn.mkdir(data_dir, 'p')
end

-- Migrate a single entry from the old format (adopted field) to the new format
-- (sessions array + suppressed). Returns the mutated entry.
local function migrate_entry(entry)
  if not entry.sessions then
    entry.sessions = entry.adopted == true and { 10 } or {}
  end
  if entry.suppressed == nil then
    entry.suppressed = false
  end
  entry.adopted = nil
  return entry
end

local function load()
  local f = io.open(data_file, 'r')
  -- first-run guard, not exercised once a stats file exists
  -- luacov: disable
  if not f then
    return {}
  end
  -- luacov: enable
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  -- corrupt/invalid JSON guard, not reachable with valid data
  -- luacov: disable
  if not (ok and type(data) == 'table') then
    return {}
  end
  -- luacov: enable
  if data._meta then
    meta = vim.tbl_extend('force', meta, data._meta)
    data._meta = nil
  end
  -- Migrate entries from old format on load
  for _, entry in pairs(data) do
    if type(entry) == 'table' then
      migrate_entry(entry)
    end
  end
  return data
end

local function save()
  ensure_dir()
  local f = io.open(data_file, 'w')
  -- open-for-write failure guard, not reachable in tests
  -- luacov: disable
  if not f then
    return
  end
  -- luacov: enable
  local payload = vim.deepcopy(usage)
  payload._meta = meta
  f:write(vim.json.encode(payload))
  f:close()
end

local function increment(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false }
  end
  usage[cmd].count = usage[cmd].count + 1
  session_counts[cmd] = (session_counts[cmd] or 0) + 1
end

-- Base single-char keys to track: prerequisites for suggestions + level detection.
-- Registry entries with track = true are merged in below.
local function build_track_table()
  local t = {
    f = true,
    F = true,
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
  for cmd, entry in pairs(commands.registry) do
    if entry.track and #cmd == 1 then
      t[cmd] = true
    end
  end
  return t
end
local TRACK = build_track_table()

local function handle_key(key)
  if current_mode:sub(1, 1) ~= 'n' then
    seq = patterns.new_seq()
    return
  end

  local line = vim.fn.line('.')
  local prev_op = seq.last_op
  local result = patterns.feed(seq, key, line)

  -- Track compound operators (dw, dd, cw …) the moment they complete.
  -- Single-char keys are handled by the TRACK lookup below; compound ones
  -- are only visible here through the change in seq.last_op.
  -- luacov: disable
  if seq.last_op ~= nil and seq.last_op ~= prev_op then
    increment(seq.last_op)
  end
  -- luacov: enable

  if result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  end

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

  local ns = vim.api.nvim_create_namespace('tobira_logger')
  vim.on_key(function(key, typed)
    local k = (typed ~= nil and typed ~= '') and typed or key
    -- empty-keystroke guard, not reproducible via feedkeys
    -- luacov: disable
    if #k == 0 then
      return
    end
    -- luacov: enable
    handle_key(k)
  end, ns)

  vim.api.nvim_create_autocmd('VimLeave', {
    group = mode_group,
    callback = M.close_session,
  })
end

-- Flush current-session key counts into usage.sessions, then save.
-- Called on VimLeave and exposed for testing.
function M.close_session()
  for cmd, count in pairs(session_counts) do
    table.insert(usage[cmd].sessions, count)
    while #usage[cmd].sessions > MAX_SESSIONS do
      table.remove(usage[cmd].sessions, 1)
    end
  end
  session_counts = {}
  save()
end

function M.get(cmd)
  return usage[cmd] or { count = 0, sessions = {}, shown = 0, suppressed = false }
end

-- Exposed only for testing — lets specs verify in-session counts before close_session.
function M.get_session_counts()
  return session_counts
end

function M.get_all()
  return usage
end

function M.mark_shown(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false }
  end
  usage[cmd].shown = usage[cmd].shown + 1
  save()
end

-- Treat an explicit in-session adoption as a strong session signal.
-- Immediately flushes a boosted count to sessions so is_adopted() returns true
-- without waiting for the next VimLeave.
function M.mark_adopted(cmd)
  local count = math.max(session_counts[cmd] or 0, 5)
  session_counts[cmd] = nil
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false }
  end
  table.insert(usage[cmd].sessions, count)
  while #usage[cmd].sessions > MAX_SESSIONS do
    table.remove(usage[cmd].sessions, 1)
  end
  save()
end

function M.set_suppressed(cmd, value)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false }
  end
  usage[cmd].suppressed = value
  save()
end

function M.reset()
  usage = {}
  session_counts = {}
  meta = { guide_seen = false }
  seq = patterns.new_seq()
  current_mode = 'n'
  _initialized = false
  pcall(os.remove, data_file)
end

-- Re-read usage from disk without resetting in-memory state.
-- Used in tests to verify migration of old-format JSON.
function M.load_from_disk()
  usage = load()
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
  local str = require('tobira.i18n').load()
  local lines = { str.stats.title, string.rep('─', 28) }
  local sorted = {}
  for cmd, data in pairs(usage) do
    table.insert(sorted, { cmd = cmd, data = data })
  end
  table.sort(sorted, function(a, b)
    return a.data.count > b.data.count
  end)
  for _, item in ipairs(sorted) do
    local graph = require('tobira.core.graph')
    local mark = graph.is_adopted(item.data) and '✅' or '  '
    table.insert(lines, string.format('%s %-12s %d %s', mark, item.cmd, item.data.count, str.stats.times))
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M
