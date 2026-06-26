local M = {}

M.defaults = {
  idle_delay = 1500, -- ms to wait after pattern detection before showing suggestion
  max_shown = 3, -- max times to show a suggestion before suppressing
  lang = 'ja', -- reserved for future i18n
}

function M.setup(opts)
  local config = vim.tbl_deep_extend('force', M.defaults, opts or {})

  local ok, err = pcall(vim.validate, {
    idle_delay = { config.idle_delay, 'number' },
    max_shown = { config.max_shown, 'number' },
    lang = { config.lang, 'string' },
  })
  if not ok then
    vim.notify('tobira: invalid config — ' .. err, vim.log.levels.ERROR)
    return
  end

  M.config = config
  require('tobira.core.logger').setup(M.config)
end

return M
