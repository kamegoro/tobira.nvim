local M = {}

M.defaults = {
  frequency = "session", -- "session" | "save" | "manual"
  level = "auto",        -- "auto" | "beginner" | "intermediate" | "advanced"
  lang = "ja",           -- "ja" | "en"
  max_per_session = 1,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  require("tobira.core.logger").setup(M.config)
end

return M
