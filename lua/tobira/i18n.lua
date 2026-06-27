local M = {}

function M.load()
  local lang = require('tobira.core.config').values.lang
  local ok, loc = pcall(require, 'tobira.locales.' .. lang)
  return ok and loc or require('tobira.locales.en')
end

return M
