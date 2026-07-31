-- Pure pattern detection. No vim.* calls.
-- feed() mutates seq in place and returns a fired pattern or nil.

local M = {}

function M.new_seq()
  return {
    pending_f = nil,
    last_f = nil,
    pending_op = nil,
    last_op = nil,
    run = { key = nil, count = 0 },
    pending_text_obj = nil,
    dd_streak = 0,
    cc_streak = 0,
    indent_streak = 0,
    dedent_streak = 0,
    -- r-replacement tracking: r{char} l r{char} l r{char} → R
    pending_r = false,
    r_streak = 0,
    -- <C-a> sequential-increment tracking: <C-a> j <C-a> j <C-a> → g<C-a>
    ca_streak = 0,
    -- visual text-object tracking: v i {obj} c/d/y → c/d/yiw etc.
    pending_visual = false,
    visual_inner = nil,
    visual_obj = nil,
    -- v <Esc> v <Esc> v run tracking → gv (#55). v_streak counts consecutive
    -- "v then immediate <Esc>, nothing else" cycles; v_clean_exit remembers
    -- whether the cycle that just ended was one of those (vs. real visual
    -- usage) so the next v knows whether to extend the streak or restart it.
    v_streak = 0,
    v_clean_exit = false,
    pending_g = false,
    pending_z = false,
    -- gq operator-pending tracking: unlike the simple two-key pending_g
    -- targets (gg, gj, gd, …), gq is a real Vim operator that needs a further
    -- motion (gqq, gqap, gq}) before it's complete — see pending_gq below.
    pending_gq = false,
    pending_gq_text_obj = false,
    -- true only while the immediately-preceding mark-prefix key (`) started
    -- right after a completed gq — lets the very next key tell "`` (jump back,
    -- suggest gw)" apart from an unrelated "`a (jump to mark a)".
    pending_gq_backtick = false,
    pending_ctrl_w = false,
    -- <C-w>q / <C-w>c repeated (or alternated) 2+ times in a row → <C-w>o
    ctrl_w_close_streak = 0,
    -- prefixes that consume exactly one following character
    pending_register = false, -- " or @ (register / macro name)
    pending_mark = false, -- m / ' / ` (mark name or target)
    pending_bracket = false, -- [ or ] (navigation pair)
    -- "+ immediately followed by y → "+y system-clipboard yank. Set by
    -- pending_register below only when the register was '+'.
    pending_clipboard_yank = false,
    -- Guards exactly one key after "+y: without it, a following 'y' (as in
    -- "+yy) falls through to the operator-start branch and sets a dangling
    -- pending_op = 'y' that silently eats the next real keystroke (bug: "+yy
    -- + 5 j's needed a 6th to fire j_repeat).
    clipboard_yank_tail = false,
    pending_paste = nil, -- 'p' | 'P' | nil
    paste_motion_streak = 0,
    -- set true by M.feed when the key was the second char of a compound;
    -- logger uses this to skip standalone TRACK counting for that key
    key_consumed = false,
    -- True on the call that freshly sets last_op. logger.lua increments
    -- usage from this flag rather than diffing last_op's value, because a
    -- value diff can't tell "same compound completed again" from "nothing
    -- happened" — undercounted back-to-back repeats like dd dd.
    op_completed = false,
    -- jumplist-underuse tracking — see JUMP_MOTION_KEYS / RETURN_MOTION_KEYS
    -- below for what counts as a "jump" vs a "return" motion. now is
    -- caller-supplied so this file stays vim.*-free.
    jump_last_at = nil,
    jump_return_streak = 0,
    ctrl_o_seen = false,
    -- changelist-underuse tracking — see inner_feed's "changelist-underuse
    -- bookkeeping" section below for what each field tracks and why.
    edit_last_at = nil,
    edit_moved_away = false,
    edit_second_seen = false,
    change_return_streak = 0,
    -- Mirrors ctrl_o_seen (for g;).
    g_semi_seen = false,
    -- Array of { tok, t, nav_run } entries fed by M.feed_macro() (below) from
    -- BOTH normal- and insert-mode branches of logger.lua's handle_key() —
    -- unlike this seq's other fields, which are normal-mode only.
    macro_buf = {},
  }
end

local INSERT_KEYS = {
  i = true,
  I = true,
  a = true,
  A = true,
  o = true,
  O = true,
  s = true,
  S = true,
}

-- Motion keys that move the cursor rightward on the current line — the set
-- checked by the p/P → gp/gP cursor-skip-past-paste pattern.
local RIGHTWARD_KEYS = {
  l = true,
  w = true,
  W = true,
  e = true,
  E = true,
  ['$'] = true,
}

-- ── jumplist / changelist underuse detection ────────────────────────────────
-- Tolerance window: long enough to catch a real "read a few lines, then
-- scroll back" case, short enough that an unrelated jump from minutes ago
-- doesn't get blamed for an unrelated manual scroll now.
local JUMP_TOLERANCE_MS = 15000
local CHANGE_TOLERANCE_MS = 15000
local RETURN_MOTION_THRESHOLD = 5

-- Keys that mean "the user just made a big navigational jump" — the same
-- class of motion that adds a jumplist entry. 'gg' is deliberately absent:
-- it only resolves inside the pending_g dispatch table below (neither 'g'
-- keystroke of "gg" ever reaches this table on its own), so it is recorded
-- there instead. '/' is deliberately absent too — pressing '/' opens the
-- command-line, and logger.lua resets patterns.lua's whole seq for every
-- keystroke while mode is neither normal nor insert (see lua/tobira/CLAUDE.md
-- and logger.lua's handle_key), so a literal '/' key can never reliably
-- survive long enough to matter here.
local JUMP_MOTION_KEYS = {
  G = true,
  n = true,
  N = true,
  ['\4'] = true, -- <C-d>
  ['\21'] = true, -- <C-u>
  ['\6'] = true, -- <C-f>
  ['\2'] = true, -- <C-b>
}

-- Keys that mean "the user is manually stepping/scrolling back" — the
-- evidence that <C-o> (jumplist back) would have done in one keystroke.
local RETURN_MOTION_KEYS = {
  j = true,
  k = true,
  ['\5'] = true, -- <C-e>
  ['\25'] = true, -- <C-y>
}

-- Keys that mutate the buffer directly — either by entering insert mode
-- (INSERT_KEYS) or editing without leaving normal mode (x/X). Each is a
-- point where Vim would add a changelist entry.
local EDIT_OP_KEYS = { x = true, X = true }
for k in pairs(INSERT_KEYS) do
  EDIT_OP_KEYS[k] = true
end

-- ── macro opportunity detection ──────────────────────────────────────────────
-- Watches for the user manually repeating an identical edit sequence 3+ times
-- — exactly the case where recording a macro (qq...q, then @q) would pay off.
--
-- Uses its own rolling buffer (seq.macro_buf), NOT suggest.lua's 20-char one
-- (a different purpose — watching adoption of an already-shown suggestion —
-- and far too short to hold 3 reps of a 15-key sequence).
--
-- Fed through its own M.feed_macro() entry point rather than folded into
-- inner_feed(): the repeated *edit* this cares about (e.g. "cwFooBar<Esc>")
-- spans into insert mode, and piping those characters through inner_feed
-- would corrupt its normal-mode operator-pending grammar (a stray "F" while
-- pending_op is set would misfire as a find-command). Same shape of problem
-- patterns_insert.lua's feed_after_escape() solves one file over. See
-- logger.lua's handle_macro_key() for where both mode branches feed this.
--
-- The pitfall this is designed around: a naive per-character classifier
-- ("h/j/k/l/w/b/e/W/B/E/0/$/^ are motion keys — scan for motion runs")
-- misfires on this feature's own headline example — `cwFooBar<Esc>` contains
-- a lowercase `w` and uppercase `B`, both motion keys, so a naive scanner
-- would treat characters INSIDE the repeated sequence as navigation BETWEEN
-- repetitions.
--
-- The fix: find anchored, exact matches of a candidate length-L window
-- against EARLIER buffer content, and only apply the "gap must be pure
-- navigation" check to keys strictly BETWEEN two matched occurrences — never
-- to characters inside an occurrence itself.
--
-- Performance: bounded, not a rescan-per-keystroke. L ranges over
-- [MACRO_MIN_LEN, MACRO_MAX_LEN]; how far back each L searches is capped by
-- that position's navigation-key streak (nav_run, O(1) per keystroke, same
-- as seq.run) at MACRO_MAX_GAP — so the common case tries one candidate per
-- L, widening only when a real navigation streak exists to search across.
local MACRO_MIN_LEN = 3
local MACRO_MAX_LEN = 15
local MACRO_MAX_GAP = 20 -- max navigation keys allowed in one gap between reps
local MACRO_WINDOW_MS = 30000 -- all 3 occurrences must fall within this span
local MACRO_BUF_SOFT_CAP = 100 -- trimmed back down to this once the hard cap is hit
local MACRO_BUF_HARD_CAP = 150

-- Keys allowed in the gap BETWEEN two matched occurrences of S. Deliberately
-- the exact set named in the pitfall description above — membership in this
-- set is only ever consulted for gap positions, never used to decide whether
-- characters inside an already-anchored S count as "the same edit" or not.
local MACRO_NAV_KEYS = {
  h = true,
  j = true,
  k = true,
  l = true,
  w = true,
  b = true,
  e = true,
  W = true,
  B = true,
  E = true,
  ['0'] = true,
  ['$'] = true,
  ['^'] = true,
}
for d = 1, 9 do
  MACRO_NAV_KEYS[tostring(d)] = true
end

-- Keys that count as a genuine edit, for macro_contains_edit below — reuses
-- EDIT_OP_KEYS (x/X plus every INSERT_KEYS entry) and the same d/c/y/>/<
-- operator-start set inner_feed() checks via `==` chains further down (named
-- here as a table since this second use needs membership testing).
local MACRO_EDIT_KEYS = { d = true, c = true, y = true, ['>'] = true, ['<'] = true }
for k in pairs(EDIT_OP_KEYS) do
  MACRO_EDIT_KEYS[k] = true
end

-- S (buf[s_start..s_end]) must contain at least one genuine edit keystroke
-- to be a real candidate — not just any 3+ exact repeat of a nav-only window
-- (follow-up bug: "jjjjjjjjjjjj" and "0fh0fh0fh0fh" both satisfied every
-- other check, since the anchored-match algorithm only inspects the GAP
-- between occurrences for navigation-key membership, and neither repro has a
-- gap at all — the repeats are back-to-back).
--
-- Deliberately "at least one edit key ANYWHERE in S", not "S isn't entirely
-- MACRO_NAV_KEYS": those framings differ — a key in neither set (e.g. G, n)
-- would make "entirely nav" wrongly pass despite zero real edits.
local function macro_contains_edit(buf, s_start, s_end)
  for i = s_start, s_end do
    if MACRO_EDIT_KEYS[buf[i].tok] then
      return true
    end
  end
  return false
end

-- Slides seq.macro_buf's contents down by `drop` slots once it has grown
-- past MACRO_BUF_HARD_CAP, so the array never grows unbounded. Only runs
-- once every (HARD_CAP - SOFT_CAP) appends, so it is O(1) amortised.
local function macro_trim(buf)
  local n = #buf
  if n <= MACRO_BUF_HARD_CAP then
    return
  end
  local drop = n - MACRO_BUF_SOFT_CAP
  for i = drop + 1, n do
    buf[i - drop] = buf[i]
  end
  for i = n - drop + 1, n do
    buf[i] = nil
  end
end

local function macro_windows_equal(buf, a_start, b_start, len)
  for i = 0, len - 1 do
    if buf[a_start + i].tok ~= buf[b_start + i].tok then
      return false
    end
  end
  return true
end

-- S must not itself contain a register/macro key — recording a macro to
-- replay a sequence that already plays or records a macro is not a sane
-- suggestion.
local function macro_contains_bad(buf, s_start, s_end)
  for i = s_start, s_end do
    local tok = buf[i].tok
    if tok == 'q' or tok == '@' then
      return true
    end
  end
  return false
end

-- Anchored search: does buf end (at index n) with 3 occurrences of some
-- length-L window, each pair separated only by navigation keys? Only
-- examines the GAP between matched windows for navigation-key membership —
-- the windows themselves are compared by exact token equality.
local function macro_check_len(buf, n, l)
  local s_start = n - l + 1
  if s_start < 1 then
    return false
  end
  if macro_contains_bad(buf, s_start, n) then
    return false
  end

  local before1 = buf[s_start - 1]
  local gap1_max = before1 and math.min(before1.nav_run, MACRO_MAX_GAP) or 0
  local occ2_start = nil
  for g = 0, gap1_max do
    local j_end = s_start - 1 - g
    local j_start = j_end - l + 1
    if j_start < 1 then
      break
    end
    if macro_windows_equal(buf, j_start, s_start, l) then
      occ2_start = j_start
      break
    end
  end
  if not occ2_start then
    return false
  end

  local before2 = buf[occ2_start - 1]
  local gap2_max = before2 and math.min(before2.nav_run, MACRO_MAX_GAP) or 0
  local occ1_start = nil
  for g = 0, gap2_max do
    local k_end = occ2_start - 1 - g
    local k_start = k_end - l + 1
    if k_start < 1 then
      break
    end
    if macro_windows_equal(buf, k_start, s_start, l) then
      occ1_start = k_start
      break
    end
  end
  if not occ1_start then
    return false
  end

  -- Content check, deliberately last: only reached once the anchored match
  -- is fully confirmed (both occurrences found, gaps validated as pure
  -- navigation above). Kept separate from and after that gap-classification
  -- logic so the anchored-match search itself stays untouched (follow-up bug
  -- fix — see this file's header comment).
  if not macro_contains_edit(buf, s_start, n) then
    return false
  end

  return (buf[n].t - buf[occ1_start].t) <= MACRO_WINDOW_MS
end

local function macro_detect(seq)
  local buf = seq.macro_buf
  local n = #buf
  for l = MACRO_MIN_LEN, MACRO_MAX_LEN do
    if macro_check_len(buf, n, l) then
      return { pattern = 'macro_opportunity', cmd = '@q' }
    end
  end
  return nil
end

-- token: key/canonical-name logger.lua wants recorded — raw key for ordinary
-- characters, or a readable name like '<Esc>' via logger.lua's
-- INSERT_SPECIAL table. patterns.lua stays vim.*-free (see
-- lua/tobira/CLAUDE.md) so this is threaded in as a parameter, like is_diff/now.
-- now: optional caller-supplied clock (ms); omitted calls behave as now == 0.
function M.feed_macro(seq, token, now)
  local t = now or 0
  local buf = seq.macro_buf
  local prev = buf[#buf]
  local nav_run = 0
  if MACRO_NAV_KEYS[token] then
    nav_run = (prev and prev.nav_run or 0) + 1
  end
  buf[#buf + 1] = { tok = token, t = t, nav_run = nav_run }
  macro_trim(buf)
  return macro_detect(seq)
end

local function track_run(seq, key)
  if seq.run.key == key then
    seq.run.count = seq.run.count + 1
  else
    seq.run = { key = key, count = 1 }
  end
  return seq.run.count
end

local function inner_feed(seq, key, line, is_diff, now)
  -- ── changelist-underuse bookkeeping ────────────────────────────────────────
  -- Observes every key unconditionally, before any other handler, and never
  -- consumes/returns — mirrors pending_paste's "always observe, only
  -- sometimes fire" shape below. EDIT_OP_KEYS mark "an edit just happened
  -- here"; any other key (except <Esc>, which only leaves insert mode
  -- without moving anywhere) marks "the user left that spot" — the closest
  -- passive proxy for "moved elsewhere" available without snapshotting the
  -- buffer or reading marks (both forbidden — see lua/tobira/CLAUDE.md).
  if EDIT_OP_KEYS[key] then
    if seq.edit_last_at and seq.edit_moved_away then
      seq.edit_second_seen = true
    end
    seq.edit_last_at = now
    seq.edit_moved_away = false
  elseif seq.edit_last_at and key ~= '\27' then
    seq.edit_moved_away = true
  end

  -- ── <C-o> observation ───────────────────────────────────────────────────────
  -- Raw byte for Ctrl-O (ASCII 15 / 0x0F). Recorded unconditionally (unlike
  -- the gq_then_jumpback check further down, which only fires its own
  -- suggestion when last_op == 'gq') so manual_return can permanently stop
  -- suggesting <C-o> once the user has demonstrably already used it.
  if key == '\15' then
    seq.ctrl_o_seen = true
  end

  -- ── p / P → rightward motion: cursor skipped past a paste ────────────────
  -- Checked first, before any other handler, so it observes every key after
  -- a paste — including keys other handlers would otherwise consume (g, ",
  -- m). Unlike those handlers this does NOT return early on a non-firing
  -- key: rightward motions still fall through to their own patterns
  -- (l_repeat, w_repeat, ...), and non-motion keys just cancel the streak
  -- and fall through. p/P re-press is exempted so p_repeat/P_repeat below
  -- are unaffected.
  if seq.pending_paste then
    if RIGHTWARD_KEYS[key] then
      seq.paste_motion_streak = seq.paste_motion_streak + 1
      if seq.paste_motion_streak >= 3 then
        local pasted = seq.pending_paste
        seq.pending_paste = nil
        seq.paste_motion_streak = 0
        if pasted == 'p' then
          return { pattern = 'p_then_rightward', cmd = 'gp' }
        else
          return { pattern = 'P_then_rightward', cmd = 'gP' }
        end
      end
    elseif key ~= 'p' and key ~= 'P' then
      seq.pending_paste = nil
      seq.paste_motion_streak = 0
    end
  end

  -- ── pending_g / pending_z: must precede f/F/t/T so that gf and zt are ────
  -- ── consumed by their own handlers rather than starting an f/t search.  ────
  if seq.pending_g then
    seq.pending_g = false
    -- gq is a real operator (needs a further motion), unlike every other
    -- pending_g target below which is a complete two-key command on its own —
    -- hand it off to pending_gq instead of the flat dispatch table.
    if key == 'q' then
      seq.pending_gq = true
      return nil
    end
    local g_targets = {
      g = 'gg',
      j = 'gj',
      k = 'gk',
      e = 'ge',
      d = 'gd',
      f = 'gf',
      n = 'gn',
      x = 'gx',
      ['0'] = 'g0',
      [';'] = 'g;',
      p = 'gp',
      u = 'gu',
    }
    if g_targets[key] then
      -- Captured BEFORE last_op is overwritten below: true only when a bare
      -- G was the most recently completed action and nothing else has
      -- happened since — any other key would already have cleared last_op
      -- (the generic reset further down in inner_feed) or overwritten it
      -- (a different g-compound resolving right here). See the mirrored
      -- gg → G check earlier in inner_feed for why last_op itself (not a
      -- dedicated field) is reused for this (#52).
      local g_then_gg = seq.last_op == 'G'
      seq.last_op = g_targets[key]
      seq.op_completed = true
      -- gg / g; are themselves significant jumplist / changelist motions,
      -- recorded the moment the compound resolves — neither key of "gg" (or
      -- "g;") ever reaches the bare-key tables below on its own, since
      -- pending_g consumes both.
      if seq.last_op == 'gg' then
        seq.jump_last_at = now
        seq.jump_return_streak = 0
        -- G → gg: suggest '' (#52). last_op is deliberately left as 'gg'
        -- (not cleared) so the usage-tracking increment in logger.lua
        -- (keyed off op_completed, set above) still counts this gg as
        -- used, and so an immediately-following bare G can still detect it
        -- via the gg → G check earlier in inner_feed.
        if g_then_gg then
          return { pattern = 'jump_back', cmd = "''" }
        end
      elseif seq.last_op == 'g;' then
        seq.g_semi_seen = true
      end
    end
    return nil
  end

  -- ── pending_gq: gq operator awaiting its motion ────────────────────────────
  -- Mirrors pending_op's d/c shape (count prefix, text-object prefix, linewise
  -- double, or a plain motion char) but always collapses to last_op = 'gq' —
  -- nothing downstream needs to know which motion was used, only that a gq
  -- format operation completed. Must precede f/F/t/T so a motion like gqf{char}
  -- is consumed as gq's motion, not mistaken for the start of an f-search.
  if seq.pending_gq then
    if key:match('^[1-9]$') then
      return nil -- count prefix; keep pending_gq (handles gq3j)
    end
    seq.pending_gq = false
    if key == '\27' then
      return nil -- <Esc> cancels
    end
    if key == 'i' or key == 'a' then
      seq.pending_gq_text_obj = true
      return nil
    end
    -- 'q' (linewise, like dd) or any other motion character completes gq.
    seq.last_op = 'gq'
    seq.op_completed = true
    return nil
  end

  if seq.pending_gq_text_obj then
    seq.pending_gq_text_obj = false
    seq.last_op = 'gq'
    seq.op_completed = true
    return nil
  end

  if seq.pending_z then
    seq.pending_z = false
    local z_targets = {
      z = 'zz',
      t = 'zt',
      b = 'zb',
      a = 'za',
      c = 'zc',
      o = 'zo',
      j = 'zj',
      k = 'zk',
      M = 'zM',
      R = 'zR',
      d = 'zd',
    }
    if z_targets[key] then
      seq.last_op = z_targets[key]
      seq.op_completed = true
    end
    return nil
  end

  -- ── pending_ctrl_w: <C-w>X window-command two-key compound ────────────────
  -- Same dispatch-table design as pending_g / pending_z above. Must precede
  -- f/F/t/T for the same reason gf and zt do — a stray collision would be a
  -- new two-character prefix anyway, which is why this sits right next to them.
  if seq.pending_ctrl_w then
    seq.pending_ctrl_w = false
    local ctrl_w_targets = {
      s = '<C-w>s',
      v = '<C-w>v',
      w = '<C-w>w',
      h = '<C-w>h',
      j = '<C-w>j',
      k = '<C-w>k',
      l = '<C-w>l',
      q = '<C-w>q',
      c = '<C-w>c',
      ['='] = '<C-w>=',
    }
    if ctrl_w_targets[key] then
      seq.last_op = ctrl_w_targets[key]
      seq.op_completed = true
      -- <C-w>q and <C-w>c both close the current window. Repeating either one
      -- (or alternating between them) 2+ times in a row means the user is
      -- closing windows one at a time — suggest <C-w>o instead.
      if key == 'q' or key == 'c' then
        seq.ctrl_w_close_streak = seq.ctrl_w_close_streak + 1
        if seq.ctrl_w_close_streak >= 2 then
          seq.ctrl_w_close_streak = 0
          return { pattern = 'ctrl_w_close_repeat', cmd = '<C-w>o' }
        end
      else
        seq.ctrl_w_close_streak = 0
      end
    else
      seq.ctrl_w_close_streak = 0
    end
    return nil
  end

  -- ── pending_clipboard_yank: "+ immediately followed by y ──────────────────
  -- Must precede f/F/t/T for the same "waiting on the very next key" reason
  -- pending_g / pending_z / pending_ctrl_w do above. Only 'y' completes the
  -- "+y compound; any other key means the user did something else with the +
  -- register (e.g. "+p) and falls through to that key's normal meaning —
  -- this state never survives past the one key right after "+.
  if seq.pending_clipboard_yank then
    seq.pending_clipboard_yank = false
    if key == 'y' then
      seq.last_op = '"+y'
      seq.op_completed = true
      seq.clipboard_yank_tail = true
      return nil
    end
  end

  -- ── clipboard_yank_tail: the key right after "+y completes ───────────────
  -- See clipboard_yank_tail's declaration in new_seq() for why this exists.
  -- Only 'y' needs guarding — it is the only key the generic operator-start
  -- branch below would otherwise turn into a fresh, dangling pending_op.
  if seq.clipboard_yank_tail then
    seq.clipboard_yank_tail = false
    if key == 'y' then
      return nil
    end
  end

  -- ── f / F / t / T ────────────────────────────────────────────────────────
  if key == 'f' or key == 'F' or key == 't' or key == 'T' then
    seq.pending_f = key
    seq.pending_op = nil
    seq.run = { key = nil, count = 0 }
    seq.r_streak = 0
    seq.indent_streak = 0
    seq.dedent_streak = 0
    seq.visual_obj = nil
    seq.visual_inner = nil
    seq.pending_visual = false
    seq.pending_register = false
    seq.pending_mark = false
    seq.pending_bracket = false
    return nil
  end

  if seq.pending_f then
    local op = seq.pending_f
    seq.pending_f = nil
    local fired = nil
    if seq.last_f and seq.last_f.line == line and seq.last_f.char == key and seq.last_f.op == op then
      fired = { pattern = 'f_repeat', cmd = ';' }
    end
    seq.last_f = { char = key, line = line, op = op }
    return fired
  end

  if seq.last_f and seq.last_f.line ~= line then
    seq.last_f = nil
  end

  -- ── pending_r: consume replacement character ──────────────────────────────
  if seq.pending_r then
    seq.pending_r = false
    seq.r_streak = seq.r_streak + 1
    if seq.r_streak >= 3 then
      seq.r_streak = 0
      return { pattern = 'r_run', cmd = 'R' }
    end
    return nil
  end

  -- ── visual text-object tracking ───────────────────────────────────────────
  -- State: pending_visual → visual_inner → visual_obj → operator
  if seq.visual_obj then
    if key == 'c' or key == 'd' or key == 'y' then
      local cmd = key .. seq.visual_inner .. seq.visual_obj
      seq.visual_obj = nil
      seq.visual_inner = nil
      return { pattern = 'visual_textobj', cmd = cmd }
    end
    -- Non-operator: cancel and fall through
    seq.visual_obj = nil
    seq.visual_inner = nil
  end

  if seq.visual_inner then
    seq.visual_obj = key
    return nil
  end

  if seq.pending_visual then
    seq.pending_visual = false
    if key == '\27' then
      -- Tapped v and left immediately with no real usage — the v_repeat
      -- half of the streak. Only <Esc> counts as "clean"; every other
      -- completion below (text object or otherwise) means the user did
      -- something with the selection, which breaks the streak.
      seq.v_clean_exit = true
      return nil
    end
    seq.v_clean_exit = false
    seq.v_streak = 0
    if key == 'i' or key == 'a' then
      seq.visual_inner = key
    end
    -- Whether accepted or cancelled, consume and return
    return nil
  end

  -- ── single-char prefix consumers ─────────────────────────────────────────
  if seq.pending_register then
    seq.pending_register = false
    seq.key_consumed = true
    -- "+ specifically arms pending_clipboard_yank; every other register name
    -- (including "*) keeps the existing consume-and-forget behavior below.
    if key == '+' then
      seq.pending_clipboard_yank = true
    end
    return nil
  end

  if seq.pending_mark then
    seq.pending_mark = false
    local was_gq_backtick = seq.pending_gq_backtick
    seq.pending_gq_backtick = false
    -- `` (backtick-backtick, jump to position before last jump) right after a
    -- completed gq: the user formatted text then manually jumped back to
    -- where they started — exactly what gw does automatically.
    if was_gq_backtick and key == '`' then
      seq.last_op = nil
      seq.key_consumed = true
      return { pattern = 'gq_then_jumpback', cmd = 'gw' }
    end
    seq.key_consumed = true
    return nil
  end

  if seq.pending_bracket then
    seq.pending_bracket = false
    seq.key_consumed = true
    return nil
  end

  -- ── pending_text_obj ──────────────────────────────────────────────────────
  if seq.pending_text_obj then
    local op = seq.pending_text_obj
    seq.pending_text_obj = nil
    seq.last_op = op .. 'w'
    seq.op_completed = true
    return nil
  end

  -- ── pending_op ────────────────────────────────────────────────────────────
  if seq.pending_op then
    local op = seq.pending_op
    if key:match('^[1-9]$') then
      return nil
    end
    seq.pending_op = nil
    if key == '\27' then
      return nil
    end

    -- ── >> / << indent/dedent streak ─────────────────────────────────────
    if op == '>' or op == '<' then
      if key == op then
        seq.last_op = op .. op -- '>>' or '<<' for compound tracking
        seq.op_completed = true
        if op == '>' then
          seq.indent_streak = seq.indent_streak + 1
          if seq.indent_streak == 3 then
            seq.indent_streak = 0
            return { pattern = 'indent_run', cmd = '{n}>>' }
          end
        else
          seq.dedent_streak = seq.dedent_streak + 1
          if seq.dedent_streak == 3 then
            seq.dedent_streak = 0
            return { pattern = 'dedent_run', cmd = '{n}<<' }
          end
        end
      else
        seq.indent_streak = 0
        seq.dedent_streak = 0
      end
      return nil
    end

    -- ── y: track yy for yy_then_p, y$ for y_dollar ───────────────────────
    if op == 'y' then
      if key == 'y' then
        seq.last_op = 'yy'
        seq.op_completed = true
      elseif key == '$' then
        return { pattern = 'y_dollar', cmd = 'Y' }
      end
      return nil
    end

    -- ── d / c operators ──────────────────────────────────────────────────
    if key == '$' then
      if op == 'c' then
        return { pattern = 'c_dollar', cmd = 'C' }
      elseif op == 'd' then
        return { pattern = 'd_dollar', cmd = 'D' }
      end
    elseif key == op or key == 'j' or key == 'k' then
      seq.last_op = op .. op -- 'dd' or 'cc' (also dj/dk, cj/ck: linewise, tracked the same)
      seq.op_completed = true
      if key == op then
        if op == 'd' then
          seq.dd_streak = seq.dd_streak + 1
          if seq.dd_streak >= 3 then
            seq.dd_streak = 0
            return { pattern = 'dd_run', cmd = '{n}dd' }
          end
        elseif op == 'c' then
          seq.cc_streak = seq.cc_streak + 1
        end
      else
        seq.dd_streak = 0
        seq.cc_streak = 0
      end
    elseif key == 'i' or key == 'a' then
      seq.pending_text_obj = op
    else
      seq.last_op = op .. 'w'
      seq.op_completed = true
    end
    return nil
  end

  -- ── d / c / y / > / < operator start ─────────────────────────────────────
  if key == 'd' or key == 'c' or key == 'y' or key == '>' or key == '<' then
    seq.pending_op = key
    seq.run = { key = nil, count = 0 }
    return nil
  end

  -- ── r: single-char replace ────────────────────────────────────────────────
  if key == 'r' then
    seq.pending_r = true
    return nil
  end

  -- ── <C-a>: sequential-increment streak tracking ────────────────────────────
  -- Raw byte for Ctrl-A (ASCII 1 / 0x01). Same streak-counter shape as
  -- r_streak above: increment on every occurrence, fire at the 3rd, reset
  -- via the tolerated-motion check below (j/k here, in place of r_streak's
  -- h/l).
  if key == '\1' then
    seq.ca_streak = seq.ca_streak + 1
    if seq.ca_streak >= 3 then
      seq.ca_streak = 0
      return { pattern = 'ca_run', cmd = 'g<C-a>' }
    end
    return nil
  end

  -- ── v: start visual text-object tracking ─────────────────────────────────
  -- Also extends the v_repeat streak (#55): this v only continues the streak
  -- when the immediately preceding cycle was a clean v-then-<Esc> tap
  -- (v_clean_exit); anything else (a fresh start, or the last cycle having
  -- done real visual work) restarts the count at 1. Fires as soon as this
  -- 3rd v lands, without waiting for a 3rd <Esc> — matching the issue's own
  -- "v<Esc>v<Esc>v" example, which ends on a bare v.
  if key == 'v' then
    seq.v_streak = seq.v_clean_exit and (seq.v_streak + 1) or 1
    seq.v_clean_exit = false
    seq.pending_visual = true
    if seq.v_streak >= 3 then
      seq.v_streak = 0
      return { pattern = 'v_repeat', cmd = 'gv' }
    end
    return nil
  end

  -- ── g / z: start two-key compound tracking ───────────────────────────────
  if key == 'g' then
    seq.pending_g = true
    return nil
  end
  if key == 'z' then
    seq.pending_z = true
    return nil
  end

  -- ── <C-w>: start window-command two-key compound tracking ────────────────
  -- Raw byte for Ctrl-W (ASCII 23 / 0x17). Only reached from the normal-mode
  -- path in logger.lua's handle_key — the insert-mode meaning of the exact
  -- same byte is handled entirely separately by handle_insert_key(), so this
  -- can never conflate the two (see commands.lua's '<C-w>' entry comment).
  if key == '\23' then
    seq.pending_ctrl_w = true
    return nil
  end

  -- ── single-char prefix starters ───────────────────────────────────────────
  if key == '"' or key == '@' then
    seq.pending_register = true
    return nil
  end
  if key == 'm' or key == "'" or key == '`' then
    seq.pending_mark = true
    seq.pending_gq_backtick = key == '`' and seq.last_op == 'gq'
    return nil
  end
  if key == '[' or key == ']' then
    seq.pending_bracket = true
    return nil
  end

  -- ── r_streak reset for keys that break the r-replacement flow ────────────
  -- h and l are safe navigation between replacements; everything else resets.
  if key ~= 'h' and key ~= 'l' then
    seq.r_streak = 0
  end

  -- ── ca_streak reset for keys that break the C-a increment flow ───────────
  -- j and k are the tolerated connecting motion between increments; any
  -- other key reaching this point means the sequence wasn't built line by
  -- line and the streak no longer applies.
  if key ~= 'j' and key ~= 'k' then
    seq.ca_streak = 0
  end

  -- ── yy → p (duplicate line) ──────────────────────────────────────────────
  if key == 'p' and seq.last_op == 'yy' then
    seq.last_op = nil
    return { pattern = 'yy_then_p', cmd = 'yyp' }
  end

  -- ── dd → p (swap lines) ──────────────────────────────────────────────────
  if key == 'p' and seq.last_op == 'dd' then
    seq.last_op = nil
    seq.dd_streak = 0
    return { pattern = 'dd_then_p', cmd = 'ddp' }
  end

  -- ── dd → insert: suggest cc ──────────────────────────────────────────────
  if seq.last_op == 'dd' and INSERT_KEYS[key] then
    seq.last_op = nil
    seq.dd_streak = 0
    return { pattern = 'dd_then_insert', cmd = 'cc' }
  end

  -- ── p / P: arm cursor-skip-past-paste tracking ────────────────────────────
  -- Not consumed here — p/P still fall through to p_repeat/P_repeat via
  -- track_run() at the bottom. The top-of-function check above uses this
  -- state to detect rightward moves right after the paste.
  if key == 'p' or key == 'P' then
    seq.pending_paste = key
    seq.paste_motion_streak = 0
  end

  -- ── 0 → w: first non-blank ───────────────────────────────────────────────
  if key == 'w' and seq.run.key == '0' then
    return { pattern = 'zero_then_w', cmd = '^' }
  end

  -- ── 0 → i: suggest gI (true column 1, unlike I which goes to first non-blank) ──
  if key == 'i' and seq.run.key == '0' then
    return { pattern = 'zero_col_then_insert', cmd = 'gI' }
  end

  -- ── ^ → i: suggest I ─────────────────────────────────────────────────────
  if key == 'i' and seq.run.key == '^' then
    return { pattern = 'zero_then_insert', cmd = 'I' }
  end

  -- ── $ → a: suggest A ─────────────────────────────────────────────────────
  if key == 'a' and seq.run.key == '$' then
    return { pattern = 'dollar_then_append', cmd = 'A' }
  end

  -- ── k (exactly once) → o: suggest O ─────────────────────────────────────
  if key == 'o' and seq.run.key == 'k' and seq.run.count == 1 then
    -- Reset the run so a second k -> o round trip right after this one still
    -- sees count == 1 instead of a stale count == 2 from the first k.
    seq.run = { key = nil, count = 0 }
    return { pattern = 'k_then_o', cmd = 'O' }
  end

  -- ── x (exactly once) → insert: suggest s ─────────────────────────────────
  if INSERT_KEYS[key] and seq.run.key == 'x' and seq.run.count == 1 then
    -- Reset the run so a second x -> insert round trip right after this one
    -- still sees count == 1 instead of a stale count == 2 from the first x.
    seq.run = { key = nil, count = 0 }
    return { pattern = 'x_then_insert', cmd = 's' }
  end

  -- ── D → insert: suggest C ────────────────────────────────────────────────
  if INSERT_KEYS[key] and seq.run.key == 'D' then
    return { pattern = 'D_then_insert', cmd = 'C' }
  end

  -- ── dw → insert: suggest cw ──────────────────────────────────────────────
  if seq.last_op == 'dw' and INSERT_KEYS[key] then
    seq.last_op = nil
    return { pattern = 'dw_then_insert', cmd = 'cw' }
  end

  -- ── gq → <C-o>: jump back after format, suggest gw ────────────────────────
  -- Raw byte for Ctrl-O (ASCII 15 / 0x0F). <C-o> is already a complete
  -- "jump back" command on its own (unlike `` ` ``, which needs a second key),
  -- so this only needs a direct last_op check, not a pending_* prefix state.
  if key == '\15' and seq.last_op == 'gq' then
    seq.last_op = nil
    return { pattern = 'gq_then_jumpback', cmd = 'gw' }
  end

  -- ── gg → G: suggest '' (jump back to position before gg) (#52) ───────────
  -- Mirrors the reverse direction handled inside the pending_g dispatch
  -- above. Captured here (before last_op is reset below for any unrelated
  -- key) so it only fires when G is the very next resolved action after gg,
  -- not some later, unrelated G.
  --
  -- Bug fix: this used to fire-and-return immediately, right here, which
  -- skipped the JUMP_MOTION_KEYS bookkeeping further down (jump_last_at
  -- refresh, jump_return_streak reset, last_op = 'G') that every OTHER bare
  -- G gets. Since last_op is deliberately left as 'gg'/'G' after firing (so
  -- a further alternation can still fire) and survives both idle time and a
  -- 'p' paste (see the generic reset's 'p' exception below), a later,
  -- entirely unrelated bare G could reach here, refire jump_back, and STILL
  -- leave jump_last_at stale — corrupting manual_return's (#61) tolerance
  -- check for that same, genuine G. The fix: only capture the flag here;
  -- the actual fire-and-return now happens below, inside the
  -- JUMP_MOTION_KEYS block, AFTER that block's bookkeeping has already run
  -- for this G — so firing jump_back never bypasses it.
  local gg_then_G = key == 'G' and seq.last_op == 'gg'

  if key ~= 'p' then
    seq.last_op = nil
    seq.dd_streak = 0
    seq.cc_streak = 0
    seq.indent_streak = 0
    seq.dedent_streak = 0
    seq.ctrl_w_close_streak = 0
    seq.v_streak = 0
    seq.v_clean_exit = false
  end

  -- ── consecutive-run patterns (count computed early) ────────────────────────
  -- track_run() must run unconditionally on every key, even ones the
  -- jumplist/changelist blocks below return early on — skipping it here
  -- freezes seq.run's counter for that keystroke, so the next same-key press
  -- jumps it forward by 2 instead of 1, firing j_repeat/k_repeat/j_many/
  -- k_many one press "early" right after a manual_return/changelist_return
  -- (a live-regression bug, not caught by patterns_spec.lua's per-call
  -- assertions).
  local count = track_run(seq, key)

  -- ── jumplist-underuse detection ──────────────────────────────────────────
  -- Only reached for keys that fell through every operator/compound-pending
  -- state above uncontested — e.g. `dj` never reaches this: pending_op
  -- already consumed the j as part of a linewise delete, not a "return".
  -- NOTE: this no longer returns early on its own — see the arbitration
  -- block below for why (follow-up bug).
  local jump_ready = false
  if key == 'G' or JUMP_MOTION_KEYS[key] then
    seq.jump_last_at = now
    seq.jump_return_streak = 0
    -- Only reached when the gg → G check earlier in inner_feed did NOT
    -- already fire (that branch returns early) — so this only runs for a
    -- bare G with no immediately-preceding gg. Remembered so a following gg
    -- can detect this G via the pending_g dispatch's g_then_gg check (#52).
    -- Deliberately NOT paired with op_completed = true: G is already
    -- tracked as a plain single keystroke via logger.lua's TRACK table, and
    -- op_completed here would double-count it through the compound-tracking
    -- increment path there too.
    if key == 'G' then
      seq.last_op = 'G'
      -- gg → G jump_back (#52): fire now that this G's own bookkeeping
      -- (jump_last_at, jump_return_streak, last_op — all just above) has
      -- already run for this same keystroke. See gg_then_G's capture
      -- earlier in inner_feed for why this moved here instead of returning
      -- immediately when detected.
      if gg_then_G then
        return { pattern = 'jump_back', cmd = "''" }
      end
    end
  elseif RETURN_MOTION_KEYS[key] then
    if seq.jump_last_at and not seq.ctrl_o_seen and (now - seq.jump_last_at) <= JUMP_TOLERANCE_MS then
      seq.jump_return_streak = seq.jump_return_streak + 1
      if seq.jump_return_streak == RETURN_MOTION_THRESHOLD then
        jump_ready = true
      end
    else
      seq.jump_return_streak = 0
    end
  else
    seq.jump_return_streak = 0
  end

  -- ── changelist-underuse detection ────────────────────────────────────────
  -- edit_second_seen only becomes true once two edits have happened with a
  -- non-<Esc> key seen in between (see the top-of-function observer) —
  -- i.e. two edits at genuinely different spots, not the same location
  -- re-entered. Like the jumplist block above, this does not return early —
  -- see the arbitration block below.
  local change_ready = false
  if key == 'j' or key == 'k' then
    if
      seq.edit_second_seen
      and not seq.g_semi_seen
      and seq.edit_last_at
      and (now - seq.edit_last_at) <= CHANGE_TOLERANCE_MS
    then
      seq.change_return_streak = seq.change_return_streak + 1
      if seq.change_return_streak == RETURN_MOTION_THRESHOLD then
        change_ready = true
      end
    else
      seq.change_return_streak = 0
    end
  else
    seq.change_return_streak = 0
  end

  -- ── jumplist vs. changelist arbitration (follow-up bug) ───────────────────
  -- Both patterns key off the same evidence — "5+ consecutive j/k after some
  -- earlier event" — so a single keystroke can satisfy both at once (e.g.
  -- jump far, edit, jump far again, edit, then k×5 back). The two blocks
  -- above no longer return early: they only record whether each threshold
  -- was reached this keystroke (jump_ready / change_ready), and this block
  -- decides what to do once both are known.
  --
  -- When only one is ready it fires as before. When both are ready, the one
  -- whose triggering "away" event happened MORE RECENTLY wins (the
  -- significant jump for manual_return, the second edit for
  -- changelist_return) — the more likely thing the user is trying to get
  -- back to. The loser's streak is reset without firing, not left dangling,
  -- so it can still build back up and fire later if it genuinely repeats.
  if jump_ready and change_ready then
    if seq.jump_last_at >= seq.edit_last_at then
      seq.jump_return_streak = 0
      seq.jump_last_at = nil
      seq.change_return_streak = 0
      return { pattern = 'manual_return', cmd = '<C-o>' }
    else
      seq.change_return_streak = 0
      seq.edit_second_seen = false
      seq.edit_last_at = nil
      seq.jump_return_streak = 0
      return { pattern = 'changelist_return', cmd = 'g;' }
    end
  elseif jump_ready then
    seq.jump_return_streak = 0
    seq.jump_last_at = nil
    return { pattern = 'manual_return', cmd = '<C-o>' }
  elseif change_ready then
    seq.change_return_streak = 0
    seq.edit_second_seen = false
    seq.edit_last_at = nil
    return { pattern = 'changelist_return', cmd = 'g;' }
  end

  -- == (not >=): each threshold fires exactly once, enabling multi-threshold
  -- patterns like j_repeat(5) and j_many(10) for the same key.
  if key == 'x' and count == 3 then
    return { pattern = 'x_repeat', cmd = '{n}x' }
  elseif key == 'u' and count == 3 then
    return { pattern = 'u_repeat', cmd = '<C-r>' }
  elseif key == 'j' and count == 5 then
    return { pattern = 'j_repeat', cmd = '{n}j' }
  elseif key == 'j' and count == 10 then
    -- While &diff is set, hunting for the next changed hunk with plain j is
    -- better served by ]c (jump to next hunk) than } (paragraph jump).
    -- is_diff is a plain parameter, not seq state, because it reflects the
    -- window's CURRENT &diff value at the moment of the 10th press, not
    -- anything accumulated over the streak — see logger.lua for where it's
    -- read (vim.wo.diff) and passed in.
    if is_diff then
      return { pattern = 'j_many_diff', cmd = ']c' }
    end
    return { pattern = 'j_many', cmd = '}' }
  elseif key == 'k' and count == 5 then
    return { pattern = 'k_repeat', cmd = '{n}k' }
  elseif key == 'k' and count == 10 then
    if is_diff then
      return { pattern = 'k_many_diff', cmd = '[c' }
    end
    return { pattern = 'k_many', cmd = '{' }
  elseif key == 'n' and count == 4 then
    return { pattern = 'n_repeat', cmd = 'cgn' }
  elseif key == 'l' and count == 5 then
    return { pattern = 'l_repeat', cmd = 'w' }
  elseif key == 'h' and count == 5 then
    return { pattern = 'h_repeat', cmd = 'b' }
  elseif key == 'w' and count == 5 then
    return { pattern = 'w_repeat', cmd = 'W' }
  elseif key == 'b' and count == 5 then
    return { pattern = 'b_repeat', cmd = 'B' }
  elseif key == 'p' and count == 3 then
    return { pattern = 'p_repeat', cmd = '{n}p' }
  elseif key == 'P' and count == 3 then
    return { pattern = 'P_repeat', cmd = '{n}P' }
  elseif key == '~' and count == 3 then
    return { pattern = 'tilde_repeat', cmd = '{n}~' }
  elseif key == '.' and count == 3 then
    return { pattern = 'dot_repeat', cmd = '{n}.' }
  elseif key == 'J' and count == 3 then
    return { pattern = 'J_repeat', cmd = '{n}J' }
  end

  return nil
end

-- is_diff: true when &diff is set on the window the keystroke came from.
-- Only consulted by j_many/k_many. Passed in by the caller (logger.lua reads
-- vim.wo.diff) since patterns.lua stays vim.*-free by design (pure Lua,
-- testable without a running Neovim instance).
--
-- now: optional caller-supplied clock (ms) used by the jumplist/changelist
-- tolerance-window checks. Omitted calls behave as now == 0, so a constant
-- clock never expires a tolerance window — keeps existing call sites and
-- non-time-sensitive tests working unchanged. Real callers pass
-- vim.loop.now(); tests pass a fake value.
function M.feed(seq, key, line, is_diff, now)
  seq.key_consumed = false -- reset before each call; handlers set true when consuming
  seq.op_completed = false -- reset before each call; handlers set true when last_op is freshly set
  local result = inner_feed(seq, key, line, is_diff, now or 0)
  return result
end

return M
