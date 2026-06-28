-- Pure Lua. No vim.* calls.
-- suggestions is derived at load time from commands.registry.
-- Display strings (title / body / example) are NOT stored here —
-- they live in locales/ and are looked up at display time by float.lua / progress.lua.
-- To add a new suggestion, edit lua/tobira/commands.lua and lua/tobira/locales/.

local commands = require('tobira.commands')

local M = {}

M.suggestions = {}

for cmd, entry in pairs(commands.registry) do
  if not entry.compound then
    M.suggestions[cmd] = {
      cmd     = cmd,
      trigger = entry.requires,
    }
  end
end

function M.find_best(usage, max_shown)
  max_shown = max_shown or 3
  local best_cmd = nil
  local best_score = -1

  for cmd, sug in pairs(M.suggestions) do
    local data = usage[cmd] or { count = 0, shown = 0, adopted = false }

    if not data.adopted and data.shown < max_shown then
      local trigger_count = (usage[sug.trigger] and usage[sug.trigger].count) or 0
      local cmd_count = data.count

      if trigger_count > 0 then
        local score = trigger_count - cmd_count
        if score > best_score then
          best_score = score
          best_cmd = cmd
        end
      end
    end
  end

  return best_cmd
end

return M
