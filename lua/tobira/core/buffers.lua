-- Which buffers are not user editing, so their keystrokes are not counted and
-- no automatic suggestion is shown over them. See
-- docs/adr/0124-ignore-keys-in-non-editing-buffers.md.
local M = {}

-- Ignored only while not modifiable: a modifiable buffer of these types is
-- being edited (scratch buffers, the cmdline window, editable quickfix lists).
local READ_ONLY_TYPES = { nofile = true, help = true, quickfix = true }

function M.is_ignored(buf)
  local buftype = vim.bo[buf].buftype
  if buftype == 'prompt' then
    return true
  end
  return READ_ONLY_TYPES[buftype] == true and not vim.bo[buf].modifiable
end

return M
