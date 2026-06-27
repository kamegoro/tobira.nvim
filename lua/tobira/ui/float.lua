local M = {}

function M.show(suggestion)
  local str = require('tobira.i18n').load()
  local msg = suggestion.body
  if suggestion.example and suggestion.example ~= '' then
    msg = msg .. '\n\n' .. str.float.example_prefix .. suggestion.example
  end

  vim.notify(msg, vim.log.levels.INFO, {
    title = 'tobira / ' .. suggestion.title,
    timeout = 10000,
  })
end

return M
