local graph = require('tobira.core.graph')

local M = {}

local function cnt(usage, keys)
  local total = 0
  for _, k in ipairs(keys) do
    total = total + ((usage[k] and usage[k].count) or 0)
  end
  return total
end

-- Returns 'novice' | 'beginner' | 'intermediate' | 'advanced'
-- based on accumulated usage counts — no user input required.
-- Accepts an optional usage table; falls back to logger.get_all() if omitted.
function M.get(usage)
  usage = usage or require('tobira.core.logger').get_all()

  -- Advanced: knows ;/, or cgn (sophisticated repeat techniques)
  local semi_count = cnt(usage, { ';', ',' })
  local cgn_adopted = usage['cgn'] and graph.is_adopted(usage['cgn'])
  if semi_count >= 3 or cgn_adopted then
    return 'advanced'
  end

  -- Intermediate: actively uses f/t or word motions
  local f_count = cnt(usage, { 'f', 'F' })
  local wb_count = cnt(usage, { 'w', 'b' })
  if f_count >= 5 or wb_count >= 20 then
    return 'intermediate'
  end

  -- Beginner: uses hjkl navigation
  if cnt(usage, { 'h', 'j', 'k', 'l' }) >= 10 then
    return 'beginner'
  end

  return 'novice'
end

return M
