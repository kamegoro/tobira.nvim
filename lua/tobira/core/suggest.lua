local config = require('tobira.core.config')
local logger = require('tobira.core.logger')
local graph = require('tobira.core.graph')
local level = require('tobira.core.level')
local integrations = require('tobira.core.integrations')

local M = {}

-- Display sink; wired by init.lua to ui.float.show (core/ never require()s ui/).
M.on_show = nil

-- Fired once on first-ever adoption of a suggested command; wired to ui.float.celebrate.
M.on_adopt = nil

local session = {
  last_auto_at = nil,
  timer = nil,
  -- cmd -> { buf = <rolling keytrans buffer>, match_target = <normalized cmd> },
  -- consumed by the single shared adopt_on_key callback below -- see
  -- docs/adr/0111-unified-suggestion-scheduling.md.
  watches = {},
}

local _idle_timer = nil
local _idle_ns = nil

-- Lazily created once, reused for the rest of the session; only the
-- vim.on_key() attachment itself is added/removed as session.watches goes
-- non-empty/empty. See docs/adr/0111-unified-suggestion-scheduling.md.
local _adopt_ns = nil

local KEY_BUF_MAX = 20

-- Normalises <C-x>/<M-x> command strings to keytrans()'s output form for suffix
-- matching -- see docs/adr/0047-adoption-watch-keytrans-rolling-buffer.md for why.
local function normalize_cmd(cmd)
  if cmd:match('^<.->$') then
    local bytes = vim.api.nvim_replace_termcodes(cmd, true, false, true)
    local kt = vim.fn.keytrans(bytes)
    if kt ~= '' then
      return kt
    end
  end
  return cmd
end

-- True when buf ends with cmd (post-normalisation), or cmd is a count-prefix
-- meta-command ({n}j) and buf ends with [1-9]\d*<base>. See
-- docs/adr/0047-adoption-watch-keytrans-rolling-buffer.md for the full approach.
local function buf_matches(cmd, buf)
  local base = cmd:match('^{n}(.+)$')
  if base then
    return buf:match('[1-9]%d*' .. vim.pesc(base) .. '$') ~= nil
  end
  return #buf >= #cmd and buf:sub(-#cmd) == cmd
end

-- Single choke point every do_show call goes through: covers the reactive path
-- (suggest.queue/show with a specific cmd) the same way graph.find_best() covers
-- the proactive path, so ui/float.lua never has to special-case a remapped
-- command itself. The override check also consults is_equivalent_override, not
-- just is_overridden -- see docs/adr/0045-equivalent-override-suppression-exemption.md.
local function should_suppress(cmd)
  local data = logger.get(cmd)
  return graph.is_mastered(data)
    or data.suppressed
    or data.shown >= config.values.max_shown
    or (integrations.is_overridden(cmd) and not integrations.is_equivalent_override(cmd))
end

local function cancel_timer()
  if session.timer then
    session.timer:stop()
    session.timer:close()
    session.timer = nil
  end
end

-- Marks cmd adopted and fires the first-adoption celebration if this is the
-- first time ever. Shared by the single adopt_on_key callback below for
-- every pending watch that matches on a given keystroke.
local function mark_adopted(cmd)
  local first_adoption = not logger.is_celebrated(cmd)
  logger.mark_adopted(cmd)
  if first_adoption then
    logger.mark_celebrated(cmd)
    if M.on_adopt then
      M.on_adopt(cmd)
    end
  end
end

-- Single vim.on_key callback shared by every pending adoption watch, rather
-- than one registration per shown suggestion -- see
-- docs/adr/0111-unified-suggestion-scheduling.md. Each watch still keeps its
-- own independent rolling buffer (session.watches[cmd].buf), so adopting one
-- suggested command still can't interfere with detecting another.
local function adopt_on_key(key, typed)
  if typed == '' then
    return
  end
  local k = vim.fn.keytrans(typed or key)
  for cmd, watch in pairs(session.watches) do
    watch.buf = (watch.buf .. k):sub(-KEY_BUF_MAX)
    if buf_matches(watch.match_target, watch.buf) then
      mark_adopted(cmd)
      session.watches[cmd] = nil
    end
  end
  if next(session.watches) == nil and _adopt_ns then
    vim.on_key(nil, _adopt_ns)
  end
end

-- Watches for the user actually using cmd after it was suggested; see
-- docs/adr/0047-adoption-watch-keytrans-rolling-buffer.md for the detection
-- approach and docs/adr/0111-unified-suggestion-scheduling.md for why this
-- registers into one shared vim.on_key callback instead of one per cmd.
local function watch_adoption(cmd)
  session.watches[cmd] = { buf = '', match_target = normalize_cmd(cmd) }
  if not _adopt_ns then
    _adopt_ns = vim.api.nvim_create_namespace('tobira_adopt')
  end
  vim.on_key(adopt_on_key, _adopt_ns)
end

local function do_show(cmd, focused, pattern)
  if should_suppress(cmd) then
    return false
  end
  local suggestion = graph.suggestions[cmd]
  if not suggestion then
    return false
  end
  logger.mark_shown(cmd)
  watch_adoption(cmd)
  if M.on_show then
    M.on_show(suggestion, focused == true, pattern)
  end
  return true
end

local function over_auto_limit()
  if not session.last_auto_at then
    return false
  end
  local elapsed_s = (vim.loop.now() - session.last_auto_at) / 1000
  return elapsed_s < config.values.suggestion_cooldown
end

-- Entries in the 'terminal' category bypass the global suggestion_cooldown, the
-- same way :Tobira manual already does (see M.manual()); scoped by category, not
-- the literal pattern name, so future 'terminal' entries inherit it automatically.
-- cmd values with no suggestion entry fall through to `false` (no bypass).
-- See docs/adr/0046-terminal-category-cooldown-bypass.md for why.
local function bypasses_cooldown(cmd)
  local suggestion = graph.suggestions[cmd]
  return suggestion ~= nil and suggestion.category == 'terminal'
end

-- Choke point for "is cooldown blocking cmd", shared by M.queue and M.show
-- (queue's deferred M.show re-checks it once idle_delay elapses).
local function cooldown_blocks(cmd)
  return over_auto_limit() and not bypasses_cooldown(cmd)
end

-- Milliseconds left until suggestion_cooldown lifts, given it is currently
-- active (only ever called from resolve_queued while cooldown_blocks(cmd) is
-- true, so session.last_auto_at is guaranteed non-nil here).
local function cooldown_remaining_ms()
  local elapsed_ms = vim.loop.now() - session.last_auto_at
  local remaining = (config.values.suggestion_cooldown * 1000) - elapsed_ms
  return math.max(remaining, 0)
end

local function fire_ambient()
  -- A reactive suggestion is queued (or waiting out a cooldown retry) for
  -- this same idle window -- yield to it instead of racing it. See
  -- docs/adr/0111-unified-suggestion-scheduling.md.
  if session.timer then
    return
  end
  if vim.fn.mode():sub(1, 1) ~= 'n' then
    return
  end
  if over_auto_limit() then
    return
  end
  local usage = logger.get_all()
  local best = graph.find_best(
    usage,
    config.values.max_shown,
    level.ceiling(level.get()),
    integrations.get_overrides(),
    integrations.get_promotions(usage)
  )
  if best then
    M.show(best)
  end
end

-- Start the ambient idle watcher. Called once from init.lua after config is set.
-- Each keypress resets the idle timer; when it fires, show the best suggestion.
function M.setup_idle()
  if not config.values.idle_suggestions then
    return
  end
  if _idle_ns then
    return
  end
  _idle_timer = vim.loop.new_timer()
  _idle_ns = vim.api.nvim_create_namespace('tobira_idle')
  vim.on_key(function(_, typed)
    if typed == '' then
      return
    end
    _idle_timer:stop()
    _idle_timer:start(config.values.idle_delay, 0, vim.schedule_wrap(fire_ambient))
  end, _idle_ns)
end

function M.teardown_idle()
  if _idle_ns then
    vim.on_key(nil, _idle_ns)
    _idle_ns = nil
  end
  if _idle_timer then
    _idle_timer:stop()
    _idle_timer:close()
    _idle_timer = nil
  end
end

-- Resolves a queued reactive suggestion once its idle_delay (or a later
-- cooldown-retry wait) elapses. If suggestion_cooldown from an earlier,
-- unrelated suggestion is still active, re-arms for exactly the remaining
-- cooldown instead of dropping the suggestion -- see
-- docs/adr/0111-unified-suggestion-scheduling.md for why.
local function resolve_queued(pattern, cmd)
  session.timer = nil
  if should_suppress(cmd) then
    return
  end
  if cooldown_blocks(cmd) then
    session.timer = vim.defer_fn(function()
      resolve_queued(pattern, cmd)
    end, cooldown_remaining_ms())
    return
  end
  M.show(cmd, pattern)
end

-- Queues a reactive suggestion to fire after idle_delay. Only the most
-- recent reactive pattern within an unresolved window is kept (cancel_timer
-- below), matching the pre-existing single-pending-suggestion behavior of
-- this mechanism. cooldown is intentionally NOT checked here -- see
-- resolve_queued, which re-checks it once idle_delay elapses and requeues
-- for the remaining cooldown instead of dropping the suggestion outright.
function M.queue(pattern, cmd)
  if should_suppress(cmd) then
    return
  end
  cancel_timer()
  session.timer = vim.defer_fn(function()
    resolve_queued(pattern, cmd)
  end, config.values.idle_delay)
end

-- pattern: the patterns.lua event name that triggered this suggestion, or nil
-- when there is no single triggering event (ambient idle pick, :Tobira manual).
function M.show(cmd, pattern)
  if cooldown_blocks(cmd) then
    return
  end
  if do_show(cmd, false, pattern) then
    session.last_auto_at = vim.loop.now()
  end
end

function M.reset_session()
  cancel_timer()
  if _adopt_ns then
    vim.on_key(nil, _adopt_ns)
  end
  session.last_auto_at = nil
  session.watches = {}
end

function M.manual()
  local usage = logger.get_all()
  local best = graph.find_best(
    usage,
    config.values.max_shown,
    level.ceiling(level.get()),
    integrations.get_overrides(),
    integrations.get_promotions(usage)
  )
  if not best then
    local str = require('tobira.i18n').load()
    vim.notify(str.notifications.no_suggestions, vim.log.levels.INFO)
    return
  end
  do_show(best, true)
end

return M
