local config = require('tobira.core.config')
local logger = require('tobira.core.logger')
local graph = require('tobira.core.graph')

local M = {}

local session = {
  last_auto_at = nil,
  timer = nil,
  watching_ns = {},
}

local _idle_timer = nil
local _idle_ns = nil

local KEY_BUF_MAX = 20

local LEVEL_UP = { novice = 'beginner', beginner = 'intermediate', intermediate = 'advanced', advanced = 'advanced' }

-- Normalise <C-x> / <M-x> style command strings to the form keytrans() returns,
-- so suffix matching works regardless of capitalisation in commands.lua.
-- e.g. '<C-r>' → '\x12' → '<C-R>'  (keytrans always uppercases the letter)
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

-- True when buf ends with the literal command string (post-normalisation), or
-- when cmd is a count-prefix meta-command ({n}j / {n}x) and buf ends with
-- [1-9]\d*<effective-base>.  The effective base is resolved through
-- vim.fn.maparg so that user remaps like j→gj are handled transparently.
-- Inspired by hardtime.nvim's rolling-buffer approach (MIT).
local function buf_matches(cmd, buf)
  local base = cmd:match('^{n}(.+)$')
  if base then
    local mapped = vim.fn.maparg(base, 'n')
    local target = (mapped ~= '') and mapped or base
    return buf:match('[1-9]%d*' .. vim.pesc(target) .. '$') ~= nil
  end
  return #buf >= #cmd and buf:sub(-#cmd) == cmd
end

local function should_suppress(cmd)
  local data = logger.get(cmd)
  local mastered = graph.mastery_level(data) >= 2 and not graph.is_forgotten(data)
  return mastered or data.suppressed or data.shown >= config.values.max_shown
end

local function cancel_timer()
  if session.timer then
    session.timer:stop()
    session.timer:close()
    session.timer = nil
  end
end

-- Watch for the user actually using cmd after it was suggested.
-- Uses vim.fn.keytrans() to normalise raw bytes (e.g. \x12 → "<C-R>"),
-- accumulates a per-watcher rolling buffer, and checks suffix / pattern match —
-- so multi-char sequences like cw, ddp, <C-r>, {n}j all resolve correctly.
-- Each watcher owns an independent closure-local buf to avoid shared state.
local function watch_adoption(cmd)
  local ns = vim.api.nvim_create_namespace('tobira_adopt_' .. cmd)
  session.watching_ns[cmd] = ns
  local match_target = normalize_cmd(cmd)
  local buf = ''
  vim.on_key(function(key, typed)
    local raw = (typed ~= nil and typed ~= '') and typed or key
    local k = vim.fn.keytrans(raw)
    buf = (buf .. k):sub(-KEY_BUF_MAX)
    if buf_matches(match_target, buf) then
      logger.mark_adopted(cmd)
      session.watching_ns[cmd] = nil
      vim.on_key(nil, ns)
    end
  end, ns)
end

local function do_show(cmd)
  if should_suppress(cmd) then
    return false
  end
  local suggestion = graph.suggestions[cmd]
  if not suggestion then
    return false
  end
  logger.mark_shown(cmd)
  watch_adoption(cmd)
  require('tobira.ui.float').show(suggestion)
  return true
end

local function over_auto_limit()
  if not session.last_auto_at then
    return false
  end
  local elapsed_s = (vim.loop.now() - session.last_auto_at) / 1000
  return elapsed_s < config.values.suggestion_cooldown
end

local function fire_ambient()
  if vim.fn.mode():sub(1, 1) ~= 'n' then
    return
  end
  if over_auto_limit() then
    return
  end
  local level = require('tobira.core.level')
  local max_lv = LEVEL_UP[level.get()] or 'advanced'
  local best = graph.find_best(logger.get_all(), config.values.max_shown, max_lv)
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
  vim.on_key(function()
    if not _idle_timer then
      return
    end
    _idle_timer:stop()
    _idle_timer:start(config.values.idle_delay, 0, vim.schedule_wrap(fire_ambient))
  end, _idle_ns)
end

function M.teardown_idle()
  if _idle_timer then
    _idle_timer:stop()
    _idle_timer:close()
    _idle_timer = nil
  end
  if _idle_ns then
    vim.on_key(nil, _idle_ns)
    _idle_ns = nil
  end
end

function M.queue(_, cmd)
  if over_auto_limit() then
    return
  end
  if should_suppress(cmd) then
    return
  end
  cancel_timer()
  session.timer = vim.defer_fn(function()
    session.timer = nil
    M.show(cmd)
  end, config.values.idle_delay)
end

function M.show(cmd)
  if over_auto_limit() then
    return
  end
  if do_show(cmd) then
    session.last_auto_at = vim.loop.now()
  end
end

function M.reset_session()
  cancel_timer()
  for _, ns in pairs(session.watching_ns) do
    vim.on_key(nil, ns)
  end
  session.last_auto_at = nil
  session.watching_ns = {}
end

function M.manual()
  local level = require('tobira.core.level')
  local max_lv = LEVEL_UP[level.get()] or 'advanced'
  local best = graph.find_best(logger.get_all(), config.values.max_shown, max_lv)
  if not best then
    local str = require('tobira.i18n').load()
    vim.notify(str.notifications.no_suggestions, vim.log.levels.INFO)
    return
  end
  do_show(best)
end

return M
