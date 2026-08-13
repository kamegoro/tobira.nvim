-- Deterministic, realistic-scale usage.json fixture generator for the
-- regression suite in tests/regression/realistic_scale_spec.lua.
--
-- Why this exists: several real bugs (#290, #291, #292, #307) only manifested
-- against realistic accumulated scale (hundreds of commands' worth of usage)
-- or duration (10+ simulated session boundaries) -- the thin, hand-picked
-- fixtures used in individual pattern PRs (graph_spec.lua etc.) structurally
-- cannot reproduce that. See issue #317 / the #315 umbrella for the full
-- rationale.
--
-- Pure Lua, no vim.* calls -- same "vim.*-free" shape as core/graph.lua,
-- so this file can be required from a plain Lua unit-test context.
--
-- Deliberately NOT a static committed JSON blob: it reads
-- tobira.commands.registry directly, so the fixture automatically grows/
-- shrinks as the real command registry changes -- nothing here hardcodes a
-- command name that could drift out of sync with commands.lua.

local commands = require('tobira.commands')

local M = {}

-- ── Deterministic PRNG ───────────────────────────────────────────────────────
--
-- A plain Lehmer/MINSTD linear congruential generator (multiplier 16807,
-- modulus 2^31-1), not math.randomseed/math.random. Those are
-- implementation-defined across Lua 5.1/LuaJIT and are not required to
-- produce the same sequence for the same seed on every platform -- exactly
-- the non-determinism CLAUDE.md's "pairs() iteration order is never
-- asserted" rule warns about elsewhere in this codebase. This LCG only uses
-- plain float multiplication/modulo well within double precision (max
-- intermediate ~3.6e13, far below the 2^53 exact-integer boundary), so it is
-- bit-for-bit identical on macOS and Ubuntu CI alike.
local function new_rng(seed)
  local state = seed % 2147483647
  if state <= 0 then
    state = state + 2147483646
  end
  return function()
    state = (state * 16807) % 2147483647
    return state / 2147483647
  end
end
M.new_rng = new_rng

-- Every non-compound command in the registry, sorted alphabetically so
-- fixture generation never depends on pairs()'s undefined iteration order
-- (see tests/CLAUDE.md).
function M.registry_commands()
  local list = {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound then
      table.insert(list, cmd)
    end
  end
  table.sort(list)
  return list
end

-- All non-compound commands whose `requires` equals `trigger`, sorted
-- alphabetically. Registry-driven (no hardcoded command list) so it stays
-- correct as commands.lua grows -- used by tests that need to target "every
-- child of a given high-fan-out trigger" without naming them by hand.
function M.children_of(trigger)
  local out = {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound and entry.requires == trigger then
      table.insert(out, cmd)
    end
  end
  table.sort(out)
  return out
end

-- The `requires` value with the most non-compound children whose try_next
-- is not explicitly false (i.e. eligible for efficiency_gaps()). Registry-
-- driven and deterministic (candidates are visited in sorted key order, with
-- a strict > comparison so the first-seen max always wins regardless of
-- pairs() iteration order) -- used by tests that need "whichever trigger
-- currently has the worst fan-out" without hardcoding a command/key name
-- that could drift as commands.lua grows. See issue #291.
function M.highest_fanout_trigger()
  local counts = {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound and entry.requires and entry.try_next ~= false then
      counts[entry.requires] = (counts[entry.requires] or 0) + 1
    end
  end
  local keys = {}
  for k in pairs(counts) do
    table.insert(keys, k)
  end
  table.sort(keys)
  local best, best_n = nil, 0
  for _, k in ipairs(keys) do
    if counts[k] > best_n then
      best, best_n = k, counts[k]
    end
  end
  return best, best_n
end

-- Every category name that has zero beginner-level, non-compound commands.
-- Registry-driven -- see issue #292, whose root cause only affects a category
-- shaped exactly this way (no beginner rung to keep it under find_best's/
-- guide_commands' global ceiling regardless of that category's own mastery).
function M.categories_without_beginner_commands()
  local has_beginner, all_cats = {}, {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound then
      local cat = entry.category or 'motion'
      all_cats[cat] = true
      if (entry.level or 'beginner') == 'beginner' then
        has_beginner[cat] = true
      end
    end
  end
  local out = {}
  for cat in pairs(all_cats) do
    if not has_beginner[cat] then
      table.insert(out, cat)
    end
  end
  table.sort(out)
  return out
end

-- All non-compound commands in a given category, sorted alphabetically.
function M.commands_in_category(cat)
  local out = {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound and entry.category == cat then
      table.insert(out, cmd)
    end
  end
  table.sort(out)
  return out
end

local function sessions_of(rng, n, lo, hi)
  local s = {}
  for i = 1, n do
    s[i] = lo + math.floor(rng() * (hi - lo + 1))
  end
  return s
end

-- ── Usage profiles ───────────────────────────────────────────────────────────
--
-- Each profile returns a {count, sessions} shape representing one command's
-- accumulated history. Named after real usage shapes discussed in #307's
-- repro (steady/bursty/abandoned) plus the ordinary never/tried/familiar
-- spread every registry has at realistic scale.
local PROFILES = {
  never = function()
    return { count = 0, sessions = {} }
  end,

  tried = function(rng)
    local count = 1 + math.floor(rng() * 40)
    return { count = count, sessions = sessions_of(rng, 1 + math.floor(rng() * 3), 0, 4) }
  end,

  familiar = function(rng)
    local count = 100 + math.floor(rng() * 300)
    return { count = count, sessions = sessions_of(rng, 5, 3, 15) }
  end,

  -- Heavily used, evenly across recent sessions: is_mastered() == true,
  -- is_forgotten() == false.
  mastered_steady = function(rng)
    local count = 400 + math.floor(rng() * 4000)
    return { count = count, sessions = sessions_of(rng, 10, 5, 30) }
  end,

  -- Mastered but only lightly used per-session (not a heavy habit, just a
  -- long-standing consistent one).
  mastered_light_consistent = function(rng)
    local count = 120 + math.floor(rng() * 200)
    return { count = count, sessions = sessions_of(rng, 10, 1, 6) }
  end,

  -- Historical average clears FORGOTTEN_ADOPTED_BAR, but the last two
  -- sessions dropped near zero -- the graded is_forgotten() == true case
  -- ADR 0029 targets.
  forgotten_recently = function(rng)
    local sessions = sessions_of(rng, 8, 8, 20)
    table.insert(sessions, 0)
    table.insert(sessions, math.floor(rng() * 2))
    local count = 300 + math.floor(rng() * 2000)
    return { count = count, sessions = sessions }
  end,

  -- #307's exact repro shape: a command with a huge lifetime count whose
  -- 10-slot sessions window is now entirely zero -- i.e. the state AFTER 10+
  -- session-close boundaries of total inactivity since abandonment.
  heavy_then_long_abandoned = function(rng)
    local count = 1500 + math.floor(rng() * 3000)
    local sessions = {}
    for i = 1, 10 do
      sessions[i] = 0
    end
    return { count = count, sessions = sessions }
  end,

  -- Genuinely used every 3rd session, not abandoned -- #307's "secondary,
  -- lower-confidence finding" false-positive shape.
  irregular_bursty = function(rng)
    local sessions = {}
    for i = 1, 10 do
      sessions[i] = (i % 3 == 1) and (10 + math.floor(rng() * 10)) or 0
    end
    local count = 200 + math.floor(rng() * 500)
    return { count = count, sessions = sessions }
  end,
}
M.PROFILES = PROFILES

-- Weighted so most of a ~190-command registry stays lightly touched (as in
-- real usage: nobody masters every command), with a smaller mastered tail and
-- a thin slice of forgotten/bursty/abandoned edge cases. This weighting is
-- what makes the fixture "realistic scale" rather than uniformly random.
local WEIGHTED = {
  { 'never', 30 },
  { 'tried', 28 },
  { 'familiar', 14 },
  { 'mastered_steady', 12 },
  { 'mastered_light_consistent', 6 },
  { 'forgotten_recently', 4 },
  { 'heavy_then_long_abandoned', 3 },
  { 'irregular_bursty', 3 },
}
local TOTAL_WEIGHT = 0
for _, w in ipairs(WEIGHTED) do
  TOTAL_WEIGHT = TOTAL_WEIGHT + w[2]
end

local function pick_profile(rng)
  local r = rng() * TOTAL_WEIGHT
  local acc = 0
  for _, w in ipairs(WEIGHTED) do
    acc = acc + w[2]
    if r <= acc then
      return w[1]
    end
  end
  return WEIGHTED[#WEIGHTED][1]
end

-- Generates a realistic-scale usage.json-shaped table covering every command
-- currently in tobira.commands.registry.
--
-- seed: integer. Same seed always produces the same fixture.
-- overrides: optional table of cmd -> profile-name-string | explicit
--   {count, sessions, shown?, suppressed?, pinned?, celebrated?} entry.
--   Applied AFTER random generation, so a specific invariant test can pin a
--   handful of commands to an exact known state while the rest of the
--   registry still gets realistic random filler around it. Keys that are not
--   themselves registry commands (e.g. bare trigger keys like 'n'/'j'/'i',
--   which logger.lua tracks but which never get their own commands.registry
--   entry -- see build_track_table()'s comment) are also accepted here, since
--   graph.lua reads usage[trigger].count regardless of whether the trigger is
--   itself a registered command.
function M.generate(seed, overrides)
  overrides = overrides or {}

  -- Union of every registry command and every override key, sorted, so a
  -- trigger-only override (e.g. usage.n, which has no commands.registry
  -- entry of its own) still lands in the output deterministically.
  local keys, seen = {}, {}
  for _, cmd in ipairs(M.registry_commands()) do
    keys[#keys + 1] = cmd
    seen[cmd] = true
  end
  for cmd in pairs(overrides) do
    if not seen[cmd] then
      keys[#keys + 1] = cmd
      seen[cmd] = true
    end
  end
  table.sort(keys)

  local rng = new_rng(seed)
  local usage = {}
  for _, cmd in ipairs(keys) do
    local override = overrides[cmd]
    local entry
    if type(override) == 'string' then
      entry = PROFILES[override](rng)
    elseif type(override) == 'table' then
      entry = override
    else
      entry = PROFILES[pick_profile(rng)](rng)
    end
    entry.shown = entry.shown or 0
    entry.suppressed = entry.suppressed or false
    entry.pinned = entry.pinned or false
    entry.celebrated = entry.celebrated or false
    usage[cmd] = entry
  end
  return usage
end

-- Mirrors logger.lua's close_session() session-array rolling-window behavior
-- (MAX_SESSIONS = 10 there): appends `count` then truncates from the front
-- once the array exceeds max_sessions. Lets regression tests simulate N
-- session-close boundaries directly on a sessions array without depending on
-- logger.lua's I/O (data_dir / vim.on_key / VimLeave) -- keeps this fixture
-- module pure Lua, matching graph.lua's own vim.*-free contract.
function M.simulate_session_close(sessions, count, max_sessions)
  max_sessions = max_sessions or 10
  table.insert(sessions, count)
  while #sessions > max_sessions do
    table.remove(sessions, 1)
  end
  return sessions
end

return M
