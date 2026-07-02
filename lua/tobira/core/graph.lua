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
      category = entry.category,
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

-- True when the command is mastered (mastery_level ≥ 2) and not forgotten.
-- Centralises the "skip this from suggestions" decision; callers must not
-- inline mastery_level(data) >= 2 checks.
function M.is_mastered(data)
  return M.mastery_level(data) >= 2 and not M.is_forgotten(data)
end

-- Returns 0-4 mastery level based on cumulative usage count.
-- 0 = never used, 1 = ☆ (≥1), 2 = ★ (≥100), 3 = ★★ (≥1000), 4 = ★★★ (≥5000)
function M.mastery_level(data)
  local c = data.count or 0
  if c >= 5000 then
    return 4
  end
  if c >= 1000 then
    return 3
  end
  if c >= 100 then
    return 2
  end
  if c > 0 then
    return 1
  end
  return 0
end

-- Returns unmastered-or-forgotten commands grouped by category for the Guide panel.
-- Ceiling level = lowest level that still has commands with is_mastered(data) == false.
-- Uses is_mastered() (not a raw mastery_level(data) < 2 check) so a command that
-- crossed the mastery threshold but has since gone quiet (is_forgotten) reappears
-- here instead of being permanently excluded — see #68.
-- Commands within each category are sorted alphabetically for determinism.
function M.guide_commands(usage)
  local cmds = require('tobira.commands')

  local unmastered = { beginner = 0, intermediate = 0, advanced = 0 }
  for cmd, entry in pairs(cmds.registry) do
    if not entry.compound then
      local lv = entry.level or 'beginner'
      local data = usage[cmd] or { count = 0 }
      if not M.is_mastered(data) then
        unmastered[lv] = (unmastered[lv] or 0) + 1
      end
    end
  end

  local ceiling
  if unmastered.beginner > 0 then
    ceiling = 1
  elseif unmastered.intermediate > 0 then
    ceiling = 2
  else
    ceiling = 3
  end

  local by_cat = {}
  for cmd, entry in pairs(cmds.registry) do
    if not entry.compound and (LEVEL_ORDER[entry.level] or 1) <= ceiling then
      local data = usage[cmd] or { count = 0 }
      if not M.is_mastered(data) then
        local cat = entry.category or 'motion'
        if not by_cat[cat] then
          by_cat[cat] = {}
        end
        table.insert(by_cat[cat], cmd)
      end
    end
  end

  for _, list in pairs(by_cat) do
    table.sort(list)
  end

  return by_cat
end

-- Returns knowledge distribution across all non-compound commands.
-- Buckets: never (level 0), tried (1), familiar (2), mastered (3-4).
function M.knowledge_dist(usage)
  local cmds = require('tobira.commands')
  local dist = { never = 0, tried = 0, familiar = 0, mastered = 0 }
  for cmd, entry in pairs(cmds.registry) do
    if not entry.compound then
      local data = usage[cmd] or { count = 0 }
      local lv = M.mastery_level(data)
      if lv == 0 then
        dist.never = dist.never + 1
      elseif lv == 1 then
        dist.tried = dist.tried + 1
      elseif lv == 2 then
        dist.familiar = dist.familiar + 1
      else
        dist.mastered = dist.mastered + 1
      end
    end
  end
  return dist
end

-- Returns pairs where the trigger (requires) is used heavily but the suggestion
-- is rarely or never used, sorted by ratio descending.
-- Only includes pairs where trigger count >= 50 and child mastery_level < 2.
-- limit: optional cap on returned results.
function M.efficiency_gaps(usage, limit)
  local cmds = require('tobira.commands')
  local gaps = {}
  for cmd, entry in pairs(cmds.registry) do
    if not entry.compound and entry.requires then
      local parent = entry.requires
      local parent_data = usage[parent] or { count = 0 }
      local child_data = usage[cmd] or { count = 0 }
      if parent_data.count >= 50 and M.mastery_level(child_data) < 2 then
        local ratio = math.floor(parent_data.count / math.max(child_data.count, 1))
        if ratio >= 5 then
          table.insert(gaps, {
            parent = parent,
            child = cmd,
            parent_count = parent_data.count,
            child_count = child_data.count,
            ratio = ratio,
          })
        end
      end
    end
  end
  table.sort(gaps, function(a, b)
    if a.ratio ~= b.ratio then
      return a.ratio > b.ratio
    end
    return a.child < b.child
  end)
  if limit then
    local trimmed = {}
    for i = 1, math.min(limit, #gaps) do
      trimmed[i] = gaps[i]
    end
    return trimmed
  end
  return gaps
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

      local mastered = M.is_mastered(data)
      local offered = not mastered and not data.suppressed and data.shown < max_shown

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
