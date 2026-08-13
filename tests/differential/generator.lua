-- Seedable, weighted-random keystroke sequence generator for the
-- patterns.lua differential test (see reference_model.lua and
-- tests/differential/patterns_seq_differential_spec.lua).
--
-- Uses its own tiny deterministic PRNG (a Park-Miller LCG — see below) rather
-- than Lua's math.random/math.randomseed, so a given integer seed produces
-- the exact same keystroke sequence regardless of which Lua/LuaJIT build
-- runs it (PUC Lua and LuaJIT's math.random are not guaranteed to agree
-- bit-for-bit even with the same math.randomseed()) — required for "print
-- the seed, a human pastes it back and gets the identical failing sequence"
-- reproducibility.
--
-- Two kinds of chunks make up the output stream, always emitted as
-- indivisible units (never interleaved by an independent draw mid-chunk):
--   1. Single-key "safe noise" — ordinary, non-prefix keys that reach
--      patterns.lua's shared bottom-of-function bookkeeping on their own
--      (see SAFE_NOISE below). Weighted toward common Vim motions.
--   2. Pattern-building runs — a repeated 2-key compound (dd, >>, <<, r{char},
--      <C-w>{q,c,+,-,<,>}, z{o,c}) or repeated bare motion (j, k), run for a
--      randomized rep count so the corpus covers under-threshold,
--      exactly-at-threshold, and well-past-threshold cases, sometimes with
--      a tolerated navigation key spliced between reps (h/l for r_run, the
--      fold-tolerance set for zo/zc) to exercise each pattern's own
--      documented tolerance rule, not just its bare happy path.
--
-- Deliberately excluded from every chunk here: f/F/t/T, v, g, ", @, m, ',
-- `, [, ] and INSERT_KEYS (i/a/o/I/A/O/s/S) — every one of these either
-- starts its own multi-key compound with no relevance to the 10 patterns
-- this differential test tracks, or (i/a/o/…) can trigger one of
-- patterns.lua's OTHER early-return branches (dd_then_insert, x_then_insert,
-- …) under specific preceding state, which would silently skip the shared
-- bookkeeping our "safe noise" assumption depends on. Exercising that whole
-- class of early-return skip is real and valuable — see the deterministic,
-- clearly-labeled KNOWN_GAP scenarios in the differential spec instead,
-- where it's demonstrated on purpose rather than accidentally diluting this
-- generator's pass/fail signal.

local M = {}

-- ── deterministic PRNG (Park-Miller "Minimal Standard" LCG) ─────────────────
-- Deliberately NOT a bitwise-operator-based generator (xorshift etc.):
-- `~`/`<<`/`>>` are Lua 5.3+ syntax and are not guaranteed to exist, or to
-- agree bit-for-bit, across every Lua/LuaJIT build (confirmed empirically —
-- an earlier xorshift32 draft of this file produced a DIFFERENT sequence for
-- the same seed under a standalone `lua` interpreter vs. Neovim's bundled
-- LuaJIT). This generator uses only `*` and `%`. Its only multiplication,
-- 16807 * state, never exceeds 2^45 (state is always < 2^31), which is
-- exactly representable in a 53-bit IEEE double — so it produces byte-for-
-- byte identical output whether Lua represents numbers as doubles (LuaJIT,
-- PUC Lua 5.1/5.2) or 64-bit integers (PUC Lua 5.3+). This is what actually
-- makes "paste the seed back to reproduce" reliable regardless of which Lua
-- a human's local `lua` REPL happens to be.
local PARK_MILLER_MODULUS = 2147483647 -- 2^31 - 1, prime
local PARK_MILLER_MULTIPLIER = 16807 -- 7^5, a primitive root of the modulus

local function new_rng(seed)
  local state = seed % PARK_MILLER_MODULUS
  if state <= 0 then
    state = state + (PARK_MILLER_MODULUS - 1) -- keep state in [1, modulus - 1]
  end
  return {
    next_u32 = function()
      state = (state * PARK_MILLER_MULTIPLIER) % PARK_MILLER_MODULUS
      return state
    end,
  }
end
M.new_rng = new_rng

-- Integer in [lo, hi], inclusive.
local function rand_int(rng, lo, hi)
  return lo + (rng.next_u32() % (hi - lo + 1))
end

-- Picks one entry from a { {value=, weight=}, ... } list.
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

-- ── safe noise pool ─────────────────────────────────────────────────────────
-- Every key here was empirically verified (see the differential-testing PR's
-- probe scripts) to reach patterns.lua's shared bottom-of-function reset
-- unconditionally on its own — no pending state, no early return. Weighted
-- roughly toward realistic Vim usage: hjkl and w/b/e motions dominate,
-- edit/misc keys appear occasionally.
--
-- Deliberately excluded despite reaching the bottom cleanly themselves: G/n/N
-- (JUMP_MOTION_KEYS) and x (an EDIT_OP_KEYS member). Both feed patterns.lua's
-- pre-existing, unrelated jumplist/changelist-underuse arbitration
-- (docs/adr/0019) — 5 j/k presses within its own 15s tolerance window after
-- one of these can make manual_return/changelist_return legitimately outrank
-- j_repeat/k_repeat, which is correct, documented, in-production behavior,
-- just not one of the 10 patterns this test tracks. Including them here
-- would drown this generator's real signal in a second test's worth of
-- noise for a feature this differential test isn't scoped to model.
local SAFE_NOISE = {
  { value = 'h', weight = 10 },
  { value = 'l', weight = 10 },
  { value = 'w', weight = 7 },
  { value = 'b', weight = 5 },
  { value = 'e', weight = 4 },
  { value = 'u', weight = 2 },
  { value = '~', weight = 2 },
  { value = '.', weight = 2 },
  { value = 'J', weight = 1 },
  { value = '0', weight = 2 },
  { value = '^', weight = 1 },
  { value = '$', weight = 2 },
}

local function emit_noise(rng, out)
  table.insert(out, weighted_choice(rng, SAFE_NOISE))
end

-- ── pattern-building chunk emitters ─────────────────────────────────────────
-- Each emits a randomized rep count so the corpus naturally covers
-- under-threshold, at-threshold, and well-past-threshold (which also drifts
-- into macro_opportunity's own 3x-repeat territory — the collision surface
-- issue #316 calls out) cases.

local function rand_reps(rng, min_reps, max_reps)
  return rand_int(rng, min_reps, max_reps)
end

local function emit_j_run(rng, out)
  for _ = 1, rand_reps(rng, 1, 12) do
    table.insert(out, 'j')
  end
end

local function emit_k_run(rng, out)
  for _ = 1, rand_reps(rng, 1, 12) do
    table.insert(out, 'k')
  end
end

local function emit_dd_run(rng, out)
  for _ = 1, rand_reps(rng, 1, 5) do
    table.insert(out, 'd')
    table.insert(out, 'd')
  end
end

local function emit_indent_run(rng, out)
  for _ = 1, rand_reps(rng, 1, 5) do
    table.insert(out, '>')
    table.insert(out, '>')
  end
end

local function emit_dedent_run(rng, out)
  for _ = 1, rand_reps(rng, 1, 5) do
    table.insert(out, '<')
    table.insert(out, '<')
  end
end

-- r{char} repeated, occasionally splicing in the documented h/l tolerance
-- (ADR 0027) between reps instead of always emitting a bare run.
local R_CHARS = { 'x', 'o', '_', '0', 'z' }
local function emit_r_run(rng, out)
  local reps = rand_reps(rng, 1, 5)
  for i = 1, reps do
    table.insert(out, 'r')
    table.insert(out, R_CHARS[rand_int(rng, 1, #R_CHARS)])
    if i < reps and rand_int(rng, 1, 3) == 1 then
      table.insert(out, rand_int(rng, 1, 2) == 1 and 'h' or 'l')
    end
  end
end

local function emit_ctrl_w_close_run(rng, out)
  local reps = rand_reps(rng, 1, 4)
  for _ = 1, reps do
    table.insert(out, '\23')
    table.insert(out, rand_int(rng, 1, 2) == 1 and 'q' or 'c')
  end
end

local function emit_ctrl_w_resize_run(rng, out)
  local targets = { '+', '-', '<', '>' }
  local reps = rand_reps(rng, 1, 4)
  for _ = 1, reps do
    table.insert(out, '\23')
    table.insert(out, targets[rand_int(rng, 1, #targets)])
  end
end

-- zo/zc repeated, occasionally splicing in the documented navigation
-- tolerance (ADR 0108's CI_QUOTE_NAV_KEYS reuse) between reps.
local FOLD_TOLERATED_NAV = { 'w', 'b', 'e', 'h', 'l', 'j', 'k', '0', '^', '$' }
local function emit_fold_run(rng, out, target)
  local reps = rand_reps(rng, 1, 4)
  for i = 1, reps do
    table.insert(out, 'z')
    table.insert(out, target)
    if i < reps and rand_int(rng, 1, 2) == 1 then
      table.insert(out, FOLD_TOLERATED_NAV[rand_int(rng, 1, #FOLD_TOLERATED_NAV)])
    end
  end
end

-- All pattern-building chunk kinds this generator knows, with their default
-- (mixed-corpus) weights. M.generate's `only` parameter can restrict this to
-- a single kind (plus noise) for the "isolated" corpus — see its own doc
-- comment below for why that corpus exists alongside the full mixed one.
local ALL_CHUNK_KINDS = {
  { value = 'j_run', weight = 6 },
  { value = 'k_run', weight = 6 },
  { value = 'dd_run', weight = 6 },
  { value = 'indent_run', weight = 4 },
  { value = 'dedent_run', weight = 4 },
  { value = 'r_run', weight = 4 },
  { value = 'ctrl_w_close_run', weight = 3 },
  { value = 'ctrl_w_resize_run', weight = 3 },
  { value = 'fold_open_run', weight = 3 },
  { value = 'fold_close_run', weight = 3 },
}
M.ALL_CHUNK_KINDS = {}
for _, it in ipairs(ALL_CHUNK_KINDS) do
  table.insert(M.ALL_CHUNK_KINDS, it.value)
end

local NOISE_WEIGHT = 40

-- Generates a flat list of keystrokes (strings, using patterns.feed()'s own
-- raw-byte convention for control keys, e.g. '\23' for <C-w>).
--
-- rng: from M.new_rng(seed) — pass the SAME seed to reproduce the identical
-- sequence.
-- length: approximate number of chunks to emit (each chunk is 1-10 keys).
-- only: optional single chunk kind (a value from M.ALL_CHUNK_KINDS) to
--   restrict generation to — plain noise plus only that one pattern family.
--   Used for the "isolated" differential corpus, which builds exactly one
--   family's streak at a time so no OTHER family's two-key compound can ever
--   interrupt it — see the differential spec for why that separation matters
--   (patterns.lua's real early-return prefix-consumer branches mean a
--   DIFFERENT family's compound silently not resetting this one's streak is
--   itself the exact bug class issue #313 tracks, so mixing families
--   together deliberately, in the OTHER (non-isolated) corpus, is what
--   surfaces it — see that corpus's own comment).
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
    elseif kind == 'j_run' then
      emit_j_run(rng, out)
    elseif kind == 'k_run' then
      emit_k_run(rng, out)
    elseif kind == 'dd_run' then
      emit_dd_run(rng, out)
    elseif kind == 'indent_run' then
      emit_indent_run(rng, out)
    elseif kind == 'dedent_run' then
      emit_dedent_run(rng, out)
    elseif kind == 'r_run' then
      emit_r_run(rng, out)
    elseif kind == 'ctrl_w_close_run' then
      emit_ctrl_w_close_run(rng, out)
    elseif kind == 'ctrl_w_resize_run' then
      emit_ctrl_w_resize_run(rng, out)
    elseif kind == 'fold_open_run' then
      emit_fold_run(rng, out, 'o')
    elseif kind == 'fold_close_run' then
      emit_fold_run(rng, out, 'c')
    end
  end
  return out
end

return M
