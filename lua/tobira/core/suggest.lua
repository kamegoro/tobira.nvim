local config = require('tobira.core.config')
local logger = require('tobira.core.logger')
local graph = require('tobira.core.graph')

local M = {}

local session = {
  shown = false,
  timer = nil,
  watching_ns = {},
}

local function should_suppress(cmd)
  local data = logger.get(cmd)
  return graph.is_adopted(data) or data.suppressed or data.shown >= config.values.max_shown
end

local function cancel_timer()
  if session.timer then
    session.timer:stop()
    session.timer:close()
    session.timer = nil
  end
end

local function watch_adoption(cmd)
  local ns = vim.api.nvim_create_namespace('tobira_adopt_' .. cmd)
  session.watching_ns[cmd] = ns
  vim.on_key(function(key, typed)
    local k = (typed ~= nil and typed ~= '') and typed or key
    if k == cmd then
      logger.mark_adopted(cmd)
      session.watching_ns[cmd] = nil
      vim.on_key(nil, ns)
    end
  end, ns)
end

function M.queue(_, cmd)
  if session.shown then
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
  if session.shown then
    return
  end
  if should_suppress(cmd) then
    return
  end

  local suggestion = graph.suggestions[cmd]
  if not suggestion then
    return
  end

  logger.mark_shown(cmd)
  session.shown = true
  watch_adoption(cmd)
  require('tobira.ui.float').show(suggestion)
end

function M.reset_session()
  cancel_timer()
  for _, ns in pairs(session.watching_ns) do
    vim.on_key(nil, ns)
  end
  session.shown = false
  session.watching = {}
  session.watching_ns = {}
end

function M.manual()
  local best = graph.find_best(logger.get_all(), config.values.max_shown)
  if not best then
    local str = require('tobira.i18n').load()
    vim.notify(str.notifications.no_suggestions, vim.log.levels.INFO)
    return
  end
  session.shown = false
  M.show(best)
end

return M
