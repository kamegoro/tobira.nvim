-- Seedable, weighted-random generator of realistic command-line (Ex) SESSIONS
-- for the patterns_cmdline.lua differential test — see
-- reference_model_cmdline.lua and patterns_cmdline_differential_spec.lua.
--
-- Unlike tests/differential/generator.lua (raw single-character normal-mode
-- keystrokes), this module's keystroke vocabulary is at the level
-- patterns_cmdline.lua itself operates at: one complete submitted
-- command-line STRING per <CR>, plus the <Up>/<Down> history-navigation
-- keystrokes observed while a session is open (see
-- docs/adr/0002-ex-command-tokenizer-one-shot-parsing.md for why the real
-- module takes one complete string at <CR> time rather than a per-keystroke
-- accumulator — the generator mirrors that same granularity).
--
-- A "session" is everything typed between opening ':' and the terminating
-- key:
--   presses: how many times <Up>/<Down> was pressed before the terminator
--             (0 most of the time — realistic cmdline usage rarely recalls
--             history — occasionally 1-2, to exercise the recalled_via_history
--             flag, #259).
--   action:  'submit' (<CR>, with a rendered command line) or 'cancel'
--             (<Esc>/<C-c>, no submission at all — the flag must not carry
--             into the next session).
--
-- Four event kinds, matching patterns_cmdline.lua's four independent
-- detectors (see the module's own section headers): 'sub' (substitute_repeat/
-- _wide), 'ex_file' (ex_file_pingpong), 'tabnew' (tabnew_run), and 'other'
-- (cmdline_history_recall's general fallback — trivial/bare commands per
-- #241, symbolic commands, and abbreviations the specific detectors don't
-- recognize like :edit/:buffer).
--
-- Small, fixed reuse pools (few distinct files/patterns/commands) are used
-- deliberately, mirroring generator.lua's small R_CHARS pool for r_run: with
-- only 3-4 distinct values, repeats — and therefore the 2nd/3rd-submission
-- thresholds every one of these four detectors is actually built to detect —
-- occur organically and often across a long random session, without the
-- generator needing to hand-bias toward repetition.

local base_generator = require('generator')

local M = {}

M.new_rng = base_generator.new_rng

local function rand_int(rng, lo, hi)
  return lo + (rng.next_u32() % (hi - lo + 1))
end

local function weighted_choice(rng, items)
  local total = 0
  for _, it in ipairs(items) do
    total = total + it.weight
  end
  local roll = rand_int(rng, 1, total)
  local acc = 0
  for _, it in ipairs(items) do
    acc = acc + it.weight
    if roll <= acc then
      return it.value
    end
  end
  return items[#items].value
end

local function pick(rng, pool)
  return pool[rand_int(rng, 1, #pool)]
end

-- ── reuse pools ──────────────────────────────────────────────────────────
local FILES = { 'alpha.txt', 'beta.txt', 'gamma.txt' }
local TABNEW_FILES = { 't1.txt', 't2.txt', 't3.txt', 't4.txt' }
local SUB_PAIRS = {
  { pattern = 'foo', replacement = 'bar' },
  { pattern = 'todo', replacement = 'done' },
  { pattern = 'x', replacement = 'y' },
  { pattern = 'old', replacement = 'new' },
}
-- Every abbreviation here is a genuine prefix of "substitute" (is_substitute_word's
-- own check) — includes mixed case to exercise the case-insensitive match.
local SUB_WORDS = { 's', 'su', 'sub', 'subs', 'substitute', 'S', 'Su', 'SUBSTITUTE' }
local SUB_DELIMS = { '/', '#', ',', '@' }
local SUB_FLAGS = { '', 'g', 'i', 'gc' }
local SUB_LINES = { 1, 2, 3, 4, 5 }

-- word/arg combos NOT claimed by any of the 3 specific detectors — includes
-- 'edit'/'buffer', the exact "abbreviation the specific detectors don't
-- recognize" case docs/adr/0095 calls out as falling through on purpose.
local OTHER_WITH_ARG = {
  { word = 'g', arg = 'pattern/d' },
  { word = 'v', arg = 'TODO/d' },
  { word = 'r', arg = 'file.txt' },
  { word = 'sort', arg = '-u' },
  { word = 'norm', arg = 'dd' },
  { word = 'edit', arg = 'alpha.txt' },
  { word = 'buffer', arg = 'beta.txt' },
  { word = 'w', arg = 'somefile.txt' },
}
local OTHER_BARE = { 'w', 'q', 'x', 'wq', 'qa', 'noh', 'wa' }
-- word == nil for all of these (command_arg() only recognizes letter-word
-- commands) — arg is folded into the raw text itself, not a separable field.
local OTHER_SYMBOLIC_TEXT = { '!ls -la', '!somecommand --flags', '=', '&', '~', '@:' }

local function render_sub(rng)
  local word = pick(rng, SUB_WORDS)
  local delim = pick(rng, SUB_DELIMS)
  local pair = pick(rng, SUB_PAIRS)
  local flags = pick(rng, SUB_FLAGS)
  local ranged = rand_int(rng, 1, 100) <= 12
  local range_prefix = ''
  if ranged then
    range_prefix = pick(rng, { '%', '1,3', "'<,'>" })
  end
  local text = range_prefix .. word .. delim .. pair.pattern .. delim .. pair.replacement .. delim .. flags
  return {
    kind = 'sub',
    text = text,
    pattern = pair.pattern,
    replacement = pair.replacement,
    ranged = ranged,
    line = pick(rng, SUB_LINES),
  }
end

local function render_ex_file(rng)
  local word = rand_int(rng, 1, 2) == 1 and 'e' or 'b'
  local bare = rand_int(rng, 1, 100) <= 15
  local arg = bare and nil or pick(rng, FILES)
  local text = word .. (arg and (' ' .. arg) or '')
  return { kind = 'ex_file', text = text, word = word, arg = arg }
end

local function render_tabnew(rng)
  local bare = rand_int(rng, 1, 100) <= 15
  local arg = bare and '' or pick(rng, TABNEW_FILES)
  local text = 'tabnew' .. (arg ~= '' and (' ' .. arg) or '')
  -- Mostly 1 (no window split happened) so streaks actually build; sometimes
  -- 2-3 to exercise the split-reset path (docs/adr/0005).
  local win_count = weighted_choice(rng, {
    { value = 1, weight = 8 },
    { value = 2, weight = 2 },
    { value = 3, weight = 1 },
  })
  return { kind = 'tabnew', text = text, arg = arg, win_count = win_count }
end

local function render_other(rng)
  local subtype = weighted_choice(rng, {
    { value = 'with_arg', weight = 4 },
    { value = 'bare', weight = 3 },
    { value = 'symbolic', weight = 2 },
  })
  if subtype == 'with_arg' then
    local combo = pick(rng, OTHER_WITH_ARG)
    return { kind = 'other', text = combo.word .. ' ' .. combo.arg, word = combo.word, arg = combo.arg }
  elseif subtype == 'bare' then
    local word = pick(rng, OTHER_BARE)
    local banged = rand_int(rng, 1, 100) <= 20
    local text = word .. (banged and '!' or '')
    return { kind = 'other', text = text, word = word, arg = nil }
  else
    local text = pick(rng, OTHER_SYMBOLIC_TEXT)
    return { kind = 'other', text = text, word = nil, arg = nil }
  end
end

local EVENT_KIND_WEIGHTS = {
  { value = 'sub', weight = 4 },
  { value = 'ex_file', weight = 4 },
  { value = 'tabnew', weight = 3 },
  { value = 'other', weight = 6 },
}
M.ALL_EVENT_KINDS = { 'sub', 'ex_file', 'tabnew', 'other' }

local function generate_event(rng, only)
  local kind = only or weighted_choice(rng, EVENT_KIND_WEIGHTS)
  if kind == 'sub' then
    return render_sub(rng)
  elseif kind == 'ex_file' then
    return render_ex_file(rng)
  elseif kind == 'tabnew' then
    return render_tabnew(rng)
  else
    return render_other(rng)
  end
end

-- Generates a flat list of session descriptors:
--   { presses = 0|1|2, action = 'submit'|'cancel', event = <submission or nil> }
--
-- rng: from M.new_rng(seed) — pass the SAME seed to reproduce the identical
-- sequence.
-- count: number of sessions to generate.
-- only: optional single event kind (a value from M.ALL_EVENT_KINDS) to
--   restrict every submitting session to — used for the "isolated" corpus,
--   mirroring generator.lua's `only` parameter, so a family's own
--   thresholds/tolerances can be validated without cross-family interference.
function M.generate_sessions(rng, count, only)
  local sessions = {}
  for _ = 1, count do
    local presses = weighted_choice(rng, {
      { value = 0, weight = 6 },
      { value = 1, weight = 3 },
      { value = 2, weight = 1 },
    })
    local action = weighted_choice(rng, {
      { value = 'submit', weight = 9 },
      { value = 'cancel', weight = 1 },
    })
    local session = { presses = presses, action = action }
    if action == 'submit' then
      session.event = generate_event(rng, only)
    end
    table.insert(sessions, session)
  end
  return sessions
end

return M
