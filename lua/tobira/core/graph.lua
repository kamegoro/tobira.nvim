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
      -- Read by find_best() to apply the stricter "never tried" offer
      -- gate instead of the generic mastery-level gate. Only ever true for
      -- Ex-command suggestions (see commands.lua's 'ex:g' / 'ex:norm').
      ex_command = entry.ex_command == true,
      -- nil (default) means eligible; only `ambient = false` in commands.lua
      -- opts an entry out of find_best()'s candidate pool. The reactive path
      -- (suggest.queue called directly from a pattern module) never reads
      -- this field, so it is unaffected either way — see find_best() below.
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

-- Not user-configurable, consistent with this file's other hardcoded
-- thresholds (100/1000/5000 mastery counts, avg>=5 adoption bar) — these
-- aren't exposed via core/config.lua so there's one fewer thing users need
-- to understand.
local FORGOTTEN_RECENT_WINDOW = 2 -- same recency window the old binary rule used
local FORGOTTEN_ADOPTED_BAR = 5 -- reuses is_adopted's "meaningfully used" bar
local FORGOTTEN_RATIO = 0.3 -- recent avg must fall below 30% of the historical avg

-- True when the command was meaningfully adopted in the past (its average
-- usage before the most recent FORGOTTEN_RECENT_WINDOW sessions reached
-- FORGOTTEN_ADOPTED_BAR) but recent usage has decayed below FORGOTTEN_RATIO
-- of that historical average. Requires at least 3 sessions to be meaningful.
--
-- Graded replacement for the old "last 2 sessions are exactly 0" rule:
-- a command fading from heavy to occasional use is now caught gradually
-- instead of requiring recent usage to hit exactly zero. Uses the average
-- (not the peak) of the historical window so one unusually heavy session
-- doesn't set a bar that makes otherwise-steady usage read as "forgotten".
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
-- Uses is_mastered() (not a raw mastery_level(data) < 2 check) so a command that
-- crossed the mastery threshold but has since gone quiet (is_forgotten) reappears
-- here instead of being permanently excluded.
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
-- overrides: optional table of cmd -> { rhs, equivalent } built by
-- core/integrations.lua, identical in shape to find_best's own `overrides`
-- parameter (see find_best's header comment for the full design -- this
-- mirrors it rather than reinventing it). Any candidate (child) present as a
-- key here is excluded from this pool entirely, regardless of `equivalent` --
-- this function powers :TobiraStats's "Try these next" section, which is
-- exactly as proactive a suggestion as anything find_best offers, so it must
-- honor the same "never suggest a command whose key you've remapped away"
-- rule. graph.lua stays pure/integrations-agnostic either way: this is only
-- ever read as plain data, never required from integrations.lua itself.
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

-- Registers "+y" as a suggestion candidate only when the user has
-- yanked heavily (y count >= REGISTER_UNDERUSE_TRIGGER) but has never once
-- reached for the system-clipboard register. This is intentionally NOT the
-- generic "trigger_count > 0" rule find_best() otherwise uses — that rule
-- would surface "+y after a single y, far too early for a suggestion this
-- different from an ordinary operator/motion pair (switching to a named or
-- system register is a bigger behavioral jump than, say, learning cw). Only
-- the clipboard heuristic is implemented — the issue's "wrong paste" /
-- register-0 heuristics are deferred pending design review (see the issue's
-- own "Phase 2" section).
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
-- overrides: optional table of cmd -> { rhs, equivalent } built by
-- integrations.lua from the user's actual :nmap/:nnoremap state. Any
-- candidate present as a key here is excluded entirely, regardless of
-- `equivalent` — graph.lua only reads this as plain data (no require of
-- integrations.lua, keeping this file pure). Proactively nudging "learn X"
-- is never useful once the user has rebound X's key to something else,
-- equivalent or not — see ui/guide.lua for the one surface where the
-- equivalent/different distinction actually matters.
-- promotions: optional table of cmd -> true built by integrations.lua from
-- detected-plugin + usage-threshold rules. A promoted candidate bypasses the
-- ordinary "trigger_count > 0" gate below (same priority-pool machinery as
-- "+y" above) but still must pass every other gate (mastery/suppression/shown).
function M.find_best(usage, max_shown, max_level, overrides, promotions)
  max_shown = max_shown or 3
  local max_level_num = max_level and (LEVEL_ORDER[max_level] or 3) or 3
  local best_cmd = nil
  -- -math.huge (not -1): a real score can legitimately equal -1 (e.g.
  -- trigger used 5 times, suggested cmd used 6), which used to collide with
  -- this sentinel and let `cmd < best_cmd` run while best_cmd was still nil
  -- -math.huge can never tie a real score, so best_cmd is always
  -- non-nil by the time the tie-break branch is reached.
  local best_score = -math.huge

  -- Register-underuse candidates are collected into their own pool instead of
  -- being folded into best_score via an additive boost. A fixed boost
  -- (previously +1000 added to usage.y.count) can never be "big enough": an
  -- ordinary score (trigger_count - cmd_count) grows with the raw trigger
  -- count, which for a real long-term user routinely reaches the thousands —
  -- no constant outraces an unbounded competitor. A separate pool, falling
  -- back to the ordinary one only when empty, makes "qualified always wins"
  -- true by construction, not arithmetic.
  local best_priority_cmd = nil
  local best_priority_score = -math.huge

  for cmd, sug in pairs(M.suggestions) do
    local cmd_level_num = LEVEL_ORDER[sug.level] or 1
    -- Entries marked ambient = false (reactive-only, e.g. the
    -- terminal-mode exit suggestion) are never proactive candidates here —
    -- they only ever reach the user via suggest.queue() called directly
    -- from a pattern module, which does not go through find_best.
    -- Entries whose own key is remapped (overrides[cmd] ~= nil) are
    -- excluded the same way -- see this function's header comment.
    local overridden = overrides and overrides[cmd] ~= nil
    if cmd_level_num <= max_level_num and sug.ambient ~= false and not overridden then
      local data = usage[cmd] or { count = 0, sessions = {}, shown = 0, suppressed = false }

      -- Ex-command suggestions use a stricter "never tried at all" gate
      -- instead of the generic mastery-level gate (count < 100) — a single
      -- :g or :norm already does the work of many ordinary keystrokes, so
      -- unlike e.g. cw (fine to keep nudging below 100 uses), continuing to
      -- suggest one of these after even one real use would read as ignoring
      -- feedback rather than teaching.
      local not_yet_known = sug.ex_command and data.count == 0 or (not sug.ex_command and not M.is_mastered(data))
      local offered = not_yet_known and not data.suppressed and data.shown < max_shown

      if offered and cmd == '"+y' then
        -- Register-underuse gate replaces the generic trigger_count > 0
        -- rule below — see is_register_underused() and the priority-pool
        -- comment above.
        if M.is_register_underused(usage) then
          local score = usage.y.count
          if score > best_priority_score or (score == best_priority_score and cmd < best_priority_cmd) then
            best_priority_score = score
            best_priority_cmd = cmd
          end
        end
      elseif offered and promotions and promotions[cmd] then
        -- Same priority-pool mechanism as "+y" above -- a
        -- promoted candidate already has independently-verified usage
        -- evidence (integrations.lua's own threshold check), so it bypasses
        -- the ordinary trigger_count > 0 requirement just below.
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
