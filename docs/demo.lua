-- Sample file used in the tobira.nvim demo
-- This file is opened in Neovim during recording.

local function find_user(id, fallback)
  if id == nil then
    return fallback
  end
  for _, user in ipairs(users) do
    if user.id == id then
      return user
    end
  end
  return fallback
end

local function format_name(first, family)
  return first .. ' ' .. family
end

return { find_user = find_user, format_name = format_name }
