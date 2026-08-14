-- A deliberately SIMPLE, obviously-correct reference model of what the
-- streak-based subset of patterns.lua's seq state machine SHOULD do.
--
-- This is NOT a reimplementation of patterns.lua's shared pending-state
-- dispatcher (inner_feed). It shares no code and no data structure with it.
-- See tests/differential/patterns_seq_differential_spec.lua for how
-- this is run side-by-side against the real patterns.lua and compared.
--
-- Patterns modeled (per issue #316's scope): j_repeat, k_repeat, dd_run,
-- indent_run, dedent_run, r_run, ctrl_w_close_repeat, ctrl_w_resize_repeat,
-- fold_open_repeat, fold_close_repeat. macro_opportunity itself is NOT
-- reimplemented here (its anchored-window-match algorithm is its own
-- pre-existing, independently-tested subsystem, see docs/adr/0018) —
-- instead the differential spec feeds the same keys to the REAL
-- patterns.feed_macro() and checks it against these 10 patterns for
-- dispatch-priority collisions (the "macro-opportunity collision surface"
-- issue #316 calls out).
--
-- Two design rules, chosen to be verifiable by reading a few lines each:
--
-- 1. j_repeat/k_repeat count the RAW key value on every single keystroke,
--    unconditionally — this is exactly what docs/adr/0026's own stated
--    "must execute unconditionally on every key" design says track_run()
--    should do (issue #313 is that patterns.lua's real track_run() does
--    NOT actually do this for several prefix-consumer branches). This
--    model does what the ADR says SHOULD happen.
--
-- 2. The other 8 patterns are two-key compounds (<C-w>{q,c,+,-,<,>},
--    z{o,c}, r{char}, d/d, >/>, </<). AT MOST ONE such compound can be
--    "awaiting its second key" at a time — modeled as a single
--    `state.pending` field, not six independent booleans — so a resolving
--    key for one compound (e.g. the '<' of "<C-w><") can never also be
--    misread as the STARTING key of a different compound (dedent_run's own
--    '<' trigger). Real patterns.lua gets this right via its own ordered,
--    mutually-exclusive pending_* dispatch (only one pending_* field is
--    ever true at a time; setting one always fully resolves before another
--    can start) — this model just needs the same mutual-exclusivity
--    property, not the same code.
--
-- Tolerance rules (which interrupting keys do NOT reset a streak) are
-- exactly the ones documented as INTENDED design in each pattern's own ADR:
-- h/l for r_run (docs/adr/0027), the fold navigation set for
-- fold_open_repeat/fold_close_repeat (docs/adr/0108). Starting ANY of the 6
-- compounds above resets every OTHER compound's streak (a user typing an
-- unrelated two-key command is clearly "doing something else") — this is a
-- strict superset of the fix ADR 0108 actually shipped (which only made
-- d/c/y/>/</= resets ctrl_w+fold, and left "does starting r/z/<C-w> reset
-- dd/indent/dedent and vice versa" an explicitly-deferred, open question —
-- see its Consequences section). Modeling the fully-symmetric version here
-- is deliberate: divergences it surfaces against the real (incomplete)
-- implementation are exactly more evidence for issue #313's own "apply the
-- same rule to any new two-or-more-key command prefix" — see the
-- differential spec's KNOWN_GAP-labeled scenarios.

local M = {}

-- \23 = <C-w> raw byte (matches patterns.lua's own raw-byte convention).
local CTRL_W = '\23'

-- Keys tolerated between r{char} replacements without resetting r_streak —
-- see docs/adr/0027-tolerated-motion-streaks-r-and-ctrl-a.md.
local R_TOLERATED = { h = true, l = true }

-- Keys tolerated between zo/zc repeats without resetting fold streaks — see
-- docs/adr/0108-fold-open-close-streak.md ("reuses CI_QUOTE_NAV_KEYS").
local FOLD_TOLERATED = {
  w = true,
  b = true,
  e = true,
  h = true,
  l = true,
  j = true,
  k = true,
  ['0'] = true,
  ['^'] = true,
  ['$'] = true,
}

function M.new_state()
  return {
    j_key = nil,
    j_count = 0,
    k_key = nil,
    k_count = 0,

    -- nil | 'ctrl_w' | 'z' | 'r' | 'd' | 'gt' | 'lt' — see header.
    pending = nil,

    dd_streak = 0,
    indent_streak = 0,
    dedent_streak = 0,
    r_streak = 0,
    ctrl_w_close_streak = 0,
    ctrl_w_resize_streak = 0,
    fold_open_streak = 0,
    fold_close_streak = 0,
  }
end

-- Resets every OTHER compound family's streak, leaving `except` (the family
-- whose own starter key was just pressed — e.g. a fresh 'd' beginning a NEW
-- rep of an in-progress dd_run) untouched. Starting a rep of the SAME
-- family is the pattern continuing, not "doing something else" — only
-- starting a DIFFERENT family's compound should break it.
local function reset_other_compound_streaks(state, except)
  if except ~= 'd' then
    state.dd_streak = 0
  end
  if except ~= 'gt' then
    state.indent_streak = 0
  end
  if except ~= 'lt' then
    state.dedent_streak = 0
  end
  if except ~= 'r' then
    state.r_streak = 0
  end
  if except ~= 'ctrl_w' then
    state.ctrl_w_close_streak = 0
    state.ctrl_w_resize_streak = 0
  end
  if except ~= 'z' then
    state.fold_open_streak = 0
    state.fold_close_streak = 0
  end
end

-- Resolves the currently-pending two-key compound with `key` as its second
-- key. Always consumes the key (state.pending is already cleared by the
-- caller) — mirrors every pending_* branch in patterns.lua accepting
-- whatever the next key turns out to be, recognized target or not.
local function resolve_pending(state, pending, key)
  if pending == 'ctrl_w' then
    if key == 'q' or key == 'c' then
      state.ctrl_w_close_streak = state.ctrl_w_close_streak + 1
      state.ctrl_w_resize_streak = 0
      if state.ctrl_w_close_streak == 2 then
        state.ctrl_w_close_streak = 0
        return { pattern = 'ctrl_w_close_repeat', cmd = '<C-w>o' }
      end
    elseif key == '+' or key == '-' or key == '<' or key == '>' then
      state.ctrl_w_resize_streak = state.ctrl_w_resize_streak + 1
      state.ctrl_w_close_streak = 0
      if state.ctrl_w_resize_streak == 2 then
        state.ctrl_w_resize_streak = 0
        return { pattern = 'ctrl_w_resize_repeat', cmd = '<C-w>=' }
      end
    else
      state.ctrl_w_close_streak = 0
      state.ctrl_w_resize_streak = 0
    end
  elseif pending == 'z' then
    if key == 'o' then
      state.fold_open_streak = state.fold_open_streak + 1
      state.fold_close_streak = 0
      if state.fold_open_streak == 2 then
        state.fold_open_streak = 0
        return { pattern = 'fold_open_repeat', cmd = 'zR' }
      end
    elseif key == 'c' then
      state.fold_close_streak = state.fold_close_streak + 1
      state.fold_open_streak = 0
      if state.fold_close_streak == 2 then
        state.fold_close_streak = 0
        return { pattern = 'fold_close_repeat', cmd = 'zM' }
      end
    else
      state.fold_open_streak = 0
      state.fold_close_streak = 0
    end
  elseif pending == 'r' then
    state.r_streak = state.r_streak + 1
    if state.r_streak == 3 then
      state.r_streak = 0
      return { pattern = 'r_run', cmd = 'R' }
    end
  elseif pending == 'd' then
    if key == 'd' then
      state.dd_streak = state.dd_streak + 1
      if state.dd_streak == 3 then
        state.dd_streak = 0
        return { pattern = 'dd_run', cmd = '{n}dd' }
      end
    else
      state.dd_streak = 0
    end
  elseif pending == 'gt' then
    if key == '>' then
      state.indent_streak = state.indent_streak + 1
      if state.indent_streak == 3 then
        state.indent_streak = 0
        return { pattern = 'indent_run', cmd = '{n}>>' }
      end
    else
      state.indent_streak = 0
    end
  elseif pending == 'lt' then
    if key == '<' then
      state.dedent_streak = state.dedent_streak + 1
      if state.dedent_streak == 3 then
        state.dedent_streak = 0
        return { pattern = 'dedent_run', cmd = '{n}<<' }
      end
    else
      state.dedent_streak = 0
    end
  end
  return nil
end

local STARTER_PENDING = {
  [CTRL_W] = 'ctrl_w',
  z = 'z',
  r = 'r',
  d = 'd',
  ['>'] = 'gt',
  ['<'] = 'lt',
}

-- Fires at most one pattern per keystroke, mirroring patterns.feed()'s own
-- "return the first thing that fires" contract.
function M.step(state, key)
  local fired = nil

  -- ── j / k plain-motion streaks ──────────────────────────────────────────
  -- Unconditional, every keystroke, using the raw key value — see header
  -- rule 1 (docs/adr/0026's own stated intent).
  if key == state.j_key then
    state.j_count = state.j_count + 1
  else
    state.j_key = (key == 'j') and 'j' or nil
    state.j_count = (key == 'j') and 1 or 0
  end
  if state.j_count == 5 then
    fired = { pattern = 'j_repeat', cmd = '{n}j' }
  end

  if key == state.k_key then
    state.k_count = state.k_count + 1
  else
    state.k_key = (key == 'k') and 'k' or nil
    state.k_count = (key == 'k') and 1 or 0
  end
  if state.k_count == 5 then
    fired = fired or { pattern = 'k_repeat', cmd = '{n}k' }
  end

  -- ── two-key compounds: at most one pending at a time ────────────────────
  if state.pending then
    local pending = state.pending
    state.pending = nil
    return fired or resolve_pending(state, pending, key)
  end

  local starts = STARTER_PENDING[key]
  if starts then
    state.pending = starts
    -- Starting any compound is "doing something else" relative to every
    -- OTHER compound's in-progress streak — see header. Does not touch the
    -- streak of the family being started (see reset_other_compound_streaks).
    reset_other_compound_streaks(state, starts)
    return fired
  end

  -- ── ordinary key: hard-reset dd/indent/dedent/ctrl_w; fold/r reset ──────
  -- unless tolerated (ADR 0027 / ADR 0108).
  state.dd_streak = 0
  state.indent_streak = 0
  state.dedent_streak = 0
  state.ctrl_w_close_streak = 0
  state.ctrl_w_resize_streak = 0
  if not R_TOLERATED[key] then
    state.r_streak = 0
  end
  if not FOLD_TOLERATED[key] then
    state.fold_open_streak = 0
    state.fold_close_streak = 0
  end

  return fired
end

-- The exact set of pattern names this model tracks — used by the
-- differential spec to decide whether a REAL result is even comparable
-- (a real firing of some pattern outside this set, e.g. x_then_insert, is
-- not a divergence — this model has no opinion about it).
M.TRACKED_PATTERNS = {
  j_repeat = true,
  k_repeat = true,
  dd_run = true,
  indent_run = true,
  dedent_run = true,
  r_run = true,
  ctrl_w_close_repeat = true,
  ctrl_w_resize_repeat = true,
  fold_open_repeat = true,
  fold_close_repeat = true,
}

return M
