local M = {}

function M.show(suggestion)
  local str = require('tobira.i18n').load()
  local sug_str = str.suggestions and str.suggestions[suggestion.cmd]
  if not sug_str then
    return
  end

  local msg = sug_str.body
  if sug_str.example and sug_str.example ~= '' then
    msg = msg .. '\n\n' .. str.float.example_prefix .. sug_str.example
  end

  vim.notify(msg, vim.log.levels.INFO, {
    title = 'tobira / ' .. sug_str.title,
    timeout = 10000,
  })
end

return M
