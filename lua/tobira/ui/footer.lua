-- Shared keybinding footer for the interactive panels (progress, stats).
-- Renders keys in the accent colour and labels dimmed, with no brackets, so
-- the footer reads the same way as the skill grid's key/label contrast. Used as
-- nvim_open_win's `footer` so it stays pinned to the window border instead of
-- scrolling away inside the buffer.
local M = {}

-- items: ordered list of { key, label } pairs, labels already localized. Order
-- is the caller's responsibility (never pairs(), which is non-deterministic).
-- Returns (chunks, width): the footer chunk list and its total display width so
-- the window can be sized to fit it.
function M.build(items)
  local chunks = { { ' ', 'TobiraGuideHint' } }
  for i, item in ipairs(items) do
    table.insert(chunks, { item[1], 'TobiraGuideKey' })
    table.insert(chunks, { ' ' .. item[2], 'TobiraGuideHint' })
    if i < #items then
      table.insert(chunks, { '    ', 'TobiraGuideHint' })
    end
  end
  table.insert(chunks, { ' ', 'TobiraGuideHint' })

  local width = 0
  for _, c in ipairs(chunks) do
    width = width + vim.fn.strdisplaywidth(c[1])
  end
  return chunks, width
end

return M
