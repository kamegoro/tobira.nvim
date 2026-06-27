local M = {}

function M.show(suggestion)
  local msg = suggestion.body
  if suggestion.example and suggestion.example ~= '' then
    msg = msg .. '\n\ne.g. ' .. suggestion.example
  end

  vim.notify(msg, vim.log.levels.INFO, {
    title = 'tobira / ' .. suggestion.title,
    timeout = 10000,
  })
end

return M
