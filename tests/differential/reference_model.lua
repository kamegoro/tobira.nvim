-- A deliberately SIMPLE, obviously-correct reference model of what
-- patterns.lua's seq state machine SHOULD do, across (almost) its entire
-- pattern surface — see tests/differential/patterns_seq_differential_spec.lua
-- for how this is run side-by-side against the real patterns.lua and
-- compared.
--
-- This is NOT a reimplementation of patterns.lua's shared pending-state
-- dispatcher (inner_feed). It shares no code and no data structure with it.
--
-- History: issue #316 (PR #323) scoped the first version of this file to 10
-- streak-based patterns (j_repeat/k_repeat/dd_run/indent_run/dedent_run/
-- r_run/ctrl_w_close_repeat/ctrl_w_resize_repeat/fold_open_repeat/
-- fold_close_repeat). Issue #328 expands it to every other pattern
-- patterns.lua can fire, EXCEPT two deliberately left unmodeled for the same
-- reason as the original 10-pattern scope's own precedent:
--   - macro_opportunity: its anchored 3x-repeat-window algorithm is its own
--     pre-existing, independently-tested subsystem (docs/adr/0018). Not
--     reimplemented; the differential spec feeds the same keys to the REAL
--     patterns.feed_macro() and checks it against every OTHER pattern this
--     file tracks for dispatch-priority collisions (docs/adr/0016, #312).
--   - visual_block_opportunity: shares macro_opportunity's own macro_buf
--     subsystem end to end (see patterns.lua's visual_block_check_len) —
--     same reasoning, same treatment.
--
-- Design rules, chosen to be verifiable by reading a few lines each (same
-- spirit as the original 10-pattern scope):
--
-- 1. A single shared `state.run = { key, count }` counter, updated
--    UNCONDITIONALLY at the very top of every M.step() call, models every
--    bare-key streak pattern (x_repeat, u_repeat, j_repeat/j_many,
--    k_repeat/k_many, l_repeat, h_repeat, w_repeat, b_repeat, e_repeat,
--    p_repeat, P_repeat, tilde_repeat/_word/_line, dot_repeat, J_repeat,
--    n_repeat) AND the reactive one-shot patterns that read the PREVIOUS
--    keystroke's run state (zero_then_w, zero_col_then_insert,
--    zero_then_insert, dollar_then_append, k_then_o, x_then_insert,
--    D_then_insert) — this is exactly docs/adr/0026's own stated "must
--    execute unconditionally on every key" intent for track_run(), which
--    issue #313 documents the real patterns.lua does NOT actually do for
--    several prefix-consumer branches. This model does what the ADR says
--    SHOULD happen; every place real patterns.lua's incomplete fix lets a
--    streak survive an unrelated compound is expected to surface as a
--    known-#313 divergence in the differential spec, not a bug in this file.
--
-- 2. Two-key compounds needing only mutual exclusion with NO further
--    internal grammar (<C-w>{q,c,+,-,<,>}, z{o,c}, r{char}) share a single
--    `state.pending` field, exactly as in the original 10-pattern scope.
--
-- 3. The d/c/y/>/</= operator-pending grammar (needed for dd_run/indent_run/
--    dedent_run plus the newly-modeled d$/c$/y$, dw/cw-family completions,
--    ciw/ci"/ci'/diw-family text objects, and their downstream reactive
--    patterns) gets its OWN `state.pending_op` field, mirroring
--    patterns.lua's real seq.pending_op — genuinely more structured than a
--    flat 2-key compound (count-prefix digits, text-object i/a routing,
--    linewise j/k, $ termination), so it is modeled as its own small
--    sub-machine rather than forced into the flat `pending` group.
--
-- 4. Starting ANY compound/operator/prefix (the `pending` group, pending_op,
--    <C-a>, v, gq/jump prefixes, mark/bracket prefixes) resets every OTHER
--    such family's own streak counter AND state.run — "a user typing an
--    unrelated command is clearly doing something else," same header rule
--    as the original 10-pattern scope, deliberately kept as a strict
--    superset of what patterns.lua's real, partial #313 fix actually
--    resets. `last_op` is the one deliberate exception — see its own
--    section below for why it is NOT reset by starters, matching real
--    patterns.lua's actual (documented, intentional) design.
--
-- Tolerance rules (which interrupting keys do NOT reset a streak) are
-- exactly the ones documented as INTENDED design in each pattern's own ADR:
-- h/l for r_run (docs/adr/0027), the fold navigation set for
-- fold_open_repeat/fold_close_repeat and reused for ci_dquote_repeat/
-- ci_squote_repeat (docs/adr/0108, docs/adr/0020).

local M = {}

-- \1 = <C-a>, \5 = <C-e>, \15 = <C-o>, \23 = <C-w>, \24 = <C-x>, \25 = <C-y>, \27 = <Esc>
-- (matches patterns.lua's own raw-byte convention).
local CTRL_A = '\1'
local CTRL_X = '\24'
local CTRL_E = '\5'
local CTRL_O = '\15'
local CTRL_W = '\23'
local CTRL_Y = '\25'
local ESC = '\27'

local INSERT_KEYS = { i = true, I = true, a = true, A = true, o = true, O = true, s = true, S = true }
local RIGHTWARD_KEYS = { l = true, w = true, W = true, e = true, E = true, ['$'] = true }
local EDIT_OP_KEYS = { x = true, X = true }
for k in pairs(INSERT_KEYS) do
  EDIT_OP_KEYS[k] = true
end
local JUMP_MOTION_KEYS = { G = true, n = true, N = true, ['\4'] = true, ['\21'] = true, ['\6'] = true, ['\2'] = true }
local RETURN_MOTION_KEYS = { j = true, k = true, [CTRL_E] = true, [CTRL_Y] = true }

-- Keys tolerated between r{char} replacements without resetting r_streak —
-- see docs/adr/0027-tolerated-motion-streaks-r-and-ctrl-a.md.
local R_TOLERATED = { h = true, l = true }

-- Keys tolerated between zo/zc repeats, and between ci"/ci' completions,
-- without resetting the respective streak — see
-- docs/adr/0108-fold-open-close-streak.md / docs/adr/0020-ci-quote-streak-and-tolerance.md.
local NAV_TOLERATED = {
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

-- Text-object characters that get their own tracked ci-quote streak
-- contribution — see docs/adr/0020-ci-quote-streak-and-tolerance.md.

local RETURN_THRESHOLD = 5 -- manual_return / changelist_return (docs/adr/0019)
local CURSOR_CENTER_THRESHOLD = 5 -- docs/adr/0097
local NAMED_MARK_THRESHOLD = 3 -- docs/adr/0100
local TOLERANCE_MS = 15000 -- docs/adr/0019

local TILDE_WORD_THRESHOLD = 6
local TILDE_LINE_THRESHOLD = 12

function M.new_state()
  return {
    -- shared bare-key streak counter — see header rule 1.
    run = { key = nil, count = 0 },

    -- nil | 'ctrl_w' | 'z' | 'r' — see header rule 2.
    pending = nil,
    dd_streak = 0,
    indent_streak = 0,
    dedent_streak = 0,
    r_streak = 0,
    ctrl_w_close_streak = 0,
    ctrl_w_resize_streak = 0,
    fold_open_streak = 0,
    fold_close_streak = 0,

    -- d/c/y/>/</= operator-pending grammar — see header rule 3.
    pending_op = nil,
    -- 'c' | 'd' | 'y' | nil — set when pending_op resolves to an i/a
    -- text-object prefix, consumed by the following key.
    pending_text_obj = nil,
    pending_text_obj_inner = false,
    ci_dquote_streak = 0,
    ci_squote_streak = 0,

    -- last completed compound this model cares about — see header rule 4's
    -- exception. nil | 'dd' | 'dw' | 'gg' | 'G' | 'gq' | 'yy'.
    last_op = nil,

    -- n-streak → reactive cgn watch — docs/adr/0107.
    n_watch = false,

    -- v/gv streak + visual text-object chain — docs/adr/0021.
    v_streak = 0,
    v_clean_exit = false,
    pending_visual = false,
    visual_inner = nil,
    visual_obj = nil,

    -- <C-a> sequential-increment streak — docs/adr/0027.
    ca_streak = 0,
    -- <C-x> sequential-decrement streak — mirrors ca_streak above, docs/adr/0027.
    cx_streak = 0,

    -- f/F/t/T repeat-search — needs same line + same char + same operator.
    pending_f = nil,
    last_f = nil,

    -- p/P → rightward-motion cursor-skip-past-paste — docs/adr/0025.
    pending_paste = nil,
    paste_motion_streak = 0,

    -- gg<->G jump_back + gq's own jumpback — docs/adr/0019, docs/adr/0022.
    pending_g = false,
    pending_gq = false,

    -- single-char prefix consumers that swallow exactly one following
    -- character with no further grammar — docs/adr/0023
    -- (register-mark-bracket-prefix-consumers). Modeled as their own fields
    -- (not folded into the ctrl_w/z/r `pending` group) because real
    -- patterns.lua keeps them as fully independent booleans too — see
    -- lua/tobira/CLAUDE.md's "patterns.lua — state machine" ordering rule.
    pending_register = false, -- '"' or '@'
    pending_clipboard_yank = false, -- '"+' immediately followed by 'y'
    clipboard_yank_tail = false,
    pending_mark = false, -- 'm' / "'" / '`'
    -- true only when the mark-prefix key just armed was '`' AND last_op was
    -- 'gq' at that moment — the one shape pending_mark's completion turns
    -- into a real fired pattern (gq_then_jumpback) instead of a silent
    -- consume — docs/adr/0022.
    pending_gq_backtick = false,

    -- ]c/[c diff-hunk jump → do/dp — docs/adr/0099.
    pending_bracket = nil,
    diff_jump_dir = nil,

    -- jumplist/changelist-underuse arbitration — docs/adr/0019.
    jump_last_at = nil,
    jump_return_streak = 0,
    ctrl_o_seen = false,
    edit_last_at = nil,
    edit_moved_away = false,
    edit_second_seen = false,
    change_return_streak = 0,
    g_semi_seen = false,

    -- cursor-centering streak — docs/adr/0097.
    zz_streak = 0,

    -- named-mark-opportunity line-return tracking — docs/adr/0100.
    mark_prev_line = nil,
    mark_anchor_line = nil,
    mark_return_count = 0,
    mark_left_anchor = false,
    mark_edited_away = false,
  }
end

-- Resets every streak-family counter EXCEPT `except` (a tag naming the
-- family whose own starter/continuation key was just pressed) — see header
-- rule 4. Deliberately does NOT touch last_op — see header rule 4's
-- exception and the file-level comment on last_op above.
local function reset_other_families(state, except)
  if except ~= 'dd' then
    state.dd_streak = 0
  end
  if except ~= 'indent' then
    state.indent_streak = 0
  end
  if except ~= 'dedent' then
    state.dedent_streak = 0
  end
  if except ~= 'r' then
    state.r_streak = 0
  end
  if except ~= 'ctrl_w' then
    state.ctrl_w_close_streak = 0
    state.ctrl_w_resize_streak = 0
  end
  if except ~= 'fold' then
    state.fold_open_streak = 0
    state.fold_close_streak = 0
  end
  if except ~= 'ca' then
    state.ca_streak = 0
  end
  if except ~= 'cx' then
    state.cx_streak = 0
  end
  if except ~= 'v' then
    state.v_streak = 0
    state.v_clean_exit = false
  end
  if except ~= 'run' then
    state.run = { key = nil, count = 0 }
  end
end

-- Resolves the `pending` mutual-exclusion group (ctrl_w/z/r) — identical
-- shape to the original 10-pattern scope.
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
  end
  return nil
end

local STARTER_PENDING = { [CTRL_W] = 'ctrl_w', z = 'z', r = 'r' }
local STARTER_EXCEPT = { ctrl_w = 'ctrl_w', z = 'fold', r = 'r' }

-- Resolves the d/c/y/>/</= operator-pending sub-machine — see header rule 3.
-- Mirrors patterns.lua's own pending_op block, condensed to only the
-- outcomes this model tracks a pattern for.
local function resolve_pending_op(state, op, key)
  if key:match('^[1-9]$') then
    return 'keep' -- count prefix; caller keeps pending_op set
  end
  if key == ESC then
    if op == 'c' then
      state.n_watch = false
    end
    return nil
  end

  if op == '>' or op == '<' then
    if key == op then
      if op == '>' then
        state.indent_streak = state.indent_streak + 1
        if state.indent_streak == 3 then
          state.indent_streak = 0
          return { pattern = 'indent_run', cmd = '{n}>>' }
        end
      else
        state.dedent_streak = state.dedent_streak + 1
        if state.dedent_streak == 3 then
          state.dedent_streak = 0
          return { pattern = 'dedent_run', cmd = '{n}<<' }
        end
      end
    else
      state.indent_streak = 0
      state.dedent_streak = 0
    end
    return nil
  end

  if op == 'y' then
    if key == 'y' then
      state.last_op = 'yy'
    elseif key == '$' then
      return { pattern = 'y_dollar', cmd = 'Y' }
    elseif key == 'i' or key == 'a' then
      state.pending_text_obj = 'y'
      state.pending_text_obj_inner = key == 'i'
    end
    return nil
  end

  -- op == 'd' or op == 'c'
  if key == '$' then
    if op == 'c' then
      state.n_watch = false
      return { pattern = 'c_dollar', cmd = 'C' }
    end
    return { pattern = 'd_dollar', cmd = 'D' }
  elseif key == op or key == 'j' or key == 'k' then
    state.last_op = 'dd' -- op..op is always 'dd'/'cc' in patterns.lua; only 'dd' feeds a tracked reactive pattern
    if op == 'c' then
      state.n_watch = false
    end
    if key == op and op == 'd' then
      state.dd_streak = state.dd_streak + 1
      if state.dd_streak == 3 then
        state.dd_streak = 0
        return { pattern = 'dd_run', cmd = '{n}dd' }
      end
    else
      state.dd_streak = 0
    end
    if op == 'c' then
      -- cc/cj/ck never become last_op == 'cw' — restore the pre-'dd'-clobber
      -- value semantics: cc-family completions are simply not 'dd'.
      state.last_op = nil
    end
  elseif key == 'i' or key == 'a' then
    state.pending_text_obj = op
    state.pending_text_obj_inner = key == 'i'
  else
    if op == 'd' then
      state.last_op = 'dw'
    end
    if op == 'c' and state.n_watch then
      state.n_watch = false
      return { pattern = 'n_then_change', cmd = 'cgn' }
    end
  end
  return nil
end

-- Resolves pending_text_obj (ciw/ci"/ci'/diw/yiw-family completions) — see
-- header rule 3 and docs/adr/0020/docs/adr/0106/docs/adr/0107.
local function resolve_pending_text_obj(state, op, inner, key)
  -- Real patterns.lua's pending_text_obj resolution unconditionally sets
  -- last_op = op..'w' for ANY op (d/c/y), BEFORE the ci-quote-streak checks
  -- below run — 'dw' is the one value this model's tracked reactive
  -- patterns read (dw_then_insert), so diw/daw/dit/... arms
  -- dw_then_insert exactly like a direct 'dw'/'d3w' would. 'cw'/'yw'
  -- themselves aren't read by anything this model tracks, but the
  -- assignment still OVERWRITES whatever last_op held before (e.g. a stale
  -- 'dd' from an earlier, not-yet-consumed completion) — this must apply
  -- unconditionally for every op, not only op=='c'.
  state.last_op = op .. 'w'

  if op == 'c' and inner and key == '"' then
    state.ci_squote_streak = 0
    state.ci_dquote_streak = state.ci_dquote_streak + 1
    if state.ci_dquote_streak >= 3 then
      state.ci_dquote_streak = 0
      return { pattern = 'ci_dquote_repeat', cmd = 'ya"' }
    end
  elseif op == 'c' and inner and key == "'" then
    state.ci_dquote_streak = 0
    state.ci_squote_streak = state.ci_squote_streak + 1
    if state.ci_squote_streak >= 3 then
      state.ci_squote_streak = 0
      return { pattern = 'ci_squote_repeat', cmd = "ya'" }
    end
  else
    state.ci_dquote_streak = 0
    state.ci_squote_streak = 0
  end

  -- n-streak → change the match: suggest cgn (text-object path, e.g. ciw,
  -- ci", cit). Checked after the ci-quote streaks above, REGARDLESS of
  -- whether this exact key matched '"'/"'" or not — real patterns.lua
  -- falls through to this check unconditionally when op=='c'; the
  -- ci-quote branches above only return early on their OWN 3x-threshold
  -- fire, never merely because the streak didn't (yet) qualify. See
  -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
  if op == 'c' and state.n_watch then
    state.n_watch = false
    return { pattern = 'n_then_change', cmd = 'cgn' }
  end

  return nil
end

-- Thresholds for the shared `state.run` bare-key streak counter. Each entry
-- fires exactly once (== not >=, matching patterns.lua) as the streak passes
-- through it, letting one key have multiple thresholds (j/k/tilde).
local RUN_THRESHOLDS = {
  x = { { count = 3, pattern = 'x_repeat', cmd = '{n}x' } },
  u = { { count = 3, pattern = 'u_repeat', cmd = '<C-r>' } },
  l = { { count = 5, pattern = 'l_repeat', cmd = 'w' } },
  h = { { count = 5, pattern = 'h_repeat', cmd = 'b' } },
  w = { { count = 5, pattern = 'w_repeat', cmd = 'W' } },
  b = { { count = 5, pattern = 'b_repeat', cmd = 'B' } },
  e = { { count = 5, pattern = 'e_repeat', cmd = 'ge' } },
  p = { { count = 3, pattern = 'p_repeat', cmd = '{n}p' } },
  P = { { count = 3, pattern = 'P_repeat', cmd = '{n}P' } },
  ['~'] = {
    { count = 3, pattern = 'tilde_repeat', cmd = '{n}~' },
    { count = TILDE_WORD_THRESHOLD, pattern = 'tilde_word_repeat', cmd = 'g~iw' },
    { count = TILDE_LINE_THRESHOLD, pattern = 'tilde_line_repeat', cmd = 'g~$' },
  },
  ['.'] = { { count = 3, pattern = 'dot_repeat', cmd = '{n}.' } },
  J = { { count = 3, pattern = 'J_repeat', cmd = '{n}J' } },
}

-- Fires at most one pattern per keystroke, mirroring patterns.feed()'s own
-- "return the first thing that fires" contract.
--
-- ctx (optional): { line=, is_diff=, is_wrapped=, now= }. line defaults to
-- 1 (matches the original 10-pattern scope's real_model.lua default); now
-- defaults to a monotonically-nil-safe 0 (jumplist/changelist tolerance
-- windows never expire against a caller that never advances the clock,
-- matching patterns.feed()'s own now-omitted behavior).
function M.step(state, key, ctx)
  ctx = ctx or {}
  local line = ctx.line or 1
  local is_diff = ctx.is_diff
  local is_wrapped = ctx.is_wrapped
  local now = ctx.now or 0

  -- ── unconditional bookkeeping (mirrors patterns.lua's own unconditional ──
  -- ── blocks, run before any dispatch) ──────────────────────────────────
  if EDIT_OP_KEYS[key] then
    if state.edit_last_at and state.edit_moved_away then
      state.edit_second_seen = true
    end
    state.edit_last_at = now
    state.edit_moved_away = false
  elseif state.edit_last_at and key ~= ESC then
    state.edit_moved_away = true
  end

  if key == CTRL_O then
    state.ctrl_o_seen = true
  end

  if key ~= 'n' and key ~= 'c' and state.pending_op ~= 'c' and state.pending_text_obj ~= 'c' then
    state.n_watch = false
  end

  if line ~= state.mark_prev_line then
    if state.mark_anchor_line == nil then
      if state.mark_prev_line ~= nil then
        state.mark_anchor_line = state.mark_prev_line
        state.mark_return_count = 0
        state.mark_left_anchor = true
        state.mark_edited_away = false
      end
    elseif line == state.mark_anchor_line then
      if state.mark_left_anchor and state.mark_edited_away then
        state.mark_return_count = state.mark_return_count + 1
      end
      state.mark_left_anchor = false
      state.mark_edited_away = false
    elseif state.mark_return_count == 0 then
      state.mark_anchor_line = state.mark_prev_line
      state.mark_left_anchor = true
      state.mark_edited_away = false
    else
      state.mark_left_anchor = true
    end
    state.mark_prev_line = line
  end
  if state.mark_anchor_line and state.mark_left_anchor and EDIT_OP_KEYS[key] then
    state.mark_edited_away = true
  end

  -- ── p/P → rightward motion: cursor skipped past a paste ──────────────
  if state.pending_paste then
    if RIGHTWARD_KEYS[key] then
      state.paste_motion_streak = state.paste_motion_streak + 1
      if state.paste_motion_streak >= 3 then
        local pasted = state.pending_paste
        state.pending_paste = nil
        state.paste_motion_streak = 0
        if pasted == 'p' then
          return { pattern = 'p_then_rightward', cmd = 'gp' }
        else
          return { pattern = 'P_then_rightward', cmd = 'gP' }
        end
      end
    elseif key ~= 'p' and key ~= 'P' then
      state.pending_paste = nil
      state.paste_motion_streak = 0
    end
  end

  -- ── gg/G jump_back + gq prefix ───────────────────────────────────────
  if state.pending_g then
    state.pending_g = false
    if key == 'q' then
      state.pending_gq = true
      return nil
    end
    if key == 'g' then
      local g_then_gg = state.last_op == 'G'
      state.last_op = 'gg'
      reset_other_families(state, nil)
      if g_then_gg then
        return { pattern = 'jump_back', cmd = "''" }
      end
    else
      reset_other_families(state, nil)
    end
    return nil
  end

  if state.pending_gq then
    if key:match('^[1-9]$') then
      return nil
    end
    state.pending_gq = false
    if key == ESC then
      return nil
    end
    if key == 'i' or key == 'a' then
      return nil -- gq{obj}: not one of this model's tracked completions
    end
    state.last_op = 'gq'
    return nil
  end

  -- ── ctrl_w / z / r mutual-exclusion group ─────────────────────────────
  if state.pending then
    local pending = state.pending
    state.pending = nil
    return resolve_pending(state, pending, key)
  end

  local starts = STARTER_PENDING[key]
  if starts then
    state.pending = starts
    reset_other_families(state, STARTER_EXCEPT[starts])
    return nil
  end

  -- ── single-char prefix consumers: "/@ (register), m/'/` (mark) ──────────
  -- Must precede pending_text_obj/pending_r/visual/f-F-t-T below, same
  -- ordering rule as ]/[ and the ctrl_w/z/r group above — a register or
  -- mark name that happens to collide with another prefix's own trigger
  -- character must be consumed here first. See docs/adr/0023
  -- (register-mark-bracket-prefix-consumers) and lua/tobira/CLAUDE.md's
  -- "patterns.lua — state machine" section.
  if state.pending_register then
    state.pending_register = false
    if key == '+' then
      state.pending_clipboard_yank = true
    end
    return nil
  end

  if state.pending_clipboard_yank then
    state.pending_clipboard_yank = false
    if key == 'y' then
      state.last_op = nil -- '"+y' is not a last_op value this model tracks
      state.clipboard_yank_tail = true
      return nil
    end
    -- falls through: a non-'y' key right after "+ is NOT consumed, exactly
    -- like real patterns.lua's own pending_clipboard_yank branch.
  end

  if state.clipboard_yank_tail then
    state.clipboard_yank_tail = false
    if key == 'y' then
      return nil
    end
    -- falls through, same reasoning as pending_clipboard_yank above.
  end

  if state.pending_mark then
    state.pending_mark = false
    local was_gq_backtick = state.pending_gq_backtick
    state.pending_gq_backtick = false
    if was_gq_backtick and key == '`' then
      state.last_op = nil
      return { pattern = 'gq_then_jumpback', cmd = 'gw' }
    end
    return nil
  end

  -- ── ]c / [c diff-hunk jump prefix ──────────────────────────────────────
  if state.pending_bracket then
    local bracket = state.pending_bracket
    state.pending_bracket = nil
    state.diff_jump_dir = (key == 'c') and bracket or nil
    return nil
  end

  -- ── pending_text_obj: ciw/ci"/ci'/diw/yiw-family completions ─────────
  if state.pending_text_obj then
    local op = state.pending_text_obj
    local inner = state.pending_text_obj_inner
    state.pending_text_obj = nil
    state.pending_text_obj_inner = false
    return resolve_pending_text_obj(state, op, inner, key)
  end

  -- ── visual text-object chain ───────────────────────────────────────────
  if state.visual_obj then
    if key == 'c' or key == 'd' or key == 'y' then
      local cmd = key .. state.visual_inner .. state.visual_obj
      state.visual_obj = nil
      state.visual_inner = nil
      return { pattern = 'visual_textobj', cmd = cmd }
    end
    state.visual_obj = nil
    state.visual_inner = nil
    -- falls through: this key still gets processed normally below, exactly
    -- like patterns.lua's own non-operator visual_obj branch.
  end

  if state.visual_inner then
    state.visual_obj = key
    return nil
  end

  if state.pending_visual then
    state.pending_visual = false
    if key == ESC then
      state.v_clean_exit = true
      if state.v_streak >= 3 then
        state.v_streak = 0
        return { pattern = 'v_repeat', cmd = 'gv' }
      end
      return nil
    end
    state.v_clean_exit = false
    state.v_streak = 0
    if key == 'i' or key == 'a' then
      state.visual_inner = key
    end
    return nil
  end

  -- ── f/F/t/T repeat search ──────────────────────────────────────────────
  if key == 'f' or key == 'F' or key == 't' or key == 'T' then
    state.pending_f = key
    reset_other_families(state, nil)
    return nil
  end
  if state.pending_f then
    local op = state.pending_f
    state.pending_f = nil
    local fired = nil
    if state.last_f and state.last_f.line == line and state.last_f.char == key and state.last_f.op == op then
      fired = { pattern = 'f_repeat', cmd = ';' }
    end
    state.last_f = { char = key, line = line, op = op }
    return fired
  end
  if state.last_f and state.last_f.line ~= line then
    state.last_f = nil
  end

  -- ── pending_op resolution ──────────────────────────────────────────────
  if state.pending_op then
    local op = state.pending_op
    local outcome = resolve_pending_op(state, op, key)
    if outcome ~= 'keep' then
      state.pending_op = nil
    end
    if outcome == 'keep' or outcome == nil then
      return nil
    end
    return outcome
  end

  -- ── pending_op starters ────────────────────────────────────────────────
  if key == 'd' or key == 'c' or key == 'y' or key == '>' or key == '<' or key == '=' then
    state.pending_op = key
    local except = (key == 'd' and 'dd') or (key == '>' and 'indent') or (key == '<' and 'dedent') or 'run'
    reset_other_families(state, except)
    return nil
  end

  -- ── r: single-char replace ────────────────────────────────────────────
  if key == 'r' then
    state.pending = 'r'
    reset_other_families(state, 'r')
    return nil
  end

  -- ── <C-a> sequential-increment streak ─────────────────────────────────
  if key == CTRL_A then
    state.ca_streak = state.ca_streak + 1
    reset_other_families(state, 'ca')
    if state.ca_streak >= 3 then
      state.ca_streak = 0
      return { pattern = 'ca_run', cmd = 'g<C-a>' }
    end
    return nil
  end

  -- ── <C-x> sequential-decrement streak ─────────────────────────────────
  -- Mirrors the <C-a> block above — see docs/adr/0027.
  if key == CTRL_X then
    state.cx_streak = state.cx_streak + 1
    reset_other_families(state, 'cx')
    if state.cx_streak >= 3 then
      state.cx_streak = 0
      return { pattern = 'cx_run', cmd = 'g<C-x>' }
    end
    return nil
  end

  -- ── v: visual streak + text-object chain start ────────────────────────
  if key == 'v' then
    state.v_streak = state.v_clean_exit and (state.v_streak + 1) or 1
    state.v_clean_exit = false
    state.pending_visual = true
    reset_other_families(state, 'v')
    return nil
  end

  -- ── g: two-key compound prefix (gg/gq only, in this model's scope) ────
  if key == 'g' then
    state.pending_g = true
    reset_other_families(state, nil)
    return nil
  end

  -- ── z: fold two-key compound prefix ────────────────────────────────────
  if key == 'z' then
    state.pending = 'z'
    reset_other_families(state, 'fold')
    return nil
  end

  -- ── <C-w>: window two-key compound prefix ──────────────────────────────
  if key == CTRL_W then
    state.pending = 'ctrl_w'
    reset_other_families(state, 'ctrl_w')
    return nil
  end

  -- ── [ / ]: bracket prefix (diff-hunk jump only, in this model's scope) ──
  if key == '[' or key == ']' then
    state.pending_bracket = key
    reset_other_families(state, nil)
    return nil
  end

  -- ── " / @ : register/macro-name prefix ─────────────────────────────────
  -- Consumes exactly one following character with no further grammar (see
  -- the consumer block above) — docs/adr/0023.
  if key == '"' or key == '@' then
    state.pending_register = true
    reset_other_families(state, nil)
    return nil
  end

  -- ── m / ' / ` : mark-name/target prefix ─────────────────────────────────
  -- Consumes exactly one following character, same shape as the register
  -- prefix above — except '`' additionally arms the gq-jumpback chain when
  -- it immediately follows a completed 'gq' (docs/adr/0022).
  if key == 'm' or key == "'" or key == '`' then
    state.pending_mark = true
    state.pending_gq_backtick = key == '`' and state.last_op == 'gq'
    reset_other_families(state, nil)
    return nil
  end

  -- ── r_streak tolerance (h/l) for keys reaching this far ────────────────
  if not R_TOLERATED[key] then
    state.r_streak = 0
  end
  -- ── ci-quote / fold streak tolerance for keys reaching this far ────────
  if not NAV_TOLERATED[key] then
    state.ci_dquote_streak = 0
    state.ci_squote_streak = 0
    state.fold_open_streak = 0
    state.fold_close_streak = 0
  end

  -- ── yy → p (duplicate line) / dd → p (swap lines) ──────────────────────
  if key == 'p' and state.last_op == 'yy' then
    state.last_op = nil
    state.pending_paste = 'p'
    state.paste_motion_streak = 0
    return { pattern = 'yy_then_p', cmd = 'yyp' }
  end
  if key == 'p' and state.last_op == 'dd' then
    state.last_op = nil
    state.dd_streak = 0
    state.pending_paste = 'p'
    state.paste_motion_streak = 0
    return { pattern = 'dd_then_p', cmd = 'ddp' }
  end

  -- ── dd → insert: suggest cc ─────────────────────────────────────────────
  if state.last_op == 'dd' and INSERT_KEYS[key] then
    state.last_op = nil
    state.dd_streak = 0
    return { pattern = 'dd_then_insert', cmd = 'cc' }
  end

  -- ── p / P: arm cursor-skip-past-paste tracking ─────────────────────────
  if key == 'p' or key == 'P' then
    state.pending_paste = key
    state.paste_motion_streak = 0
  end

  -- ── reactive one-shot checks reading the PREVIOUS keystroke's run ──────
  local prev_run_key, prev_run_count = state.run.key, state.run.count
  if key == 'w' and prev_run_key == '0' then
    return { pattern = 'zero_then_w', cmd = '^' }
  end
  if key == 'i' and prev_run_key == '0' then
    return { pattern = 'zero_col_then_insert', cmd = 'gI' }
  end
  if key == 'i' and prev_run_key == '^' then
    return { pattern = 'zero_then_insert', cmd = 'I' }
  end
  if key == 'a' and prev_run_key == '$' then
    return { pattern = 'dollar_then_append', cmd = 'A' }
  end
  if key == 'o' and prev_run_key == 'k' and prev_run_count == 1 then
    state.run = { key = nil, count = 0 }
    return { pattern = 'k_then_o', cmd = 'O' }
  end
  if INSERT_KEYS[key] and prev_run_key == 'x' and prev_run_count == 1 then
    state.run = { key = nil, count = 0 }
    return { pattern = 'x_then_insert', cmd = 's' }
  end
  if INSERT_KEYS[key] and prev_run_key == 'D' then
    return { pattern = 'D_then_insert', cmd = 'C' }
  end
  if state.last_op == 'dw' and INSERT_KEYS[key] then
    state.last_op = nil
    return { pattern = 'dw_then_insert', cmd = 'cw' }
  end
  if is_diff and state.diff_jump_dir and INSERT_KEYS[key] then
    local dir = state.diff_jump_dir
    state.diff_jump_dir = nil
    if dir == ']' then
      return { pattern = 'diff_jump_then_insert_next', cmd = 'do' }
    else
      return { pattern = 'diff_jump_then_insert_prev', cmd = 'dp' }
    end
  end
  if key == CTRL_O and state.last_op == 'gq' then
    state.last_op = nil
    return { pattern = 'gq_then_jumpback', cmd = 'gw' }
  end

  local gg_then_G = key == 'G' and state.last_op == 'gg'

  -- ── generic bottom reset (mirrors "if key ~= 'p' then ... end") ────────
  if key ~= 'p' then
    state.last_op = nil
    state.dd_streak = 0
    state.indent_streak = 0
    state.dedent_streak = 0
    state.ctrl_w_close_streak = 0
    state.ctrl_w_resize_streak = 0
    state.v_streak = 0
    state.v_clean_exit = false
  end
  state.diff_jump_dir = nil

  -- ── shared run counter: unconditional update (see header rule 1) ──────
  if key == state.run.key then
    state.run.count = state.run.count + 1
  else
    state.run = { key = key, count = 1 }
  end
  local count = state.run.count

  -- ── jumplist-underuse bookkeeping ──────────────────────────────────────
  local jump_ready = false
  if key == 'G' or JUMP_MOTION_KEYS[key] then
    state.jump_last_at = now
    state.jump_return_streak = 0
    if key == 'G' then
      state.last_op = 'G'
      if gg_then_G then
        return { pattern = 'jump_back', cmd = "''" }
      end
    end
  elseif RETURN_MOTION_KEYS[key] then
    if state.jump_last_at and not state.ctrl_o_seen and (now - state.jump_last_at) <= TOLERANCE_MS then
      state.jump_return_streak = state.jump_return_streak + 1
      if state.jump_return_streak == RETURN_THRESHOLD then
        jump_ready = true
      end
    else
      state.jump_return_streak = 0
    end
  else
    state.jump_return_streak = 0
  end

  -- ── changelist-underuse bookkeeping ─────────────────────────────────────
  local change_ready = false
  if key == 'j' or key == 'k' then
    if
      state.edit_second_seen
      and not state.g_semi_seen
      and state.edit_last_at
      and (now - state.edit_last_at) <= TOLERANCE_MS
    then
      state.change_return_streak = state.change_return_streak + 1
      if state.change_return_streak == RETURN_THRESHOLD then
        change_ready = true
      end
    else
      state.change_return_streak = 0
    end
  else
    state.change_return_streak = 0
  end

  -- ── cursor-centering streak ─────────────────────────────────────────────
  if key == CTRL_E or key == CTRL_Y then
    state.zz_streak = state.zz_streak + 1
  else
    state.zz_streak = 0
  end
  local zz_ready = state.zz_streak >= CURSOR_CENTER_THRESHOLD

  local mark_ready = state.mark_return_count >= NAMED_MARK_THRESHOLD

  -- ── arbitration (docs/adr/0019, docs/adr/0097, docs/adr/0100) ──────────
  if jump_ready and change_ready then
    state.zz_streak = 0
    if state.jump_last_at >= state.edit_last_at then
      state.jump_return_streak = 0
      state.jump_last_at = nil
      state.change_return_streak = 0
      return { pattern = 'manual_return', cmd = '<C-o>' }
    else
      state.change_return_streak = 0
      state.edit_second_seen = false
      state.edit_last_at = nil
      state.jump_return_streak = 0
      return { pattern = 'changelist_return', cmd = 'g;' }
    end
  elseif jump_ready then
    state.jump_return_streak = 0
    state.jump_last_at = nil
    state.zz_streak = 0
    return { pattern = 'manual_return', cmd = '<C-o>' }
  elseif change_ready then
    state.change_return_streak = 0
    state.edit_second_seen = false
    state.edit_last_at = nil
    state.zz_streak = 0
    return { pattern = 'changelist_return', cmd = 'g;' }
  elseif zz_ready then
    state.zz_streak = 0
    return { pattern = 'cursor_center_repeat', cmd = 'zz' }
  elseif mark_ready then
    state.mark_return_count = 0
    state.mark_anchor_line = nil
    state.mark_left_anchor = false
    state.mark_edited_away = false
    return { pattern = 'named_mark_opportunity', cmd = 'ma' }
  end

  -- ── bare-key streak thresholds ──────────────────────────────────────────
  if key == 'j' and count == 5 then
    return { pattern = is_wrapped and 'j_repeat_wrapped' or 'j_repeat', cmd = is_wrapped and 'gj' or '{n}j' }
  elseif key == 'j' and count == 10 then
    return { pattern = is_diff and 'j_many_diff' or 'j_many', cmd = is_diff and ']c' or '}' }
  elseif key == 'k' and count == 5 then
    return { pattern = is_wrapped and 'k_repeat_wrapped' or 'k_repeat', cmd = is_wrapped and 'gk' or '{n}k' }
  elseif key == 'k' and count == 10 then
    return { pattern = is_diff and 'k_many_diff' or 'k_many', cmd = is_diff and '[c' or '{' }
  elseif key == 'n' and count == 2 then
    state.n_watch = true
    return nil
  elseif key == 'n' and count == 4 then
    return { pattern = 'n_repeat', cmd = '{n}n' }
  end

  local thresholds = RUN_THRESHOLDS[key]
  if thresholds then
    for _, t in ipairs(thresholds) do
      if count == t.count then
        return { pattern = t.pattern, cmd = t.cmd }
      end
    end
  end

  return nil
end

-- The exact set of pattern names this model tracks — used by the
-- differential spec to decide whether a REAL result is even comparable.
-- Deliberately excludes macro_opportunity and visual_block_opportunity —
-- see this file's own header for why.
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

  x_repeat = true,
  u_repeat = true,
  l_repeat = true,
  h_repeat = true,
  w_repeat = true,
  b_repeat = true,
  e_repeat = true,
  p_repeat = true,
  P_repeat = true,
  tilde_repeat = true,
  tilde_word_repeat = true,
  tilde_line_repeat = true,
  dot_repeat = true,
  J_repeat = true,
  n_repeat = true,
  j_many = true,
  k_many = true,
  j_repeat_wrapped = true,
  k_repeat_wrapped = true,
  j_many_diff = true,
  k_many_diff = true,

  d_dollar = true,
  c_dollar = true,
  y_dollar = true,
  dollar_then_append = true,
  k_then_o = true,

  dd_then_insert = true,
  dw_then_insert = true,
  x_then_insert = true,
  D_then_insert = true,
  zero_then_insert = true,
  zero_col_then_insert = true,
  zero_then_w = true,
  diff_jump_then_insert_next = true,
  diff_jump_then_insert_prev = true,

  yy_then_p = true,
  dd_then_p = true,
  p_then_rightward = true,
  P_then_rightward = true,

  ci_dquote_repeat = true,
  ci_squote_repeat = true,
  n_then_change = true,

  v_repeat = true,
  visual_textobj = true,

  ca_run = true,
  cx_run = true,
  f_repeat = true,

  gq_then_jumpback = true,
  jump_back = true,

  manual_return = true,
  changelist_return = true,
  cursor_center_repeat = true,
  named_mark_opportunity = true,
}

return M
