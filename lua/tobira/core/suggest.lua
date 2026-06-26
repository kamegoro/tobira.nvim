local M = {}

local session = {
  shown = false,   -- このセッションで既に表示済み
  timer = nil,     -- 表示待ちタイマー
  watching = {},   -- 採用確認中のコマンド
}

-- 提案を表示すべきか判定
local function should_suppress(cmd)
  local logger = require("tobira.core.logger")
  local data = logger.get(cmd)
  return data.adopted or data.shown >= 3
end

-- 提案コマンドの採用を監視する
-- ユーザーが実際にそのコマンドを使ったら「習得」と判定
local function watch_adoption(cmd)
  if session.watching[cmd] then return end
  session.watching[cmd] = true

  local ns = vim.api.nvim_create_namespace("tobira_adopt_" .. cmd)
  vim.on_key(function(key, typed)
    local k = (typed ~= nil and typed ~= "") and typed or key
    if k == cmd then
      local logger = require("tobira.core.logger")
      logger.mark_adopted(cmd)
      session.watching[cmd] = nil
      -- 監視を解除
      vim.on_key(nil, ns)
    end
  end, ns)
end

-- パターン検出後に呼ばれる
-- 1500ms のアイドル後に表示する（作業を中断しない）
function M.queue(pattern_id, cmd)
  if session.shown then return end
  if should_suppress(cmd) then return end

  -- 既存タイマーがあればリセット
  if session.timer then
    pcall(function() session.timer:stop() end)
    session.timer = nil
  end

  session.timer = vim.defer_fn(function()
    session.timer = nil
    M.show(cmd)
  end, 1500)
end

-- 実際に表示する
function M.show(cmd)
  if session.shown then return end

  local graph = require("tobira.core.graph")
  local suggestion = graph.suggestions[cmd]
  if not suggestion then return end

  local logger = require("tobira.core.logger")
  logger.mark_shown(cmd)

  session.shown = true
  watch_adoption(cmd)

  require("tobira.ui.float").show(suggestion)
end

-- :Tobira コマンドから手動で呼ぶ
function M.manual()
  local logger = require("tobira.core.logger")
  local graph = require("tobira.core.graph")

  local best = graph.find_best(logger.get_all())
  if not best then
    vim.notify("tobira: 現時点で新しい提案はありません 🎉", vim.log.levels.INFO)
    return
  end

  -- 手動呼び出しはセッション制限をリセット
  session.shown = false
  M.show(best)
end

return M
