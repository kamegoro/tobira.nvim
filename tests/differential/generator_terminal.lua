-- Seedable, weighted-random keystroke sequence generator for the
-- patterns_terminal.lua differential test (see reference_model_terminal.lua,
-- real_model_terminal.lua, and patterns_terminal_differential_spec.lua).
--
-- Uses the same Park-Miller "Minimal Standard" LCG as
-- tests/differential/generator.lua, for the same reason: byte-for-byte
-- identical output across PUC Lua and LuaJIT for a given integer seed, which
-- is what makes "paste the seed back into generator_terminal.new_rng()"
-- reproduction reliable. See that file's header for the full rationale; not
-- repeated here.
--
-- Unlike generator.lua, output here is a flat list of RAW vim.on_key()-shaped
-- key strings, not canonical key names — this suite's real dispatch layer
-- (real_model_terminal.lua) tests the raw-byte-to-canonical translation
-- itself, so the generator has to hand it real bytes. NOISE_POOL below is
-- built from an empirical probe of vim.api.nvim_replace_termcodes() (see
-- issue #331's PR description for the probe output): every entry is either a
-- single byte (plain control keys) or the K_SPECIAL-prefixed multi-byte
-- string Neovim actually uses internally for special/Meta keys — never the
-- naive assumption that <M-x> arrives as a separate <Esc> byte followed by
-- 'x' (it doesn't; it's one atomic 4-byte sequence, confirmed by the probe).

local M = {}

local PARK_MILLER_MODULUS = 2147483647
local PARK_MILLER_MULTIPLIER = 16807

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

local function termcode(name)
  return vim.api.nvim_replace_termcodes(name, true, true, true)
end

-- ── realistic terminal-job-adjacent noise pool ──────────────────────────────
-- Every one of these is a plausible raw keystroke while sitting in an
-- interactive shell or REPL inside a :terminal buffer, and every one must
-- canonicalize to nil (never '<Esc>') per docs/adr/0001. Weighted roughly
-- toward realistic shell usage: printable typing dominates, readline-style
-- control keys and history navigation appear regularly, the escape hatch
-- itself and Meta chords appear occasionally (specifically to prove they
-- never get mistaken for part of an <Esc> streak).
local NOISE_POOL = {
  -- ordinary shell typing
  { value = 'l', weight = 6 },
  { value = 's', weight = 6 },
  { value = ' ', weight = 5 },
  { value = '-', weight = 3 },
  { value = '3', weight = 2 },
  -- readline-style shell editing (Ctrl-A/E/U/K/W, Ctrl-R reverse-search)
  { value = termcode('<C-a>'), weight = 3 },
  { value = termcode('<C-e>'), weight = 3 },
  { value = termcode('<C-u>'), weight = 2 },
  { value = termcode('<C-k>'), weight = 2 },
  { value = termcode('<C-w>'), weight = 3 },
  { value = termcode('<C-r>'), weight = 3 },
  -- job control / common shell interrupts
  { value = termcode('<C-c>'), weight = 3 },
  { value = termcode('<C-d>'), weight = 1 },
  { value = termcode('<C-l>'), weight = 2 },
  -- line submission / editing
  { value = termcode('<CR>'), weight = 4 },
  { value = termcode('<Tab>'), weight = 3 },
  { value = termcode('<BS>'), weight = 4 },
  -- shell history navigation (K_SPECIAL-prefixed multi-byte raw sequences)
  { value = termcode('<Up>'), weight = 3 },
  { value = termcode('<Down>'), weight = 2 },
  { value = termcode('<Left>'), weight = 2 },
  { value = termcode('<Right>'), weight = 2 },
  -- a Meta/Alt chord (one atomic raw sequence, never a split <Esc>+char —
  -- see this file's header) — occasional, e.g. bash's Alt-b/Alt-f word nav
  { value = termcode('<M-x>'), weight = 2 },
  -- the escape hatch this whole feature exists to suggest, typed for real —
  -- must never itself contribute to a future streak
  { value = termcode('<C-\\>'), weight = 1 },
  { value = termcode('<C-n>'), weight = 1 },
}

local function emit_noise(rng, out)
  table.insert(out, weighted_choice(rng, NOISE_POOL))
end

local ESC_BYTE = termcode('<Esc>')

-- A single, isolated <Esc> — the ordinary, ineffective-detection-must-NOT-fire
-- case (REPL cancel, dismissing a prompt, etc. — see ADR).
local function emit_single_esc(rng, out)
  table.insert(out, ESC_BYTE)
end

-- N consecutive <Esc> presses with nothing in between, N in [min_reps,
-- max_reps] — covers under-threshold (1), at-threshold (2), and
-- well-past-threshold (3+, exercising the fire-once latch) in one generator.
local function emit_esc_streak(rng, out, min_reps, max_reps)
  for _ = 1, rand_int(rng, min_reps, max_reps) do
    table.insert(out, ESC_BYTE)
  end
end

local CHUNK_KINDS = {
  { value = 'noise', weight = 55 },
  { value = 'single_esc', weight = 15 },
  { value = 'esc_streak', weight = 30 },
}

-- Generates a flat list of raw vim.on_key()-shaped keystroke strings.
--
-- rng: from M.new_rng(seed).
-- length: approximate number of chunks to emit (each chunk is 1-6 keys).
function M.generate(rng, length)
  local out = {}
  for _ = 1, length do
    local kind = weighted_choice(rng, CHUNK_KINDS)
    if kind == 'noise' then
      emit_noise(rng, out)
    elseif kind == 'single_esc' then
      emit_single_esc(rng, out)
    elseif kind == 'esc_streak' then
      emit_esc_streak(rng, out, 1, 6)
    end
  end
  return out
end

return M
