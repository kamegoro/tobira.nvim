-- Pure Lua. No vim.* calls. Converts a sessions[] usage-count array into a
-- Unicode sparkline string for the Progress preview strip (#67).
local M = {}

local BARS = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }

-- Renders up to the last `width` entries of `sessions` as a sparkline, scaled
-- to the max within that visible window (not a global max) so an old spike
-- doesn't flatten recent, smaller-but-still-real activity into near-zero bars.
function M.render(sessions, width)
  if #sessions == 0 then
    return string.rep(' ', width)
  end

  local visible = {}
  local start = math.max(1, #sessions - width + 1)
  for i = start, #sessions do
    table.insert(visible, sessions[i])
  end

  local max = 0
  for _, v in ipairs(visible) do
    max = math.max(max, v)
  end

  local chars = {}
  for _, v in ipairs(visible) do
    if max == 0 then
      table.insert(chars, BARS[1])
    else
      local idx = math.max(1, math.ceil(v / max * #BARS))
      table.insert(chars, BARS[idx])
    end
  end

  return table.concat(chars)
end

return M
