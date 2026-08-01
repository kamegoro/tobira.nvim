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
      -- see docs/adr/0010-ex-command-never-tried-gate.md for why
      ex_command = entry.ex_command == true,
      -- nil (default) means eligible. See docs/adr/0007-reactive-only-ambient-exclusion.md
      ambient = entry.ambient,
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

-- Hardcoded, not exposed via core/config.lua (same as this file's other
-- thresholds). See docs/adr/0029-graded-forgotten-command-detection.md for why.
local FORGOTTEN_RECENT_WINDOW = 2
local FORGOTTEN_ADOPTED_BAR = 5
local FORGOTTEN_RATIO = 0.3

-- True when historical avg usage (all sessions before the last
-- FORGOTTEN_RECENT_WINDOW) reached FORGOTTEN_ADOPTED_BAR but recent avg has
-- decayed below FORGOTTEN_RATIO of it. Requires >= 3 sessions.
-- see docs/adr/0029-graded-forgotten-command-detection.md for why
function M.is_forgotten(data)
  local sessions = data.sessions or {}
  local n = #sessions
  if n < 3 then
    return false
  end
  local historical_slice = {}
  for i = 1, n - FORGOTTEN_RECENT_WINDOW do
    historical_slice[i] = sessions[i]
  end
  local historical = avg_last_n(historical_slice, #historical_slice)
  if historical < FORGOTTEN_ADOPTED_BAR then
    return false
  end
  local recent = avg_last_n(sessions, FORGOTTEN_RECENT_WINDOW)
  return recent < historical * FORGOTTEN_RATIO
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
-- Commands within each category are sorted alphabetically for determinism.
-- Uses is_mastered(), not a raw mastery_level(data) < 2 check —
-- see docs/adr/0029-graded-forgotten-command-detection.md for why
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
-- overrides: same shape and exclusion rule as find_best's `overrides` param —
-- see docs/adr/0030-keymap-override-exclusion-contract.md for why
function M.efficiency_gaps(usage, limit, overrides)
  local cmds = require('tobira.commands')
  local gaps = {}
  for cmd, entry in pairs(cmds.registry) do
    local overridden = overrides and overrides[cmd] ~= nil
    if not entry.compound and entry.requires and not overridden then
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

-- Only the y/"+y clipboard heuristic is implemented (not "wrong paste" or
-- register-0). See docs/adr/0031-priority-pool-for-gate-bypassing-candidates.md for why
local REGISTER_UNDERUSE_TRIGGER = 20

-- True once the user has yanked (y) at least REGISTER_UNDERUSE_TRIGGER times
-- and has never used the system-clipboard register ("+y count == 0).
function M.is_register_underused(usage)
  local y_count = (usage.y and usage.y.count) or 0
  local clip_data = usage['"+y']
  local clip_count = (clip_data and clip_data.count) or 0
  return y_count >= REGISTER_UNDERUSE_TRIGGER and clip_count == 0
end

-- max_level: 'beginner' | 'intermediate' | 'advanced' | nil (no filter)
-- overrides: table of cmd -> { rhs, equivalent } built by integrations.lua.
-- see docs/adr/0030-keymap-override-exclusion-contract.md for why
-- promotions: table of cmd -> true built by integrations.lua; bypasses the
-- trigger_count > 0 gate below via the same priority pool as "+y" (still
-- subject to every other gate). see docs/adr/0031-priority-pool-for-gate-bypassing-candidates.md
function M.find_best(usage, max_shown, max_level, overrides, promotions)
  max_shown = max_shown or 3
  local max_level_num = max_level and (LEVEL_ORDER[max_level] or 3) or 3
  local best_cmd = nil
  -- -math.huge, not -1: see docs/adr/0032-find-best-sentinel-negative-infinity.md for why
  local best_score = -math.huge

  -- Separate pool for candidates that bypass the trigger_count > 0 gate below.
  -- see docs/adr/0031-priority-pool-for-gate-bypassing-candidates.md for why
  local best_priority_cmd = nil
  local best_priority_score = -math.huge

  for cmd, sug in pairs(M.suggestions) do
    local cmd_level_num = LEVEL_ORDER[sug.level] or 1
    -- ambient = false: see docs/adr/0007-reactive-only-ambient-exclusion.md
    -- overridden: see docs/adr/0030-keymap-override-exclusion-contract.md
    local overridden = overrides and overrides[cmd] ~= nil
    if cmd_level_num <= max_level_num and sug.ambient ~= false and not overridden then
      local data = usage[cmd] or { count = 0, sessions = {}, shown = 0, suppressed = false }

      -- see docs/adr/0010-ex-command-never-tried-gate.md for why ex_command uses a
      -- different gate than the generic mastery-level check
      local not_yet_known = sug.ex_command and data.count == 0 or (not sug.ex_command and not M.is_mastered(data))
      local offered = not_yet_known and not data.suppressed and data.shown < max_shown

      if offered and cmd == '"+y' then
        -- see docs/adr/0031-priority-pool-for-gate-bypassing-candidates.md for why
        if M.is_register_underused(usage) then
          local score = usage.y.count
          if score > best_priority_score or (score == best_priority_score and cmd < best_priority_cmd) then
            best_priority_score = score
            best_priority_cmd = cmd
          end
        end
      elseif offered and promotions and promotions[cmd] then
        -- see docs/adr/0031-priority-pool-for-gate-bypassing-candidates.md for why
        local score = (usage[sug.trigger] and usage[sug.trigger].count) or 0
        if score > best_priority_score or (score == best_priority_score and cmd < best_priority_cmd) then
          best_priority_score = score
          best_priority_cmd = cmd
        end
      elseif offered then
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

  if best_priority_cmd then
    return best_priority_cmd
  end

  return best_cmd
end

return M
