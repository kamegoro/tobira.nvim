-- Seedable, weighted-random keystroke-ACTION generator for the
-- patterns_insert.lua differential test (see reference_model_insert.lua and
-- patterns_insert_differential_spec.lua).
--
-- A parallel, independent apparatus to generator.lua (the patterns.lua/seq
-- differential suite) — not a shared one, per lua/tobira/CLAUDE.md's
-- "Module splitting policy". Uses its own copy of the same Park-Miller LCG
-- (see generator.lua's header for why this exact algorithm: only `*`/`%`,
-- so it's byte-for-byte identical across PUC Lua and LuaJIT for a given
-- integer seed) rather than requiring generator.lua, so this suite has no
-- file dependency on the other one.
--
-- Unlike generator.lua's flat list of raw key strings, this generator
-- produces a list of tagged ACTIONS, because patterns_insert.lua's own
-- entry points take two different shapes:
--   { mode = 'insert', canonical = '<BS>'|'<Left>'|'<Right>'|'<Esc>'|nil,
--     char = <string, only meaningful when canonical is nil> }
--   { mode = 'normal_watch', key = <string> }
-- 'normal_watch' actions only ever appear directly after an '<Esc>' insert
-- action (arming the watch) — see the co_oneshot_run emitter below — never
-- standalone, matching how logger.lua only ever calls feed_after_escape()
-- while iseq.watching_co is armed.

local M = {}

-- ── deterministic PRNG (Park-Miller "Minimal Standard" LCG) ─────────────────
-- See generator.lua's header for the full rationale (reproducibility across
-- Lua/LuaJIT builds via a multiplier that never overflows 53-bit doubles).
local PARK_MILLER_MODULUS = 2147483647 -- 2^31 - 1, prime
local PARK_MILLER_MULTIPLIER = 16807 -- 7^5, a primitive root of the modulus

local function new_rng(seed)
  local state = seed % PARK_MILLER_MODULUS
  if state <= 0 then
    state = state + (PARK_MILLER_MODULUS - 1)
  end
  return {
    next_u32 = function()
      state = (state * PARK_MILLER_MULTIPLIER) % PARK_MILLER_MODULUS
      return state
    end,
  }
end
M.new_rng = new_rng

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

-- ── action helpers ───────────────────────────────────────────────────────
local function ins(out, canonical, char)
  table.insert(out, { mode = 'insert', canonical = canonical, char = char })
end
local function watch(out, key)
  table.insert(out, { mode = 'normal_watch', key = key })
end

-- ── ordinary "safe noise" typed text ─────────────────────────────────────
-- Word-forming characters (build up the in-progress completion token) and
-- boundary/punctuation characters (close it), weighted toward realistic
-- code-editing text: lowercase letters most common, digits/underscore
-- occasional, space/punctuation boundaries regular.
local WORD_CHARS = {
  { value = 'e', weight = 8 },
  { value = 't', weight = 8 },
  { value = 'a', weight = 7 },
  { value = 'o', weight = 7 },
  { value = 'i', weight = 7 },
  { value = 'n', weight = 7 },
  { value = 's', weight = 6 },
  { value = 'r', weight = 6 },
  { value = 'l', weight = 5 },
  { value = 'u', weight = 4 },
  { value = 'x', weight = 2 },
  { value = 'q', weight = 1 },
  { value = '_', weight = 2 },
  { value = '3', weight = 1 },
}
local BOUNDARY_CHARS = { ' ', '.', ',', '(', ')', '\n' }

local function rand_word_char(rng)
  return weighted_choice(rng, WORD_CHARS)
end
local function rand_boundary_char(rng)
  return BOUNDARY_CHARS[rand_int(rng, 1, #BOUNDARY_CHARS)]
end

-- A short (2-5 char) ordinary word, well under TOKEN_LEN_THRESHOLD (6) —
-- realistic "this must never false-positive" noise per docs/adr/0039.
local function emit_short_word(rng, out)
  for _ = 1, rand_int(rng, 2, 5) do
    ins(out, nil, rand_word_char(rng))
  end
  ins(out, nil, rand_boundary_char(rng))
end

-- Plain noise chunk: a mix of short words and occasional single (non-
-- streak-reaching) <BS>/<Left>/<Right>/<Esc> presses. <Esc> here is always
-- preceded by real input in the same chunk, so it never itself contributes
-- to an insert_bounce streak — bounce_run (below) is the dedicated emitter
-- for that.
local function emit_noise(rng, out)
  local kind = rand_int(rng, 1, 10)
  if kind <= 6 then
    emit_short_word(rng, out)
  elseif kind == 7 then
    for _ = 1, rand_int(rng, 1, 3) do
      ins(out, '<BS>')
    end
  elseif kind == 8 then
    for _ = 1, rand_int(rng, 1, 3) do
      ins(out, '<Left>')
    end
  elseif kind == 9 then
    for _ = 1, rand_int(rng, 1, 3) do
      ins(out, '<Right>')
    end
  else
    ins(out, nil, rand_word_char(rng)) -- ensure had_input=true first
    ins(out, '<Esc>')
  end
end

-- ── pattern-building chunk emitters ─────────────────────────────────────

-- Streak run for one of <BS>/<Left>/<Right>, reps in [1,8] so the corpus
-- covers under-threshold, exactly-at-threshold (5), and well-past cases.
local function emit_streak_run(rng, out, canonical)
  for _ = 1, rand_int(rng, 1, 8) do
    ins(out, canonical)
  end
end

-- 1-3 empty <Esc> bounces in a row (no typed input between any of them),
-- covering under-threshold (1) and at/past-threshold (2+) reps of
-- insert_bounce's own streak (see docs/adr/0038).
local function emit_bounce_run(rng, out)
  for _ = 1, rand_int(rng, 1, 3) do
    ins(out, '<Esc>')
  end
end

-- A random identifier-shaped token: length in [threshold-2, threshold+6] so
-- the corpus covers both under-threshold (never recorded) and over-
-- threshold (recorded, matchable) lengths.
local function rand_token_len(rng)
  return rand_int(rng, 4, 12)
end

-- Draws `len` fresh random word characters (a literal array, not a length —
-- see rand_token_chars below for why the distinction matters).
local function type_token(rng, out, len)
  for _ = 1, len do
    ins(out, nil, rand_word_char(rng))
  end
end

-- A fixed array of `len` random word characters, generated ONCE, so callers
-- that want to type "the same word" a second time can replay the identical
-- characters (via type_chars below) instead of drawing fresh random ones —
-- rand_word_char() is a live draw from the RNG, so two separate
-- type_token(rng, out, len) calls of the same LENGTH almost never produce
-- the same CONTENT. Every repeat-detection scenario in this file depends on
-- literal content equality, not length equality.
local function rand_token_chars(rng, len)
  local chars = {}
  for i = 1, len do
    chars[i] = rand_word_char(rng)
  end
  return chars
end

local function type_chars(out, chars, from, to)
  for i = from or 1, to or #chars do
    ins(out, nil, chars[i])
  end
end

-- Types the same token twice (with a boundary after each), the canonical
-- insert_completion_repeat trigger — but sometimes corrupts the SECOND
-- typing with a mid-token <BS> correction (should still match once
-- corrected back to the identical spelling) or a <Left>/<Right> excursion
-- (should abandon the token, per docs/adr/0039, and therefore NOT match).
local function emit_completion_repeat_run(rng, out)
  local len = rand_token_len(rng)
  local chars = rand_token_chars(rng, len)
  -- One boundary character reused for every occurrence in this chunk —
  -- required for the variant==5 triple-repeat case below: patterns.lua's
  -- macro_opportunity anchor-match compares the token+boundary WINDOW
  -- literally token-for-token (see macro_windows_equal), so a different
  -- boundary character between occurrences (e.g. ' ' then '.') would never
  -- anchor-match even though the word itself repeated identically.
  local boundary_char = rand_boundary_char(rng)
  type_chars(out, chars)
  ins(out, nil, boundary_char)

  local variant = rand_int(rng, 1, 5)
  if variant == 1 then
    -- clean exact repeat — replays the SAME characters
    type_chars(out, chars)
  elseif variant == 2 and len > 2 then
    -- typo + correction: retype the same word, add one extra (random) typo
    -- character, then <BS> it away — final accumulated token is the same
    -- `chars` again (truncating the extra char keeps the append-only
    -- assumption valid, per docs/adr/0039), so this must still match.
    type_chars(out, chars)
    ins(out, nil, rand_word_char(rng)) -- extra typo char
    ins(out, '<BS>') -- correct it back
  elseif variant == 3 then
    -- cursor excursion mid-second-typing: types the first half of the SAME
    -- word, then <Left>/<Right> abandons that partial progress (token
    -- resets to ''), then types only the SECOND half — the final
    -- accumulated token is that second-half suffix alone, never the full
    -- `chars` string, so this must NOT match (docs/adr/0039: abandonment is
    -- a conservative false negative, not a false positive risk).
    local half = math.max(1, math.floor(len / 2))
    type_chars(out, chars, 1, half)
    ins(out, rand_int(rng, 1, 2) == 1 and '<Left>' or '<Right>')
    type_chars(out, chars, half + 1, len)
  elseif variant == 5 then
    -- THREE exact back-to-back repeats (2nd + 3rd occurrence — the 1st was
    -- already typed above), all sharing boundary_char: also anchor-matches
    -- patterns.lua's own macro_opportunity (its token+boundary window
    -- repeats 3 times with zero gap, and a random word usually contains at
    -- least one MACRO_EDIT_KEYS letter) — see the #334 divergence this is
    -- deliberately built to exercise, not just the 2-repeat case above.
    type_chars(out, chars)
    ins(out, nil, boundary_char)
    type_chars(out, chars)
  else
    -- a DIFFERENT token of the same length — must not cross-match
    type_token(rng, out, len)
  end
  ins(out, nil, boundary_char)
end

-- Builds 9 distinct over-threshold tokens back to back (one more than
-- RING_SIZE=8), to exercise eviction of the oldest.
local function emit_ring_eviction_run(rng, out)
  for _ = 1, 9 do
    type_token(rng, out, rand_token_len(rng))
    ins(out, nil, rand_boundary_char(rng))
  end
end

-- <Esc> → 0-3 safe Normal-mode keystrokes → return-to-insert key, covering
-- the exact-one-shot case (fires), the zero-motion case (does not fire —
-- nothing to have used <C-o> for), and the 2+-keystroke "genuine detour"
-- case (does not fire) — see docs/adr/0037.
--
-- SAFE_WATCH_KEYS are single Normal-mode keystrokes chosen the same way
-- generator.lua's own SAFE_NOISE was: ordinary motions that don't start any
-- patterns.lua two-key pending compound and are never i/a/A/I themselves
-- (which step_normal_watch treats specially as the return key, never as
-- "the one motion").
local SAFE_WATCH_KEYS = { 'j', 'k', 'h', 'l', 'w', 'b', 'e', 'x', 'p', '~', '0', '$' }
local RETURN_KEYS = { 'i', 'a', 'A', 'I' }

local function emit_co_oneshot_run(rng, out)
  ins(out, '<Esc>') -- arms the watch
  local motion_count = rand_int(rng, 0, 3)
  for _ = 1, motion_count do
    watch(out, SAFE_WATCH_KEYS[rand_int(rng, 1, #SAFE_WATCH_KEYS)])
  end
  watch(out, RETURN_KEYS[rand_int(rng, 1, #RETURN_KEYS)])
end

-- All pattern-building chunk kinds, with default (mixed-corpus) weights.
-- M.generate's `only` parameter restricts to a single kind (plus noise).
local ALL_CHUNK_KINDS = {
  { value = 'bs_run', weight = 6 },
  { value = 'left_run', weight = 6 },
  { value = 'right_run', weight = 6 },
  { value = 'bounce_run', weight = 6 },
  { value = 'completion_repeat_run', weight = 6 },
  { value = 'ring_eviction_run', weight = 2 },
  { value = 'co_oneshot_run', weight = 6 },
}
M.ALL_CHUNK_KINDS = {}
for _, it in ipairs(ALL_CHUNK_KINDS) do
  table.insert(M.ALL_CHUNK_KINDS, it.value)
end

local NOISE_WEIGHT = 30

-- Generates a flat list of ACTIONS (see header). rng: from M.new_rng(seed).
-- length: approximate number of chunks to emit. only: optional single
-- chunk kind (a value from M.ALL_CHUNK_KINDS) to restrict generation to —
-- used for the "isolated" differential corpus, same rationale as
-- generator.lua's own `only` parameter.
function M.generate(rng, length, only)
  local out = {}
  local chunk_emitters = { { value = 'noise', weight = NOISE_WEIGHT } }
  if only then
    table.insert(chunk_emitters, { value = only, weight = 20 })
  else
    for _, it in ipairs(ALL_CHUNK_KINDS) do
      table.insert(chunk_emitters, it)
    end
  end
  for _ = 1, length do
    local kind = weighted_choice(rng, chunk_emitters)
    if kind == 'noise' then
      emit_noise(rng, out)
    elseif kind == 'bs_run' then
      emit_streak_run(rng, out, '<BS>')
    elseif kind == 'left_run' then
      emit_streak_run(rng, out, '<Left>')
    elseif kind == 'right_run' then
      emit_streak_run(rng, out, '<Right>')
    elseif kind == 'bounce_run' then
      emit_bounce_run(rng, out)
    elseif kind == 'completion_repeat_run' then
      emit_completion_repeat_run(rng, out)
    elseif kind == 'ring_eviction_run' then
      emit_ring_eviction_run(rng, out)
    elseif kind == 'co_oneshot_run' then
      emit_co_oneshot_run(rng, out)
    end
  end
  return out
end

return M
