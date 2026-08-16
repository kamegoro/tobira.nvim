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
--   2. Pattern-building runs — a repeated compound/streak, or a fixed
--      reactive-completion shape (e.g. dd + an insert-trigger key), run for
--      a randomized rep count where applicable so the corpus covers
--      under-threshold, exactly-at-threshold, and well-past-threshold
--      cases.
--
-- Deliberately excluded from every context-free chunk here: keys whose
-- correctness depends on a contextual parameter (is_diff/is_wrapped/line)
-- rather than just the keystroke sequence — those get their own dedicated
-- generators (M.generate_context, M.generate_line_walk) below, per issue
-- #328's design guidance ("generator needs to also vary that contextual
-- parameter alongside the keystroke sequence").
--
-- History: issue #316 (PR #323) scoped this generator to the 10 streak-based
-- patterns named in reference_model.lua's own history note. Issue #328
-- extends it to (almost) every other pattern patterns.lua can fire — see
-- reference_model.lua's header for the two deliberately-unmodeled
-- exceptions (macro_opportunity, visual_block_opportunity).

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

local function rand_reps(rng, min_reps, max_reps)
  return rand_int(rng, min_reps, max_reps)
end

-- Keys that trigger patterns.lua's INSERT_KEYS branch — shared by every
-- reactive "_then_insert" chunk below.
local INSERT_TRIGGERS = { 'i', 'I', 'a', 'A', 'o', 'O', 's', 'S' }

-- ── safe noise pool ─────────────────────────────────────────────────────────
-- Every key here was empirically verified (see the differential-testing PR's
-- probe scripts) to reach patterns.lua's shared bottom-of-function reset
-- unconditionally on its own — no pending state, no early return. Weighted
-- roughly toward realistic Vim usage: hjkl and w/b/e motions dominate,
-- edit/misc keys appear occasionally.
--
-- Deliberately excluded despite reaching the bottom cleanly themselves: G/n/N
-- (JUMP_MOTION_KEYS), x (an EDIT_OP_KEYS member), and every key now used by a
-- dedicated pattern-building chunk below (d/c/y/>/</=/r/v/g/z/<C-w>/f/F/t/T/
-- `/[/]/<C-a>/p/P/j/k, and the INSERT_TRIGGERS set) — including any of these
-- as "noise" would let it appear at unpredictable positions and dilute this
-- generator's real signal for the pattern it's dedicated to, the same
-- reasoning #316's original noise pool already applied to j/k/d/z/r/<C-w>.
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

-- ── pattern-building chunk emitters (original 10-pattern scope, #316) ──────

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
local NAV_TOLERATED_LIST = { 'w', 'b', 'e', 'h', 'l', 'j', 'k', '0', '^', '$' }
local function emit_fold_run(rng, out, target)
  local reps = rand_reps(rng, 1, 4)
  for i = 1, reps do
    table.insert(out, 'z')
    table.insert(out, target)
    if i < reps and rand_int(rng, 1, 2) == 1 then
      table.insert(out, NAV_TOLERATED_LIST[rand_int(rng, 1, #NAV_TOLERATED_LIST)])
    end
  end
end

-- ── pattern-building chunk emitters added by issue #328 ────────────────────

-- Generic single-key streak, covering every RUN_THRESHOLDS-keyed pattern in
-- reference_model.lua whose shape is just "press this key N times in a row"
-- (x_repeat/u_repeat/l_repeat/h_repeat/w_repeat/b_repeat/e_repeat/
-- p_repeat/P_repeat/dot_repeat/J_repeat), plus the tilde family (3 stacked
-- thresholds on the same key) and n_repeat (2-stage: a silent watch-arming
-- threshold, then the real fire).
local function emit_simple_streak(rng, out, key, max_reps)
  for _ = 1, rand_reps(rng, 1, max_reps) do
    table.insert(out, key)
  end
end

local function emit_dd_then_insert(rng, out)
  table.insert(out, 'd')
  table.insert(out, 'd')
  table.insert(out, INSERT_TRIGGERS[rand_int(rng, 1, #INSERT_TRIGGERS)])
end

-- Any non-$, non-same-op, non-i/a motion after 'd' generically becomes
-- last_op == 'dw' in patterns.lua (the op..'w' suffix is hardcoded
-- regardless of which motion character was actually pressed) — see
-- patterns.lua's own pending_op charwise-motion branch.
local DW_MOTIONS = { 'w', 'e', 'l', 'b', 'h' }
local function emit_dw_then_insert(rng, out)
  table.insert(out, 'd')
  table.insert(out, DW_MOTIONS[rand_int(rng, 1, #DW_MOTIONS)])
  table.insert(out, INSERT_TRIGGERS[rand_int(rng, 1, #INSERT_TRIGGERS)])
end

-- diw specifically (op='d', inner=true, key='w') is the one text-object
-- shape that arms diw_then_insert instead of the generic dw_then_insert —
-- see docs/adr/0119-diw-then-insert-text-object-variant-collapse.md.
local function emit_diw_then_insert(rng, out)
  table.insert(out, 'd')
  table.insert(out, 'i')
  table.insert(out, 'w')
  table.insert(out, INSERT_TRIGGERS[rand_int(rng, 1, #INSERT_TRIGGERS)])
end

-- Must be EXACTLY one 'x' — x_then_insert requires seq.run.count == 1, not
-- just seq.run.key == 'x'.
local function emit_x_then_insert(rng, out)
  table.insert(out, 'x')
  table.insert(out, INSERT_TRIGGERS[rand_int(rng, 1, #INSERT_TRIGGERS)])
end

-- A directly-typed 'D' keystroke (not the d$ compound — that produces
-- last_op == nil via its own immediate-return path, never seq.run.key).
local function emit_D_then_insert(rng, out)
  table.insert(out, 'D')
  table.insert(out, INSERT_TRIGGERS[rand_int(rng, 1, #INSERT_TRIGGERS)])
end

-- Only 'i' specifically completes zero_then_insert/zero_col_then_insert (not
-- the full INSERT_TRIGGERS set) — see patterns.lua's own exact key == 'i'
-- checks.
local function emit_zero_then_insert(rng, out)
  table.insert(out, '^')
  table.insert(out, 'i')
end

local function emit_zero_col_then_insert(rng, out)
  table.insert(out, '0')
  table.insert(out, 'i')
end

local function emit_zero_then_w(rng, out)
  table.insert(out, '0')
  table.insert(out, 'w')
end

local function emit_dollar_then_append(rng, out)
  table.insert(out, '$')
  table.insert(out, 'a')
end

-- k_then_o also requires seq.run.count == 1 for the k.
local function emit_k_then_o(rng, out)
  table.insert(out, 'k')
  table.insert(out, 'o')
end

local function emit_yy_then_p(rng, out)
  table.insert(out, 'y')
  table.insert(out, 'y')
  table.insert(out, 'p')
end

local function emit_dd_then_p(rng, out)
  table.insert(out, 'd')
  table.insert(out, 'd')
  table.insert(out, 'p')
end

local RIGHTWARD_CHARS = { 'l', 'w', 'e' }
local function emit_paste_then_rightward(rng, out, paste_key)
  table.insert(out, paste_key)
  for _ = 1, 3 do
    table.insert(out, RIGHTWARD_CHARS[rand_int(rng, 1, #RIGHTWARD_CHARS)])
  end
end

-- ci"/ci' repeated, occasionally splicing in the documented navigation
-- tolerance (ADR 0020) between reps — same shape as emit_fold_run.
local function emit_ci_quote_run(rng, out, quote)
  local reps = rand_reps(rng, 1, 4)
  for i = 1, reps do
    table.insert(out, 'c')
    table.insert(out, 'i')
    table.insert(out, quote)
    if i < reps and rand_int(rng, 1, 2) == 1 then
      table.insert(out, NAV_TOLERATED_LIST[rand_int(rng, 1, #NAV_TOLERATED_LIST)])
    end
  end
end

local function emit_n_run(rng, out)
  for _ = 1, rand_reps(rng, 1, 6) do
    table.insert(out, 'n')
  end
end

-- n-streak (>= 2) armed, then a 'c'-family change completes shortly after —
-- see docs/adr/0107.
local function emit_n_then_change(rng, out)
  table.insert(out, 'n')
  table.insert(out, 'n')
  if rand_int(rng, 1, 2) == 1 then
    table.insert(out, 'c')
    table.insert(out, 'w')
  else
    table.insert(out, 'c')
    table.insert(out, 'i')
    table.insert(out, 'w')
  end
end

-- <C-a> repeated, occasionally splicing in the documented j/k tolerance
-- (ADR 0027) between reps.
local function emit_ca_run(rng, out)
  local reps = rand_reps(rng, 1, 5)
  for i = 1, reps do
    table.insert(out, '\1')
    if i < reps and rand_int(rng, 1, 3) == 1 then
      table.insert(out, rand_int(rng, 1, 2) == 1 and 'j' or 'k')
    end
  end
end

-- <C-x> repeated, mirrors emit_ca_run above — see docs/adr/0027.
local function emit_cx_run(rng, out)
  local reps = rand_reps(rng, 1, 5)
  for i = 1, reps do
    table.insert(out, '\24')
    if i < reps and rand_int(rng, 1, 3) == 1 then
      table.insert(out, rand_int(rng, 1, 2) == 1 and 'j' or 'k')
    end
  end
end

local function emit_v_repeat(rng, out)
  for _ = 1, rand_reps(rng, 2, 5) do
    table.insert(out, 'v')
    table.insert(out, '\27')
  end
end

local VISUAL_OBJS = { 'w', '"', "'", 'b', 't', 'p' }
local VISUAL_OPS = { 'c', 'd', 'y' }
local function emit_visual_textobj(rng, out)
  table.insert(out, 'v')
  table.insert(out, rand_int(rng, 1, 2) == 1 and 'i' or 'a')
  table.insert(out, VISUAL_OBJS[rand_int(rng, 1, #VISUAL_OBJS)])
  table.insert(out, VISUAL_OPS[rand_int(rng, 1, #VISUAL_OPS)])
end

-- gq{motion} (using 'q' as the completing motion char — gqq, linewise
-- format), then either the direct <C-o> path or the `` (double-backtick)
-- path — both fire gq_then_jumpback, see docs/adr/0022.
local function emit_gq_then_jumpback(rng, out)
  table.insert(out, 'g')
  table.insert(out, 'q')
  table.insert(out, 'q')
  if rand_int(rng, 1, 2) == 1 then
    table.insert(out, '\15')
  else
    table.insert(out, '`')
    table.insert(out, '`')
  end
end

local function emit_jump_back_gg_then_G(rng, out)
  table.insert(out, 'g')
  table.insert(out, 'g')
  table.insert(out, 'G')
end

local function emit_jump_back_G_then_gg(rng, out)
  table.insert(out, 'G')
  table.insert(out, 'g')
  table.insert(out, 'g')
end

local function emit_d_dollar(rng, out)
  table.insert(out, 'd')
  table.insert(out, '$')
end

local function emit_c_dollar(rng, out)
  table.insert(out, 'c')
  table.insert(out, '$')
end

local function emit_y_dollar(rng, out)
  table.insert(out, 'y')
  table.insert(out, '$')
end

-- manual_return: a jumplist-adding motion (G/n/N), then 5 manual
-- return-motion keystrokes (j/k/<C-e>/<C-y>, any mix) inside the 15s
-- tolerance window (real_model's STEP_MS clock keeps this well inside it —
-- see docs/adr/0019).
local JUMP_TRIGGERS = { 'G', 'n', 'N' }
local RETURN_KEYS = { 'j', 'k', '\5', '\25' }
local function emit_manual_return(rng, out)
  table.insert(out, JUMP_TRIGGERS[rand_int(rng, 1, #JUMP_TRIGGERS)])
  for _ = 1, 5 do
    table.insert(out, RETURN_KEYS[rand_int(rng, 1, #RETURN_KEYS)])
  end
end

-- changelist_return: two edit+move-away cycles (arming edit_second_seen),
-- then 5 j/k keystrokes — see docs/adr/0019. Uses 'x' (not an INSERT_KEYS
-- member) for the edits so this chunk can never also arm an unrelated
-- _then_insert pattern.
local function emit_changelist_return(rng, out)
  table.insert(out, 'x')
  table.insert(out, 'l')
  table.insert(out, 'x')
  for _ = 1, 5 do
    table.insert(out, rand_int(rng, 1, 2) == 1 and 'j' or 'k')
  end
end

local function emit_cursor_center_repeat(rng, out)
  for _ = 1, 5 do
    table.insert(out, rand_int(rng, 1, 2) == 1 and '\5' or '\25')
  end
end

-- ── dispatch table ───────────────────────────────────────────────────────
-- kind name -> { weight = <mixed-corpus weight>, emit = function(rng, out) }
local PATTERN_CHUNKS = {
  j_run = { weight = 6, emit = emit_j_run },
  k_run = { weight = 6, emit = emit_k_run },
  dd_run = { weight = 6, emit = emit_dd_run },
  indent_run = { weight = 4, emit = emit_indent_run },
  dedent_run = { weight = 4, emit = emit_dedent_run },
  r_run = { weight = 4, emit = emit_r_run },
  ctrl_w_close_run = { weight = 3, emit = emit_ctrl_w_close_run },
  ctrl_w_resize_run = { weight = 3, emit = emit_ctrl_w_resize_run },
  fold_open_run = {
    weight = 3,
    emit = function(rng, out)
      emit_fold_run(rng, out, 'o')
    end,
  },
  fold_close_run = {
    weight = 3,
    emit = function(rng, out)
      emit_fold_run(rng, out, 'c')
    end,
  },

  x_streak = {
    weight = 3,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'x', 6)
    end,
  },
  u_streak = {
    weight = 2,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'u', 6)
    end,
  },
  l_streak = {
    weight = 3,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'l', 8)
    end,
  },
  h_streak = {
    weight = 3,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'h', 8)
    end,
  },
  w_streak = {
    weight = 3,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'w', 8)
    end,
  },
  b_streak = {
    weight = 2,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'b', 8)
    end,
  },
  e_streak = {
    weight = 2,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'e', 8)
    end,
  },
  p_streak = {
    weight = 2,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'p', 6)
    end,
  },
  P_streak = {
    weight = 2,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'P', 6)
    end,
  },
  dot_streak = {
    weight = 2,
    emit = function(rng, out)
      emit_simple_streak(rng, out, '.', 6)
    end,
  },
  J_streak = {
    weight = 1,
    emit = function(rng, out)
      emit_simple_streak(rng, out, 'J', 6)
    end,
  },
  tilde_run = {
    weight = 3,
    emit = function(rng, out)
      emit_simple_streak(rng, out, '~', 14)
    end,
  },
  n_run = { weight = 2, emit = emit_n_run },
  n_then_change = { weight = 3, emit = emit_n_then_change },

  dd_then_insert = { weight = 4, emit = emit_dd_then_insert },
  dw_then_insert = { weight = 4, emit = emit_dw_then_insert },
  diw_then_insert = { weight = 4, emit = emit_diw_then_insert },
  x_then_insert = { weight = 3, emit = emit_x_then_insert },
  D_then_insert = { weight = 3, emit = emit_D_then_insert },
  zero_then_insert = { weight = 3, emit = emit_zero_then_insert },
  zero_col_then_insert = { weight = 3, emit = emit_zero_col_then_insert },
  zero_then_w = { weight = 3, emit = emit_zero_then_w },
  dollar_then_append = { weight = 3, emit = emit_dollar_then_append },
  k_then_o = { weight = 3, emit = emit_k_then_o },
  yy_then_p = { weight = 3, emit = emit_yy_then_p },
  dd_then_p = { weight = 3, emit = emit_dd_then_p },
  p_then_rightward = {
    weight = 3,
    emit = function(rng, out)
      emit_paste_then_rightward(rng, out, 'p')
    end,
  },
  P_then_rightward = {
    weight = 3,
    emit = function(rng, out)
      emit_paste_then_rightward(rng, out, 'P')
    end,
  },

  ci_dquote_run = {
    weight = 4,
    emit = function(rng, out)
      emit_ci_quote_run(rng, out, '"')
    end,
  },
  ci_squote_run = {
    weight = 4,
    emit = function(rng, out)
      emit_ci_quote_run(rng, out, "'")
    end,
  },

  ca_run = { weight = 3, emit = emit_ca_run },
  cx_run = { weight = 3, emit = emit_cx_run },
  v_repeat = { weight = 3, emit = emit_v_repeat },
  visual_textobj = { weight = 4, emit = emit_visual_textobj },

  gq_then_jumpback = { weight = 2, emit = emit_gq_then_jumpback },
  jump_back_gg_G = { weight = 2, emit = emit_jump_back_gg_then_G },
  jump_back_G_gg = { weight = 2, emit = emit_jump_back_G_then_gg },

  d_dollar = { weight = 3, emit = emit_d_dollar },
  c_dollar = { weight = 3, emit = emit_c_dollar },
  y_dollar = { weight = 3, emit = emit_y_dollar },

  manual_return = { weight = 2, emit = emit_manual_return },
  changelist_return = { weight = 2, emit = emit_changelist_return },
  cursor_center_repeat = { weight = 2, emit = emit_cursor_center_repeat },
}

-- All pattern-building chunk kinds this generator knows, with their default
-- (mixed-corpus) weights. M.generate's `only` parameter can restrict this to
-- a single kind (plus noise) for the "isolated" corpus — see its own doc
-- comment below for why that corpus exists alongside the full mixed one.
M.ALL_CHUNK_KINDS = {}
for name in pairs(PATTERN_CHUNKS) do
  table.insert(M.ALL_CHUNK_KINDS, name)
end
table.sort(M.ALL_CHUNK_KINDS) -- deterministic iteration order for the isolated-corpus describe loop

local NOISE_WEIGHT = 40

-- Generates a flat list of keystrokes (strings, using patterns.feed()'s own
-- raw-byte convention for control keys, e.g. '\23' for <C-w>).
--
-- rng: from M.new_rng(seed) — pass the SAME seed to reproduce the identical
-- sequence.
-- length: approximate number of chunks to emit (each chunk is 1-20 keys).
-- only: optional single chunk kind (a value from M.ALL_CHUNK_KINDS) to
--   restrict generation to — plain noise plus only that one pattern family.
--   Used for the "isolated" differential corpus, which builds exactly one
--   family's streak at a time so no OTHER family's compound can ever
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
    for name, spec in pairs(PATTERN_CHUNKS) do
      table.insert(chunk_emitters, { value = name, weight = spec.weight })
    end
  end
  for _ = 1, length do
    local kind = weighted_choice(rng, chunk_emitters)
    if kind == 'noise' then
      emit_noise(rng, out)
    else
      PATTERN_CHUNKS[kind].emit(rng, out)
    end
  end
  return out
end

-- ── contextual generators (is_diff / is_wrapped / line) ─────────────────────
-- The chunks above all assume is_diff = is_wrapped = false and a constant
-- line — correct for every pattern M.generate's chunks build toward. A
-- handful of patterns are gated on one of these three instead (or in
-- addition), so they need their own generator that also varies the relevant
-- contextual parameter, per issue #328's design guidance.

-- j/k runs under is_wrapped=true or is_diff=true — same shape as
-- M.generate's own j_run/k_run chunks, just wrapped with the flag the
-- differential spec should pass to BOTH models for the whole generated run.
-- kind: 'j_wrapped' | 'k_wrapped' | 'j_diff' | 'k_diff'.
local CONTEXT_RUN_KIND = {
  j_wrapped = { emit = emit_j_run, is_wrapped = true },
  k_wrapped = { emit = emit_k_run, is_wrapped = true },
  j_diff = { emit = emit_j_run, is_diff = true },
  k_diff = { emit = emit_k_run, is_diff = true },
}
M.CONTEXT_RUN_KINDS = { 'j_wrapped', 'k_wrapped', 'j_diff', 'k_diff' }

-- diff_jump_then_insert_next/_prev: ]c / [c (diff-hunk jump) immediately
-- followed by an insert trigger, only meaningful under is_diff=true — see
-- docs/adr/0099.
M.CONTEXT_DIFF_JUMP_KINDS = { 'diff_jump_insert_next', 'diff_jump_insert_prev' }

function M.generate_context(rng, length, kind)
  if kind == 'diff_jump_insert_next' or kind == 'diff_jump_insert_prev' then
    local keys =
      { kind == 'diff_jump_insert_next' and ']' or '[', 'c', INSERT_TRIGGERS[rand_int(rng, 1, #INSERT_TRIGGERS)] }
    return { keys = keys, is_diff = true, is_wrapped = false }
  end

  local spec = CONTEXT_RUN_KIND[kind]
  local keys = {}
  local chunk_emitters = { { value = 'noise', weight = NOISE_WEIGHT }, { value = 'run', weight = 20 } }
  for _ = 1, length do
    if weighted_choice(rng, chunk_emitters) == 'noise' then
      emit_noise(rng, keys)
    else
      spec.emit(rng, keys)
    end
  end
  return { keys = keys, is_diff = spec.is_diff or false, is_wrapped = spec.is_wrapped or false }
end

-- named_mark_opportunity needs the cursor to genuinely revisit the SAME line
-- 3+ times, with a real edit made away from it before each return —
-- patterns.lua reads this off the caller-supplied `line` parameter, not seq
-- state (docs/adr/0100), so (unlike every chunk above) this generator emits
-- { key=, line= } pairs instead of bare key strings.
--
-- Deliberately uses 'x' for the "edit away" step (not an INSERT_KEYS
-- member, so it can never also arm an unrelated _then_insert pattern) and
-- alternates j/k for the leave/return motion. Each cycle's 'x' always resets
-- changelist_return's own change_return_streak (x is not j/k), so this
-- sequence can never accidentally also arbitrate against changelist_return —
-- verified by hand tracing patterns.lua's edit_second_seen/change_return_streak
-- bookkeeping for this exact shape.
function M.generate_line_walk(cycles)
  local out = {}
  table.insert(out, { key = 'h', line = 1 }) -- establish the starting line
  for _ = 1, cycles do
    table.insert(out, { key = 'j', line = 2 }) -- leave the anchor
    table.insert(out, { key = 'x', line = 2 }) -- edit away from it
    table.insert(out, { key = 'k', line = 1 }) -- return to it
  end
  return out
end

return M
