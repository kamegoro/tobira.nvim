local M = {}

-- Pre-require to avoid require() calls in hot paths
local logger = nil
local graph = nil
local float = nil

local session = {
  shown = false, -- already shown once this session
  timer = nil, -- pending display timer
  watching = {}, -- cmds currently being watched for adoption
}

local function get_logger()
  logger = logger or require('tobira.core.logger')
  return logger
end

local function get_graph()
  graph = graph or require('tobira.core.graph')
  return graph
end

local function get_float()
  float = float or require('tobira.ui.float')
  return float
end

local function should_suppress(cmd)
  local data = get_logger().get(cmd)
  return data.adopted or data.shown >= 3
end

-- Watch if the user actually uses a suggested command after seeing it.
-- If they do → mark adopted (never show again).
local function watch_adoption(cmd)
  if session.watching[cmd] then
    return
  end
  session.watching[cmd] = true

  local ns = vim.api.nvim_create_namespace('tobira_adopt_' .. cmd)
  vim.on_key(function(key, typed)
    local k = (typed ~= nil and typed ~= '') and typed or key
    if k == cmd then
      get_logger().mark_adopted(cmd)
      session.watching[cmd] = nil
      vim.on_key(nil, ns)
    end
  end, ns)
end

-- Called by logger when a missed-opportunity pattern is detected.
-- Waits for an idle moment before showing to avoid interrupting flow.
function M.queue(pattern_id, cmd)
  if session.shown then
    return
  end
  if should_suppress(cmd) then
    return
  end

  if session.timer then
    pcall(function()
      session.timer:stop()
    end)
    session.timer = nil
  end

  session.timer = vim.defer_fn(function()
    session.timer = nil
    M.show(cmd)
  end, 1500)
end

function M.show(cmd)
  if session.shown then
    return
  end

  local suggestion = get_graph().suggestions[cmd]
  if not suggestion then
    return
  end

  get_logger().mark_shown(cmd)
  session.shown = true
  watch_adoption(cmd)
  get_float().show(suggestion)
end

-- :Tobira — manual trigger, bypasses session limit
function M.manual()
  local best = get_graph().find_best(get_logger().get_all())
  if not best then
    vim.notify('tobira: no new suggestions right now 🎉', vim.log.levels.INFO)
    return
  end
  session.shown = false
  M.show(best)
end

return M
