local M = {}

M.defaults = {
  idle_delay = 1500,   -- パターン検出後、何ms後に表示するか
  max_shown = 3,       -- 同じ提案を最大何回まで表示するか
  lang = "ja",         -- 将来の多言語対応用
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  require("tobira.core.logger").setup(M.config)
end

return M
