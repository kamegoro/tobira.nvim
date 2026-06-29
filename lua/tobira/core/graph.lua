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
      cmd = cmd,
      trigger = entry.requires,
      level = entry.level,
    }
  end
end

local LEVEL_ORDER = { beginner = 1, intermediate = 2, advanced = 3 }

-- Average of the last n elements in sessions (or all if fewer than n).
local function avg_last_n(sessions, n)
  local len = #sessions
  if len == 0 then
    return 0
  end
  local k = math.min(n, len)
  local sum = 0
  for i = len - k + 1, len do
    sum = sum + sessions[i]
  end
  return sum / k
end

-- True when the user regularly uses this command (avg of last 3 sessions ≥ 5).
function M.is_adopted(data)
  return avg_last_n(data.sessions or {}, 3) >= 5
end

-- True when the command was once adopted but the last 2 sessions are 0 (forgot it).
-- Requires at least 3 sessions in history to be meaningful.
function M.is_forgotten(data)
  local sessions = data.sessions or {}
  local len = #sessions
  if len < 3 then
    return false
  end
  if sessions[len] ~= 0 or sessions[len - 1] ~= 0 then
    return false
  end
  for i = 1, len - 2 do
    if sessions[i] >= 5 then
      return true
    end
  end
  return false
end

-- Returns 0-4 mastery level based on recent session activity.
-- 0 = never used, 1 = ☆ started, 2 = ★, 3 = ★★, 4 = ★★★ (adopted)
function M.mastery_level(data)
  if data.count == 0 then
    return 0
  end
  local avg = avg_last_n(data.sessions or {}, 3)
  if avg >= 5 then
    return 4
  end
  if avg >= 3 then
    return 3
  end
  if avg >= 1 then
    return 2
  end
  return 1
end

-- max_level: 'beginner' | 'intermediate' | 'advanced' | nil (no filter)
function M.find_best(usage, max_shown, max_level)
  max_shown = max_shown or 3
  local max_level_num = max_level and (LEVEL_ORDER[max_level] or 3) or 3
  local best_cmd = nil
  local best_score = -1

  for cmd, sug in pairs(M.suggestions) do
    local cmd_level_num = LEVEL_ORDER[sug.level] or 1
    if cmd_level_num <= max_level_num then
      local data = usage[cmd] or { count = 0, sessions = {}, shown = 0, suppressed = false }

      local suppressed = data.suppressed or false
      local offered = (not M.is_adopted(data) or M.is_forgotten(data)) and not suppressed and data.shown < max_shown

      if offered then
        local trigger_count = (usage[sug.trigger] and usage[sug.trigger].count) or 0
        local cmd_count = data.count

        if trigger_count > 0 then
          local score = trigger_count - cmd_count
          if score > best_score or (score == best_score and cmd < best_cmd) then
            best_score = score
            best_cmd = cmd
          end
        end
      end
    end
  end

  return best_cmd
end

return M
