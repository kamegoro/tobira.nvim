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
local _loaded_counts = {}
-- Commands flushed early via mark_adopted() this session, so close_session()
-- doesn't also zero-pad or re-append them (see close_session's zero-pad loop).
local session_adopted = {}

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
  if entry.pinned == nil then
    entry.pinned = false
  end
  if entry.celebrated == nil then
    entry.celebrated = false
  end
  entry.adopted = nil
  return entry
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
  -- Migrate entries from old format on load; reset shown so max_shown is per-session
  for _, entry in pairs(data) do
    if type(entry) == 'table' then
      migrate_entry(entry)
      entry.shown = 0
    end
  end
  return data
end

local function save()
  ensure_dir()
  -- Write to a temp file then rename so a crash mid-write can never corrupt the data file.
  local tmp = data_file .. '.tmp'
  local f = io.open(tmp, 'w')
  if not f then
    return
  end
  local payload = vim.deepcopy(usage)
  payload._meta = meta
  f:write(vim.json.encode(payload))
  f:close()
  os.rename(tmp, data_file)
end

local function increment(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].count = usage[cmd].count + 1
  session_counts[cmd] = (session_counts[cmd] or 0) + 1
end

-- Maps raw keystroke bytes → registry key name for increment().
-- Values are the canonical registry key string (e.g. '\x04' → '<C-d>').
-- Single ASCII keys map to themselves; multi-char notation (<C-d> etc.) is
-- converted via nvim_replace_termcodes so the raw byte matches what on_key
-- delivers.
local function build_track_table()
  -- Base single-char ASCII keys (not in registry but needed for level detection).
  -- 'g' omitted: it's always part of a compound (gg, gj…) tracked via last_op.
  local t = {
    f = 'f',
    F = 'F',
    n = 'n',
    ['0'] = '0',
    h = 'h',
    j = 'j',
    k = 'k',
    l = 'l',
    w = 'w',
    b = 'b',
    x = 'x',
    p = 'p',
    u = 'u',
    i = 'i',
    a = 'a',
    o = 'o',
    G = 'G',
    v = 'v',
    ['*'] = '*',
  }
  for cmd, entry in pairs(commands.registry) do
    if entry.track then
      if #cmd == 1 then
        t[cmd] = cmd
      else
        -- Multi-char notation like <C-d>: convert to raw byte for on_key lookup.
        local raw = vim.api.nvim_replace_termcodes(cmd, true, true, true)
        if raw ~= '' then
          t[raw] = cmd
        end
      end
    end
  end
  return t
end
local TRACK = build_track_table()

-- Raw on_key bytes → canonical name, for the handful of insert-mode keys
-- patterns.feed_insert() cares about (#58). Built once via the same
-- nvim_replace_termcodes approach as TRACK above. '<C-w>' is included so its
-- adoption can be measured — this is safe from the normal-mode window-prefix
-- meaning of Ctrl-W because INSERT_SPECIAL is only consulted while the mode
-- cache says insert mode (handle_insert_key), never from the normal-mode path.
local INSERT_SPECIAL = {}
for _, name in ipairs({ '<BS>', '<Left>', '<Right>', '<Esc>', '<C-w>' }) do
  local raw = vim.api.nvim_replace_termcodes(name, true, true, true)
  if raw ~= '' then
    INSERT_SPECIAL[raw] = name
  end
end

local insert_seq = patterns.new_insert_seq()

local _recording_macro = false

local function handle_insert_key(key)
  local canonical = INSERT_SPECIAL[key]
  if canonical == '<C-w>' then
    increment('<C-w>')
  end
  local result = patterns.feed_insert(insert_seq, canonical)
  if result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  end
end

local function handle_key(key)
  if current_mode:sub(1, 1) == 'i' then
    local _re = vim.fn.reg_executing()
    if not (_recording_macro or _re ~= '') then
      handle_insert_key(key)
    end
    return
  end

  if current_mode:sub(1, 1) ~= 'n' then
    seq = patterns.new_seq()
    insert_seq = patterns.new_insert_seq()
    return
  end
  -- Skip keystrokes while recording or replaying a macro so they don't pollute
  -- usage counts. _recording_macro is set by RecordingEnter/Leave autocmd
  -- (cheaper); reg_executing() covers macro replay where no autocmd fires.
  local _re = vim.fn.reg_executing()
  if _recording_macro or _re ~= '' then
    return
  end

  local line = vim.fn.line('.')
  local prev_op = seq.last_op

  local result = patterns.feed(seq, key, line)

  -- Track compound operators (dw, dd, gg, >>, …) the moment they complete.
  -- Single-char keys are handled by the TRACK lookup below; compound ones
  -- are only visible here through the change in seq.last_op.
  if seq.last_op ~= nil and seq.last_op ~= prev_op then
    increment(seq.last_op)
  end

  if result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  end

  -- Only count as a standalone key when it was not consumed as the second
  -- character of a multi-key compound (gj, zz, "a, ]c …).
  -- patterns.feed() sets seq.key_consumed = true in those cases.
  -- TRACK values are registry key strings; raw Ctrl bytes map to their
  -- canonical name (e.g. '\x04' → '<C-d>').
  if not seq.key_consumed then
    local registry_key = TRACK[key]
    if registry_key then
      increment(registry_key)
    end
  end
end

function M.setup()
  if _initialized then
    return
  end
  _initialized = true

  usage = load()
  _loaded_counts = {}
  for cmd, entry in pairs(usage) do
    if type(entry) == 'table' then
      _loaded_counts[cmd] = entry.count or 0
    end
  end

  local mode_group = vim.api.nvim_create_augroup('tobira_mode', { clear = true })

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = mode_group,
    callback = function()
      current_mode = vim.fn.mode()
    end,
  })

  vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group = mode_group,
    callback = function(ev)
      _recording_macro = ev.event == 'RecordingEnter'
      if _recording_macro then
        seq = patterns.new_seq()
        insert_seq = patterns.new_insert_seq()
      end
    end,
  })

  local ns = vim.api.nvim_create_namespace('tobira_logger')
  vim.on_key(function(key, typed)
    -- typed == '' means the key was generated internally (mapping expansion or
    -- built-in command implementation), not physically typed by the user.
    -- Skip it so that pressing D does not also fire 'd' and '$' through the
    -- pattern state machine. typed is nil on Neovim < 0.10; fall back to key.
    if typed == '' then
      return
    end
    handle_key(typed or key)
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

  -- Zero-pad every already-known command that went untouched this session, so
  -- sessions[] reflects real elapsed sessions rather than only sessions where
  -- the command happened to be used. Without this, decay-based scoring (#62)
  -- has no signal that time passed with no use — "idle" was previously
  -- invisible, not recorded as 0. Runs once per VimLeave, never on the
  -- vim.on_key hot path.
  for cmd, entry in pairs(usage) do
    if session_counts[cmd] == nil and not session_adopted[cmd] then
      table.insert(entry.sessions, 0)
      while #entry.sessions > MAX_SESSIONS do
        table.remove(entry.sessions, 1)
      end
    end
  end

  session_counts = {}
  session_adopted = {}

  -- Re-read disk before writing so that counts accumulated by a concurrent
  -- Neovim instance are not overwritten (last-writer-wins data loss).
  -- Strategy: for each command we used this session, add our delta on top of
  -- whatever disk has now.  Commands we never touched are taken from disk as-is.
  local disk_f = io.open(data_file, 'r')
  if disk_f then
    local content = disk_f:read('*a')
    disk_f:close()
    local ok, disk_data = pcall(vim.json.decode, content)
    if ok and type(disk_data) == 'table' then
      if disk_data._meta then
        meta = vim.tbl_extend('force', meta, disk_data._meta)
        disk_data._meta = nil
      end
      for cmd, disk_entry in pairs(disk_data) do
        if type(disk_entry) == 'table' then
          if usage[cmd] then
            local delta = math.max(0, (usage[cmd].count or 0) - (_loaded_counts[cmd] or 0))
            usage[cmd].count = (disk_entry.count or 0) + delta
          else
            usage[cmd] = migrate_entry(disk_entry)
          end
        end
      end
    end
  end

  save()
end

function M.get(cmd)
  return usage[cmd] or { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
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
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
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
  session_adopted[cmd] = true
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  table.insert(usage[cmd].sessions, count)
  while #usage[cmd].sessions > MAX_SESSIONS do
    table.remove(usage[cmd].sessions, 1)
  end
  save()
end

function M.is_celebrated(cmd)
  return usage[cmd] ~= nil and usage[cmd].celebrated == true
end

function M.mark_celebrated(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].celebrated = true
  save()
end

function M.set_suppressed(cmd, value)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].suppressed = value
  save()
end

function M.set_pinned(cmd, value)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].pinned = value
  save()
end

function M.reset()
  usage = {}
  session_counts = {}
  session_adopted = {}
  _loaded_counts = {}
  meta = { guide_seen = false }
  seq = patterns.new_seq()
  insert_seq = patterns.new_insert_seq()
  current_mode = 'n'
  _recording_macro = false
  _initialized = false
  -- Intentionally no disk I/O here. Callers that want disk cleared
  -- (e.g. :TobiraReset) invoke save() explicitly afterwards, which
  -- overwrites usage.json with the empty state.
end

-- Re-read usage from disk without resetting in-memory state.
-- Used in tests to verify migration of old-format JSON.
function M.load_from_disk()
  usage = load()
end

function M.save()
  save()
end

-- Exposed for :checkhealth (#42) so health.lua doesn't recompute or duplicate
-- this path independently.
function M.data_dir()
  return data_dir
end

function M.data_file()
  return data_file
end

function M.is_guide_seen()
  return meta.guide_seen == true
end

function M.mark_guide_seen()
  meta.guide_seen = true
  save()
end

return M
