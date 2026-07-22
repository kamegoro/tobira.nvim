local patterns = require('tobira.core.patterns')
local patterns_insert = require('tobira.core.patterns_insert')
local commands = require('tobira.commands')

local M = {}

local data_dir = vim.fn.stdpath('data') .. '/tobira'
local data_file = data_dir .. '/usage.json'

local usage = {}
local meta = { guide_seen = false }
local _initialized = false
local seq = patterns.new_seq()
local session_counts = {}
-- Per-command snapshot of {count, shown, suppressed, pinned, celebrated} as
-- of the last time `usage` was synced with disk (initial load, or the end of
-- a previous save()'s merge). merge_with_disk() diffs against this to tell
-- "I changed this locally" apart from "this has always been the default" —
-- see merge_with_disk()'s comment for why that distinction matters (#122).
local _baseline = {}
-- Per-command count of sessions[] entries appended locally since _baseline
-- was last synced. An array-length diff can't recover this once the rolling
-- MAX_SESSIONS cap has evicted entries from either side, so it's tracked
-- explicitly instead (see merge_with_disk()).
local _sessions_appended = {}
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

-- Default baseline shape for a command never before synced with disk —
-- mirrors the zero-value defaults used everywhere a fresh entry is created.
local function baseline_of(entry)
  entry = entry or {}
  return {
    count = entry.count or 0,
    shown = entry.shown or 0,
    suppressed = entry.suppressed == true,
    pinned = entry.pinned == true,
    celebrated = entry.celebrated == true,
  }
end

-- guide_seen has no "unsee" path (mark_guide_seen only ever sets it true), so
-- OR-merging is both correct and safe here: it can never flip a value this
-- process just set back to false because of a stale disk read, and it still
-- picks up a concurrent instance's dismissal of the first-run guide instead
-- of discarding it.
-- Callers are expected to have already checked `type(disk_meta) == 'table'`
-- (see load() / save()) — corrupt/absent _meta is filtered out there.
local function merge_meta(disk_meta)
  meta.guide_seen = (meta.guide_seen == true) or (disk_meta.guide_seen == true)
end

-- Rebuild _baseline/_sessions_appended from the current `usage` table.
-- Called whenever `usage` is freshly (re)synced with disk: setup(),
-- load_from_disk(), and the end of every save() once the merged result has
-- been written. Every later save() diffs local changes against this
-- snapshot (see merge_with_disk()).
local function sync_baseline()
  _baseline = {}
  _sessions_appended = {}
  for cmd, entry in pairs(usage) do
    if type(entry) == 'table' then
      _baseline[cmd] = baseline_of(entry)
    end
  end
end

local function read_disk()
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
  return data
end

local function load()
  local data = read_disk()
  if type(data._meta) == 'table' then
    merge_meta(data._meta)
  end
  data._meta = nil
  -- Migrate entries from old format on load; reset shown so max_shown is per-session
  for _, entry in pairs(data) do
    if type(entry) == 'table' then
      migrate_entry(entry)
      entry.shown = 0
    end
  end
  return data
end

-- Merge in-memory `usage` with whatever is currently on disk before writing,
-- so a concurrent Neovim instance's writes are never silently overwritten
-- (#122). Every save-triggering function (mark_shown, mark_adopted,
-- set_suppressed, set_pinned, mark_celebrated, close_session, ...) goes
-- through save() → this single merge point, instead of each duplicating its
-- own merge logic. Previously only close_session() merged anything, and
-- only its `.count` field.
--
-- Per-field strategy, decided deliberately field by field:
--
--   .count : additive. This instance's growth since ITS OWN last sync with
--     disk (`_baseline`) is real new data (keystrokes counted) that
--     happened in this process; stacking that delta on top of disk's
--     current value preserves what every other concurrently running
--     instance already contributed. This generalizes the delta logic
--     close_session() already had.
--
--   .shown : local value only, never combined with disk. `load()` always
--     resets in-memory `shown` to 0 so the max_shown display cap is
--     per-launch, not lifetime. Folding disk's old `.shown` back in the way
--     `.count` does would quietly turn a per-launch counter into a
--     cumulative-forever one, which is not what "reset shown so max_shown
--     is per-session" (see load()) means.
--
--   .sessions : union, not overwrite. Two concurrently running instances
--     can each close a real session; both entries are meaningful input to
--     the decay/mastery scoring in graph.lua, and neither should be
--     dropped. Disk's current array (which may already include another
--     instance's entries) is kept as-is, and only the entries THIS instance
--     appended since its own baseline are added on top — tracked via
--     `_sessions_appended` rather than an array-length diff, because the
--     rolling MAX_SESSIONS cap can evict old entries from either side
--     without that meaning "no new data". The rolling cap is then
--     re-applied to the merged result.
--
--   .suppressed / .pinned / .celebrated : sticky booleans. If THIS instance
--     changed the flag since its own baseline, that's a deliberate local
--     decision (e.g. the user just un-suppressed a command from
--     :TobiraGuide) and wins outright — this is what keeps the existing
--     "suppress then un-suppress" round trip working within one instance.
--     If this instance never touched the flag, whatever is currently on
--     disk is adopted as-is, which is what lets instance A's set_suppressed
--     survive instance B's unrelated save. In the pure concurrent-write
--     case (neither instance touches the other's flag) this behaves like an
--     OR: once suppressed/pinned by any instance, it stays that way.
--     `.celebrated` gets the same treatment: it is only ever set, never
--     unset (there is no "uncelebrate" call anywhere in the codebase — see
--     suggest.lua's `not logger.is_celebrated(cmd)` guard), so the same
--     OR-like stickiness matches how it's actually used.
local function merge_with_disk(disk_data)
  local merged = {}

  local all_cmds = {}
  for cmd, entry in pairs(usage) do
    if type(entry) == 'table' then
      all_cmds[cmd] = true
    end
  end
  for cmd, entry in pairs(disk_data) do
    if type(entry) == 'table' then
      all_cmds[cmd] = true
    end
  end

  for cmd in pairs(all_cmds) do
    local mem_entry = usage[cmd]
    local disk_entry = type(disk_data[cmd]) == 'table' and disk_data[cmd] or nil

    if mem_entry and disk_entry then
      local baseline = _baseline[cmd] or baseline_of(nil)

      local mem_sessions = mem_entry.sessions or {}
      local mem_count = mem_entry.count or 0
      local mem_suppressed = mem_entry.suppressed == true
      local mem_pinned = mem_entry.pinned == true
      local mem_celebrated = mem_entry.celebrated == true

      local count_delta = math.max(0, mem_count - baseline.count)

      local appended = math.min(_sessions_appended[cmd] or 0, #mem_sessions)
      local new_sessions = vim.deepcopy(disk_entry.sessions or {})
      for i = #mem_sessions - appended + 1, #mem_sessions do
        table.insert(new_sessions, mem_sessions[i])
      end
      while #new_sessions > MAX_SESSIONS do
        table.remove(new_sessions, 1)
      end

      local function merge_flag(mem_val, base_val, disk_val)
        if mem_val ~= base_val then
          return mem_val
        end
        return disk_val == true
      end

      merged[cmd] = {
        count = (disk_entry.count or 0) + count_delta,
        shown = mem_entry.shown or 0,
        sessions = new_sessions,
        suppressed = merge_flag(mem_suppressed, baseline.suppressed, disk_entry.suppressed),
        pinned = merge_flag(mem_pinned, baseline.pinned, disk_entry.pinned),
        celebrated = merge_flag(mem_celebrated, baseline.celebrated, disk_entry.celebrated),
      }
    elseif mem_entry then
      merged[cmd] = mem_entry
    else
      merged[cmd] = migrate_entry(disk_entry)
    end
  end

  return merged
end

-- Write to a temp file then rename so a crash mid-write can never corrupt the data file.
local function write_file()
  ensure_dir()
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

local function save()
  ensure_dir()

  local disk_data = read_disk()
  if type(disk_data._meta) == 'table' then
    merge_meta(disk_data._meta)
  end
  disk_data._meta = nil

  usage = merge_with_disk(disk_data)
  sync_baseline()

  write_file()
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
-- patterns_insert.feed_insert() cares about (#58). Built once via the same
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

local insert_seq = patterns_insert.new_insert_seq()

local _recording_macro = false

local function handle_insert_key(key)
  local canonical = INSERT_SPECIAL[key]
  if canonical == '<C-w>' then
    increment('<C-w>')
  end
  local result = patterns_insert.feed_insert(insert_seq, canonical)
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
    insert_seq = patterns_insert.new_insert_seq()
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

  local result = patterns.feed(seq, key, line)

  -- Track compound operators (dw, dd, gg, >>, …) the moment they complete.
  -- Single-char keys are handled by the TRACK lookup below; compound ones
  -- are only visible here through seq.op_completed, which patterns.feed()
  -- sets on the exact call that freshly assigns seq.last_op. This must NOT
  -- be a before/after value comparison on seq.last_op — two identical
  -- compounds back-to-back (dd dd, dw dw, …) re-assign the same string, so
  -- a value-change check would silently drop the second occurrence (#119).
  if seq.op_completed then
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
  sync_baseline()

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
        insert_seq = patterns_insert.new_insert_seq()
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
    _sessions_appended[cmd] = (_sessions_appended[cmd] or 0) + 1
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
      _sessions_appended[cmd] = (_sessions_appended[cmd] or 0) + 1
      while #entry.sessions > MAX_SESSIONS do
        table.remove(entry.sessions, 1)
      end
    end
  end

  session_counts = {}
  session_adopted = {}

  -- save() re-reads disk and merges before writing (see merge_with_disk()),
  -- so a concurrent Neovim instance's writes are never overwritten here.
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
  _sessions_appended[cmd] = (_sessions_appended[cmd] or 0) + 1
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
  _baseline = {}
  _sessions_appended = {}
  meta = { guide_seen = false }
  seq = patterns.new_seq()
  insert_seq = patterns_insert.new_insert_seq()
  current_mode = 'n'
  _recording_macro = false
  _initialized = false
  -- Intentionally no disk I/O here. Callers that want disk cleared
  -- (e.g. :TobiraReset) invoke clear_disk() explicitly afterwards.
end

-- Re-read usage from disk without resetting in-memory state.
-- Used in tests to verify migration of old-format JSON.
function M.load_from_disk()
  usage = load()
  sync_baseline()
end

-- Merge-on-save (see merge_with_disk()) — every other public save path goes
-- through this.
function M.save()
  save()
end

-- Overwrites usage.json unconditionally, bypassing the merge-on-save that
-- M.save() otherwise does. Used only by :TobiraReset. A full reset is an
-- explicit "erase everything" user action, not an incremental update — if it
-- went through the normal merge, an empty in-memory `usage` would just
-- resurrect every entry a concurrent instance (or a previous run) still has
-- on disk, and :TobiraReset would silently stop actually resetting anything
-- (#122).
function M.clear_disk()
  write_file()
  sync_baseline()
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
