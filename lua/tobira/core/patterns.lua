-- Pure pattern detection. No vim.* calls.
-- feed() mutates seq in place and returns a fired pattern or nil.
--
-- Design rationale for individual features lives in docs/adr/, linked from
-- each section below: 0018 (macro opportunity), 0019 (jumplist/changelist
-- underuse), 0020 (ci-quote streak), 0021 (v/gv streak), 0022 (gq operator),
-- 0023 (register/mark/bracket prefixes), 0024 (<C-w> window compound),
-- 0025 (paste motion streak), 0026 (state-machine bookkeeping invariants),
-- 0027 (r/ctrl-a tolerated streaks), 0028 (dd/cc/indent/dedent streaks),
-- 0096 (<C-w> resize streak), 0097 (cursor-centering streak), 0098
-- (visual-block edit streak), 0099 (diff obtain/put after hunk jump), 0100
-- (named-mark repeated line return), 0101 (tilde text-object refinement),
-- 0106 (text-object variant own-usage tracking), 0107 (n_repeat intent-neutral
-- + reactive n_then_change → cgn), 0108 (fold open/close streak), 0109
-- (wrap-aware gj/gk redirect), 0113 (buffer-local seq reset with <C-w>
-- exemption), 0114 (macro dispatch priority generalization), 0115
-- (prefix-consumer streak bookkeeping), 0116 (macro-edit-keys mode-source
-- distinction).

local M = {}

function M.new_seq()
  return {
    pending_f = nil,
    last_f = nil,
    pending_op = nil,
    last_op = nil,
    run = { key = nil, count = 0 },
    pending_text_obj = nil,
    -- Set alongside last_op on the exact call that resolves pending_text_obj,
    -- to the text-object variant's OWN registry key (e.g. 'ci"', 'diw') when
    -- the text-object character is one commands.lua's registry actually
    -- tracks on its own — in addition to (not instead of) the shared op..'w'
    -- bucket set in last_op. Reset every M.feed() call, same discipline as
    -- op_completed — see docs/adr/0106-text-object-variant-own-usage-tracking.md.
    last_op_variant = nil,
    dd_streak = 0,
    cc_streak = 0,
    indent_streak = 0,
    dedent_streak = 0,
    -- true when the i/a prefix just consumed by pending_op was 'i' (not 'a')
    -- — see docs/adr/0020-ci-quote-streak-and-tolerance.md
    pending_text_obj_inner = false,
    -- ci"/ci' streak tracking — see docs/adr/0020-ci-quote-streak-and-tolerance.md
    ci_dquote_streak = 0,
    ci_squote_streak = 0,
    -- r-replacement tracking: r{char} l r{char} l r{char} → R
    -- see docs/adr/0027-tolerated-motion-streaks-r-and-ctrl-a.md
    pending_r = false,
    r_streak = 0,
    -- <C-a> sequential-increment tracking: <C-a> j <C-a> j <C-a> → g<C-a>
    -- see docs/adr/0027-tolerated-motion-streaks-r-and-ctrl-a.md
    ca_streak = 0,
    -- visual text-object tracking: v i {obj} c/d/y → c/d/yiw etc.
    pending_visual = false,
    visual_inner = nil,
    visual_obj = nil,
    -- v/gv streak tracking — see docs/adr/0021-visual-repeat-gv-detection.md
    v_streak = 0,
    v_clean_exit = false,
    pending_g = false,
    pending_z = false,
    -- gq operator-pending tracking (needs a further motion, unlike the plain
    -- two-key pending_g targets) — see docs/adr/0022-gq-operator-pending-and-post-format-jumpback.md
    pending_gq = false,
    pending_gq_text_obj = false,
    -- true only right after gq completes and the mark-prefix key (`) starts —
    -- see docs/adr/0022-gq-operator-pending-and-post-format-jumpback.md
    pending_gq_backtick = false,
    pending_ctrl_w = false,
    -- <C-w>q / <C-w>c repeated (or alternated) 2+ times in a row → <C-w>o
    -- see docs/adr/0024-ctrl-w-window-compound-and-close-streak.md
    ctrl_w_close_streak = 0,
    -- <C-w>+ / <C-w>- / <C-w>< / <C-w>> repeated (or alternated) 2+ times in
    -- a row → <C-w>=. Tracked independently of ctrl_w_close_streak above so
    -- the two families never interfere with each other's count — see
    -- docs/adr/0096-ctrl-w-resize-streak.md
    ctrl_w_resize_streak = 0,
    -- zo repeated (or alternated with za/other z-targets, which reset it)
    -- 2+ times in a row → zR. Tracked independently of fold_close_streak
    -- below so the two never interfere with each other's count — same shape
    -- as ctrl_w_close_streak/ctrl_w_resize_streak above — see
    -- docs/adr/0108-fold-open-close-streak.md
    fold_open_streak = 0,
    -- zc repeated (or alternated) 2+ times in a row → zM. See
    -- docs/adr/0108-fold-open-close-streak.md
    fold_close_streak = 0,
    -- prefixes that consume exactly one following character
    pending_register = false, -- " or @ (register / macro name)
    pending_mark = false, -- m / ' / ` (mark name or target)
    pending_bracket = false, -- [ or ] (navigation pair)
    -- last bracket-jump direction (']' or '[') when it resolved to a diff
    -- hunk jump (]c / [c), armed for one following key only — see
    -- docs/adr/0099-diff-obtain-put-after-hunk-jump.md
    diff_jump_dir = nil,
    -- armed once an n-streak reaches N_CHANGE_WATCH_THRESHOLD; consumed by a
    -- 'c'-family change completing (last_op becomes 'cw') shortly after, or
    -- expired by any unrelated key in between — see
    -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
    n_change_watch = false,
    -- "+ immediately followed by y → "+y system-clipboard yank. Set by
    -- pending_register below only when the register was '+'.
    pending_clipboard_yank = false,
    -- guards exactly one key after "+y so a following 'y' doesn't start a
    -- dangling pending_op — see docs/adr/0023-register-mark-bracket-prefix-consumers.md
    clipboard_yank_tail = false,
    pending_paste = nil, -- 'p' | 'P' | nil
    paste_motion_streak = 0, -- see docs/adr/0025-paste-motion-streak.md
    -- true when M.feed consumed key as the 2nd half of a compound; logger.lua
    -- skips standalone TRACK counting for it then — see
    -- docs/adr/0026-state-machine-bookkeeping-invariants.md
    key_consumed = false,
    -- true only on the call that freshly sets last_op; logger.lua increments
    -- usage from this flag instead of diffing last_op — see
    -- docs/adr/0026-state-machine-bookkeeping-invariants.md
    op_completed = false,
    -- jumplist-underuse tracking. now is caller-supplied so this file stays
    -- vim.*-free. See docs/adr/0019-jumplist-changelist-underuse-detection.md
    jump_last_at = nil,
    jump_return_streak = 0,
    ctrl_o_seen = false,
    -- changelist-underuse tracking — see
    -- docs/adr/0019-jumplist-changelist-underuse-detection.md
    edit_last_at = nil,
    edit_moved_away = false,
    edit_second_seen = false,
    change_return_streak = 0,
    -- Mirrors ctrl_o_seen (for g;).
    g_semi_seen = false,
    -- <C-e>/<C-y> repeated (any mix) → zz. Increments off the same two keys
    -- RETURN_MOTION_KEYS already watches for manual_return, but is its own
    -- independent counter — see docs/adr/0097-cursor-centering-streak.md
    zz_streak = 0,
    -- Named-mark opportunity: cursor returning to the same specific line 3+
    -- times, with genuine editing elsewhere in between each return — see
    -- docs/adr/0100-named-mark-repeated-line-return.md
    mark_prev_line = nil,
    mark_anchor_line = nil,
    mark_return_count = 0,
    mark_left_anchor = false,
    mark_edited_away = false,
    -- Array of { tok, t, nav_run } entries fed by M.feed_macro() (below) from
    -- BOTH normal- and insert-mode branches of logger.lua's handle_key() —
    -- unlike this seq's other fields, which are normal-mode only. See
    -- docs/adr/0018-macro-opportunity-detection.md
    macro_buf = {},
  }
end

-- Resets seq for a buffer switch (BufEnter), preserving ONLY the <C-w>
-- window-command streak fields -- <C-w>q/<C-w>c/<C-w>s/<C-w>v's own effect
-- IS a window (and usually buffer) switch, so a blanket reset-on-buffer-
-- switch would make ctrl_w_close_repeat/ctrl_w_resize_repeat structurally
-- undetectable. See docs/adr/0113-buffer-local-seq-reset-with-ctrl-w-exemption.md.
function M.reset_for_buffer_switch(seq)
  local fresh = M.new_seq()
  fresh.pending_ctrl_w = seq.pending_ctrl_w
  fresh.ctrl_w_close_streak = seq.ctrl_w_close_streak
  fresh.ctrl_w_resize_streak = seq.ctrl_w_resize_streak
  return fresh
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

-- Motions tolerated between ci"/ci' completions without resetting
-- ci_dquote_streak/ci_squote_streak — see
-- docs/adr/0020-ci-quote-streak-and-tolerance.md
local CI_QUOTE_NAV_KEYS = {
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

-- Text-object characters that get their own tracked usage bucket, in
-- addition to the shared op..'w' bucket pending_text_obj always sets. Keyed
-- by the exact character pressed after i/a; the variant key itself is built
-- as op .. (inner and 'i' or 'a') .. key, e.g. op='c', inner=true, key='"'
-- → 'ci"'. Restricted to the text objects commands.lua's registry actually
-- chains off (ciw/ci"/ci'/cib/ciB/cit/cip/diw) rather than every character
-- reaching this state, so an accidental keystroke can't create throwaway
-- usage.json entries no `requires` chain will ever read. See
-- docs/adr/0106-text-object-variant-own-usage-tracking.md.
local TRACKED_TEXT_OBJ_CHARS = {
  w = true,
  ['"'] = true,
  ["'"] = true,
  b = true,
  B = true,
  t = true,
  p = true,
}

-- ── jumplist / changelist underuse detection ────────────────────────────────
-- see docs/adr/0019-jumplist-changelist-underuse-detection.md
local JUMP_TOLERANCE_MS = 15000
local CHANGE_TOLERANCE_MS = 15000
local RETURN_MOTION_THRESHOLD = 5

-- <C-e>/<C-y> repeated (any mix) → zz. Matches RETURN_MOTION_THRESHOLD's
-- magnitude for the same key class rather than inventing a new number — see
-- docs/adr/0097-cursor-centering-streak.md
local CURSOR_CENTER_STREAK_THRESHOLD = 5

-- Cursor returning to the same specific line, with genuine editing
-- elsewhere in between each return — see
-- docs/adr/0100-named-mark-repeated-line-return.md
local NAMED_MARK_RETURN_THRESHOLD = 3

-- ~ repeated across consecutive character positions: tilde_repeat({n}~)
-- fires at 3, then supersedes to a text-object-scoped case operator once the
-- streak plausibly spans a whole word (6, double the base threshold — same
-- doubling convention as j_repeat(5)/j_many(10)) or a whole line (12,
-- double again). See docs/adr/0101-tilde-repeat-text-object-refinement.md
local TILDE_WORD_THRESHOLD = 6
local TILDE_LINE_THRESHOLD = 12

-- Keys that mean "the user just made a big navigational jump" — the same
-- class of motion that adds a jumplist entry. 'gg' and '/' are deliberately
-- absent — see docs/adr/0019-jumplist-changelist-underuse-detection.md
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
-- Detects the user manually repeating an identical edit sequence 3+ times —
-- exactly where recording a macro (qq...q, then @q) would pay off. Fed
-- through its own M.feed_macro() entry point (see logger.lua's
-- handle_macro_key()), not inner_feed() — the repeated edit can span into
-- insert mode, which would corrupt inner_feed's normal-mode operator-pending
-- grammar. Uses its own rolling buffer (seq.macro_buf), not suggest.lua's
-- 20-char one (different purpose, and too short for 3 reps of a 15-key seq).
-- see docs/adr/0018-macro-opportunity-detection.md for the anchored-match
-- algorithm, its two follow-up-bug guards, and the buffer-size bounds below.
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
-- EDIT_OP_KEYS plus the d/c/y/>/< operator-start set inner_feed() checks.
local MACRO_EDIT_KEYS = { d = true, c = true, y = true, ['>'] = true, ['<'] = true }
for k in pairs(EDIT_OP_KEYS) do
  MACRO_EDIT_KEYS[k] = true
end

-- S must contain at least one genuine edit keystroke, not just any 3+ exact
-- repeat of a nav-only window (follow-up bug) — see
-- docs/adr/0018-macro-opportunity-detection.md
--
-- Only counts a MACRO_EDIT_KEYS match when the token was fed from the
-- Normal-mode call site (buf[i].is_normal_key) -- an insert-mode-typed
-- character sharing a letter with an operator key (e.g. the 'd'/'i'/'a'/'o'
-- in an ordinary word like "diamond") is not evidence of a repeated EDIT,
-- just prose that happens to overlap the operator alphabet. See
-- docs/adr/0116-macro-edit-keys-mode-source-distinction.md.
local function macro_contains_edit(buf, s_start, s_end)
  for i = s_start, s_end do
    if buf[i].is_normal_key and MACRO_EDIT_KEYS[buf[i].tok] then
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
-- length-L window, each pair separated only by navigation keys? See
-- docs/adr/0018-macro-opportunity-detection.md
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

  -- Content check, deliberately last — only reached once the anchored match
  -- is fully confirmed. See docs/adr/0018-macro-opportunity-detection.md
  if not macro_contains_edit(buf, s_start, n) then
    return false
  end

  return (buf[n].t - buf[occ1_start].t) <= MACRO_WINDOW_MS
end

-- ── visual-block edit streak ─────────────────────────────────────────────────
-- Same window S must repeat 3 times, like macro_check_len above, but with
-- two extra restrictions: the gap between occurrences must be EXACTLY one
-- 'j' (the cursor moving down one line, not macro_check_len's up-to-
-- MACRO_MAX_GAP tolerance), and S itself must be a *plain* insert-then-Escape
-- shape — starting with an INSERT_KEYS entry (i/I/a/A/o/O/s/S), ending with
-- <Esc> — rather than any repeated edit sequence. That second restriction
-- deliberately excludes operator+motion shapes like "cwFooBar<Esc>"
-- (macro_opportunity's own canonical example, ADR 0018): that repeated edit
-- also happens to have single-'j' gaps in its own regression test, so
-- without this restriction visual-block would silently steal it. See
-- docs/adr/0098-visual-block-edit-streak.md
local function visual_block_check_len(buf, n, l)
  local s_start = n - l + 1
  if s_start < 1 then
    return false
  end
  -- buf[s_start] must be a genuine Normal-mode insert-entry key (the one
  -- that opens the edit window this shape detects), not an insert-mode-typed
  -- character that happens to share a letter — same is_normal_key gate as
  -- macro_contains_edit, see docs/adr/0116.
  if not (buf[s_start].is_normal_key and INSERT_KEYS[buf[s_start].tok]) or buf[n].tok ~= '<Esc>' then
    return false
  end
  if macro_contains_bad(buf, s_start, n) then
    return false
  end
  -- No separate macro_contains_edit check here (unlike macro_check_len):
  -- buf[s_start] is already guaranteed to be an INSERT_KEYS member above,
  -- and INSERT_KEYS ⊂ EDIT_OP_KEYS ⊂ MACRO_EDIT_KEYS, so contains_edit would
  -- always be true by construction — checking it would be dead code.

  local gap1 = buf[s_start - 1]
  if not gap1 or gap1.tok ~= 'j' then
    return false
  end
  local occ2_start = s_start - 1 - l
  if occ2_start < 1 then
    return false
  end
  if not macro_windows_equal(buf, occ2_start, s_start, l) then
    return false
  end

  local gap2 = buf[occ2_start - 1]
  if not gap2 or gap2.tok ~= 'j' then
    return false
  end
  local occ1_start = occ2_start - 1 - l
  if occ1_start < 1 then
    return false
  end
  if not macro_windows_equal(buf, occ1_start, s_start, l) then
    return false
  end

  return (buf[n].t - buf[occ1_start].t) <= MACRO_WINDOW_MS
end

local function visual_block_detect(seq)
  local buf = seq.macro_buf
  local n = #buf
  for l = MACRO_MIN_LEN, MACRO_MAX_LEN do
    if visual_block_check_len(buf, n, l) then
      return { pattern = 'visual_block_opportunity', cmd = '<C-v>' }
    end
  end
  return nil
end

local function macro_detect(seq)
  local vb = visual_block_detect(seq)
  if vb then
    return vb
  end
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
-- INSERT_SPECIAL table (patterns.lua stays vim.*-free, so this is threaded
-- in as a parameter, like is_diff/now).
-- now: optional caller-supplied clock (ms); omitted calls behave as now == 0.
-- is_normal_key: true when this token was fed from the Normal-mode call
-- site (logger.lua's handle_key, a genuine operator/command keystroke),
-- false/omitted when fed from handle_insert_key (an ordinary insert-mode
-- character stream, or its <Esc>/<BS>/etc canonical names). Only tokens fed
-- with is_normal_key=true can ever satisfy MACRO_EDIT_KEYS membership — see
-- macro_contains_edit and docs/adr/0116.
function M.feed_macro(seq, token, now, is_normal_key)
  local t = now or 0
  local buf = seq.macro_buf
  local prev = buf[#buf]
  local nav_run = 0
  if MACRO_NAV_KEYS[token] then
    nav_run = (prev and prev.nav_run or 0) + 1
  end
  buf[#buf + 1] = { tok = token, t = t, nav_run = nav_run, is_normal_key = is_normal_key == true }
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

-- Streak-tolerance bookkeeping (r_streak/ca_streak/ci_dquote_streak/
-- ci_squote_streak/fold_open_streak/fold_close_streak) and seq.run tracking
-- that must run for every key consumed as the resolving key of a two-or-
-- more-key prefix, not just keys that fall through inner_feed's dispatch
-- chain uncontested — see docs/adr/0026 and
-- docs/adr/0115-prefix-consumer-streak-bookkeeping.md.
--
-- `except` names the ONE family (if any) the calling branch has ALREADY
-- updated for `key` itself this same call, so this doesn't immediately
-- undo that update — nil | 'r' | 'ci' | 'fold'.
local function reset_unclaimed_streaks(seq, key, except)
  if except ~= 'r' and key ~= 'h' and key ~= 'l' then
    seq.r_streak = 0
  end
  if key ~= 'j' and key ~= 'k' then
    seq.ca_streak = 0
  end
  if not CI_QUOTE_NAV_KEYS[key] then
    if except ~= 'ci' then
      seq.ci_dquote_streak = 0
      seq.ci_squote_streak = 0
    end
    if except ~= 'fold' then
      seq.fold_open_streak = 0
      seq.fold_close_streak = 0
    end
  end
end

local function inner_feed(seq, key, line, is_diff, now, is_wrapped)
  -- ── changelist-underuse bookkeeping ────────────────────────────────────────
  -- Observes every key unconditionally, before any other handler, and never
  -- consumes/returns. EDIT_OP_KEYS mark "an edit just happened here"; any
  -- other key (except <Esc>) marks "the user left that spot" — the closest
  -- passive proxy for "moved elsewhere" without snapshotting the buffer or
  -- reading marks (both forbidden). See docs/adr/0019-jumplist-changelist-underuse-detection.md
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
  -- Raw byte for Ctrl-O (ASCII 15 / 0x0F). Recorded unconditionally so
  -- manual_return can permanently stop suggesting <C-o> once the user has
  -- demonstrably already used it. See docs/adr/0019-jumplist-changelist-underuse-detection.md
  if key == '\15' then
    seq.ctrl_o_seen = true
  end

  -- ── n-streak → change watch expiry ────────────────────────────────────────
  -- Observes every key unconditionally, before any dispatch. n_change_watch
  -- survives any key that is itself 'n' (streak continuing) or that is
  -- building toward a 'c'-family change already in progress (pending_op or
  -- pending_text_obj currently 'c', from a 'c' pressed on an earlier call —
  -- covers c, c<count>, ciw, ci", cit, ...; pending_op/pending_text_obj set
  -- to 'd' or 'y' do NOT count, so a delete/yank text object correctly
  -- expires the watch too). Any other key is treated as an unrelated
  -- intervening motion and expires the watch. See
  -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
  if key ~= 'n' and key ~= 'c' and seq.pending_op ~= 'c' and seq.pending_text_obj ~= 'c' then
    seq.n_change_watch = false
  end

  -- ── named-mark opportunity bookkeeping ────────────────────────────────────
  -- Observes every key unconditionally, like the changelist-underuse block
  -- above, and never consumes/returns — only increments mark_return_count.
  -- The actual fire-and-reset happens in the jumplist/changelist arbitration
  -- block further down, as the lowest-priority branch. See
  -- docs/adr/0100-named-mark-repeated-line-return.md
  if line ~= seq.mark_prev_line then
    if seq.mark_anchor_line == nil then
      if seq.mark_prev_line ~= nil then
        seq.mark_anchor_line = seq.mark_prev_line
        -- 0, not 1: choosing an anchor (the line just LEFT) is not itself a
        -- return to it — mark_return_count only counts genuine arrivals back
        -- at the anchor below. See docs/adr/0100-named-mark-repeated-line-return.md
        seq.mark_return_count = 0
        seq.mark_left_anchor = true
        seq.mark_edited_away = false
      end
    elseif line == seq.mark_anchor_line then
      if seq.mark_left_anchor and seq.mark_edited_away then
        seq.mark_return_count = seq.mark_return_count + 1
      end
      seq.mark_left_anchor = false
      seq.mark_edited_away = false
    elseif seq.mark_return_count == 0 then
      -- No genuine return has ever confirmed the current anchor is actually
      -- meaningful — re-anchor to the line just left instead of leaving the
      -- session permanently stuck on whatever line the cursor happened to
      -- be on before the very first navigation (often accidental, e.g. the
      -- line the cursor was at when the file was opened). Once a real
      -- return lands (mark_return_count > 0), the anchor is committed and
      -- this branch is never reached again until it fires or the session
      -- moves on. See docs/adr/0100-named-mark-repeated-line-return.md
      seq.mark_anchor_line = seq.mark_prev_line
      seq.mark_left_anchor = true
      seq.mark_edited_away = false
    else
      seq.mark_left_anchor = true
    end
    seq.mark_prev_line = line
  end
  if seq.mark_anchor_line and seq.mark_left_anchor and EDIT_OP_KEYS[key] then
    seq.mark_edited_away = true
  end

  -- ── p / P → rightward motion: cursor skipped past a paste ────────────────
  -- see docs/adr/0025-paste-motion-streak.md
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
    -- This key resolves the g-prefix — see reset_unclaimed_streaks and
    -- docs/adr/0115-prefix-consumer-streak-bookkeeping.md.
    reset_unclaimed_streaks(seq, key, nil)
    -- gq is a real operator (needs a further motion), unlike every other
    -- pending_g target below which is a complete two-key command on its own —
    -- hand it off to pending_gq instead of the flat dispatch table.
    if key == 'q' then
      seq.pending_gq = true
      track_run(seq, key)
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
      -- true only when a bare G was the most recently completed action and
      -- nothing else has happened since — see
      -- docs/adr/0019-jumplist-changelist-underuse-detection.md
      local g_then_gg = seq.last_op == 'G'
      seq.last_op = g_targets[key]
      seq.op_completed = true
      -- Reset unconditionally after any g-compound resolves, so a following
      -- bare `key` press starts a fresh streak instead of continuing a
      -- frozen one — see docs/adr/0019-jumplist-changelist-underuse-detection.md
      seq.run = { key = nil, count = 0 }
      -- gg / g; are themselves significant jumplist / changelist motions,
      -- recorded the moment the compound resolves — neither key of "gg" (or
      -- "g;") ever reaches the bare-key tables below on its own, since
      -- pending_g consumes both.
      if seq.last_op == 'gg' then
        seq.jump_last_at = now
        seq.jump_return_streak = 0
        -- G → gg: suggest '' — see
        -- docs/adr/0019-jumplist-changelist-underuse-detection.md
        if g_then_gg then
          return { pattern = 'jump_back', cmd = "''" }
        end
      elseif seq.last_op == 'g;' then
        seq.g_semi_seen = true
      end
    else
      -- Unrecognized key after 'g': not a real g-compound, but this key
      -- still must not be silently dropped from seq.run's bookkeeping — see
      -- reset_unclaimed_streaks's header.
      track_run(seq, key)
    end
    return nil
  end

  -- ── pending_gq: gq operator awaiting its motion ────────────────────────────
  -- see docs/adr/0022-gq-operator-pending-and-post-format-jumpback.md
  if seq.pending_gq then
    if key:match('^[1-9]$') then
      return nil -- count prefix; keep pending_gq (handles gq3j)
    end
    seq.pending_gq = false
    if key == '\27' then
      -- <Esc> resolves (aborts) the gq-pending state; still needs
      -- track_run/tolerance bookkeeping — see reset_unclaimed_streaks.
      reset_unclaimed_streaks(seq, key, nil)
      track_run(seq, key)
      return nil -- <Esc> cancels
    end
    if key == 'i' or key == 'a' then
      seq.pending_gq_text_obj = true
      return nil
    end
    -- 'q' (linewise, like dd) or any other motion character completes gq.
    seq.last_op = 'gq'
    seq.op_completed = true
    reset_unclaimed_streaks(seq, key, nil)
    track_run(seq, key)
    return nil
  end

  if seq.pending_gq_text_obj then
    seq.pending_gq_text_obj = false
    seq.last_op = 'gq'
    seq.op_completed = true
    reset_unclaimed_streaks(seq, key, nil)
    track_run(seq, key)
    return nil
  end

  if seq.pending_z then
    seq.pending_z = false
    -- This key resolves the z-prefix; fold_open/close_streak are already
    -- managed inline below (hence except='fold') — see
    -- reset_unclaimed_streaks's header.
    reset_unclaimed_streaks(seq, key, 'fold')
    track_run(seq, key)
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
      -- zf: unlike sibling zd, its raw keystroke needs counting too so it
      -- can be marked mastered (display-accuracy only; nothing else uses zf
      -- as a `requires` target).
      f = 'zf',
    }
    if z_targets[key] then
      seq.last_op = z_targets[key]
      seq.op_completed = true
      -- zo repeated (or alternated with itself) 2+ times → suggest zR. za is
      -- ambiguous (open-or-close depending on buffer fold state, which this
      -- keystroke-only design deliberately never reads) and every other
      -- z-target resets both streaks — see docs/adr/0108-fold-open-close-streak.md
      if key == 'o' then
        seq.fold_open_streak = seq.fold_open_streak + 1
        seq.fold_close_streak = 0
        if seq.fold_open_streak >= 2 then
          seq.fold_open_streak = 0
          -- beats_macro: logger.lua's dispatch reports this over a same-
          -- keystroke macro_opportunity result — see
          -- docs/adr/0114-macro-dispatch-priority-generalization.md.
          return { pattern = 'fold_open_repeat', cmd = 'zR', beats_macro = true }
        end
      -- zc repeated (or alternated with itself) 2+ times → suggest zM. See
      -- docs/adr/0108-fold-open-close-streak.md
      elseif key == 'c' then
        seq.fold_close_streak = seq.fold_close_streak + 1
        seq.fold_open_streak = 0
        if seq.fold_close_streak >= 2 then
          seq.fold_close_streak = 0
          return { pattern = 'fold_close_repeat', cmd = 'zM', beats_macro = true }
        end
      else
        seq.fold_open_streak = 0
        seq.fold_close_streak = 0
      end
    else
      seq.fold_open_streak = 0
      seq.fold_close_streak = 0
    end
    return nil
  end

  -- ── pending_ctrl_w: <C-w>X window-command two-key compound ────────────────
  -- see docs/adr/0024-ctrl-w-window-compound-and-close-streak.md and
  -- docs/adr/0096-ctrl-w-resize-streak.md
  if seq.pending_ctrl_w then
    seq.pending_ctrl_w = false
    -- This key resolves the <C-w>-prefix; ctrl_w's own streaks are a
    -- separate field entirely — see reset_unclaimed_streaks's header.
    reset_unclaimed_streaks(seq, key, nil)
    track_run(seq, key)
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
      ['+'] = '<C-w>+',
      ['-'] = '<C-w>-',
      ['<'] = '<C-w><',
      ['>'] = '<C-w>>',
    }
    if ctrl_w_targets[key] then
      seq.last_op = ctrl_w_targets[key]
      seq.op_completed = true
      -- <C-w>q / <C-w>c repeated (or alternated) 2+ times → suggest <C-w>o
      if key == 'q' or key == 'c' then
        seq.ctrl_w_close_streak = seq.ctrl_w_close_streak + 1
        seq.ctrl_w_resize_streak = 0
        if seq.ctrl_w_close_streak >= 2 then
          seq.ctrl_w_close_streak = 0
          -- beats_macro: <C-w>c's own 'c' is a MACRO_EDIT_KEYS member, so a
          -- long enough homogeneous <C-w>c run also satisfies
          -- macro_opportunity's anchored 3x-repeat window on this same
          -- keystroke — the identical #312 collision shape dd_run/r_run/etc.
          -- were fixed for. See docs/adr/0114-macro-dispatch-priority-generalization.md.
          return { pattern = 'ctrl_w_close_repeat', cmd = '<C-w>o', beats_macro = true }
        end
      -- <C-w>+ / <C-w>- / <C-w>< / <C-w>> repeated (or alternated) 2+ times
      -- → suggest <C-w>= — see docs/adr/0096-ctrl-w-resize-streak.md
      elseif key == '+' or key == '-' or key == '<' or key == '>' then
        seq.ctrl_w_resize_streak = seq.ctrl_w_resize_streak + 1
        seq.ctrl_w_close_streak = 0
        if seq.ctrl_w_resize_streak >= 2 then
          seq.ctrl_w_resize_streak = 0
          -- beats_macro: <C-w>< / <C-w>> resolve to MACRO_EDIT_KEYS members
          -- ('<'/'>') too — same collision shape as <C-w>c above. See
          -- docs/adr/0114-macro-dispatch-priority-generalization.md.
          return { pattern = 'ctrl_w_resize_repeat', cmd = '<C-w>=', beats_macro = true }
        end
      else
        seq.ctrl_w_close_streak = 0
        seq.ctrl_w_resize_streak = 0
      end
    else
      seq.ctrl_w_close_streak = 0
      seq.ctrl_w_resize_streak = 0
    end
    return nil
  end

  -- ── pending_clipboard_yank: "+ immediately followed by y ──────────────────
  -- Only 'y' completes the "+y compound; any other key falls through to that
  -- key's normal meaning. See docs/adr/0023-register-mark-bracket-prefix-consumers.md
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
  -- see docs/adr/0023-register-mark-bracket-prefix-consumers.md
  if seq.clipboard_yank_tail then
    seq.clipboard_yank_tail = false
    if key == 'y' then
      return nil
    end
  end

  -- ── single-char prefix consumers ─────────────────────────────────────────
  -- Must precede f/F/t/T below: a register or mark name that happens to BE
  -- f/F/t/T (e.g. "tyy, mt, `t) must be consumed here as that prefix's
  -- expected next character, not reinterpreted as the start of a fresh
  -- f/t-search — same ordering rule as pending_g/pending_z above. See
  -- lua/tobira/CLAUDE.md's "patterns.lua — state machine" section.
  if seq.pending_register then
    seq.pending_register = false
    seq.key_consumed = true
    -- This key resolves the register-name prefix — see
    -- reset_unclaimed_streaks's header.
    reset_unclaimed_streaks(seq, key, nil)
    track_run(seq, key)
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
    -- This key resolves the mark-name prefix — see
    -- reset_unclaimed_streaks's header.
    reset_unclaimed_streaks(seq, key, nil)
    track_run(seq, key)
    -- `` right after a completed gq — see
    -- docs/adr/0022-gq-operator-pending-and-post-format-jumpback.md
    if was_gq_backtick and key == '`' then
      seq.last_op = nil
      seq.key_consumed = true
      return { pattern = 'gq_then_jumpback', cmd = 'gw' }
    end
    seq.key_consumed = true
    return nil
  end

  if seq.pending_bracket then
    local bracket = seq.pending_bracket
    seq.pending_bracket = false
    seq.key_consumed = true
    -- This key resolves the bracket prefix — see
    -- reset_unclaimed_streaks's header.
    reset_unclaimed_streaks(seq, key, nil)
    track_run(seq, key)
    -- ]c / [c diff-hunk jump: arm diff_jump_dir for one following key only —
    -- see docs/adr/0099-diff-obtain-put-after-hunk-jump.md
    seq.diff_jump_dir = (key == 'c') and bracket or nil
    return nil
  end

  -- ── pending_text_obj ──────────────────────────────────────────────────────
  -- Must also precede f/F/t/T below, same ordering rule as the prefix
  -- consumers above: the tag text object (cit/dit/yit) uses 't' as its
  -- text-object character, which would otherwise be reinterpreted as the
  -- start of a fresh f/t-search instead of completing the pending text
  -- object.
  if seq.pending_text_obj then
    local op = seq.pending_text_obj
    local inner = seq.pending_text_obj_inner
    seq.pending_text_obj = nil
    seq.pending_text_obj_inner = false
    -- This key resolves the text-object prefix; ci_dquote_streak/
    -- ci_squote_streak are already managed inline below (hence
    -- except='ci') — see reset_unclaimed_streaks's header. seq.run is
    -- deliberately left untouched here (unlike the other prefix consumers):
    -- the pending_op starter (d/c/y) that always precedes this branch
    -- already wipes seq.run unconditionally on its own, so this key can
    -- never leave a stale PRE-compound value behind the way pending_r/
    -- pending_ctrl_w/etc's own starters don't — and text-object completions
    -- (ciw/diw/yiw) are deliberately not bare-motion keystrokes for
    -- w_repeat's own counting purposes.
    reset_unclaimed_streaks(seq, key, 'ci')
    seq.last_op = op .. 'w'
    seq.op_completed = true
    -- Sets key_consumed the same as pending_register/pending_mark/
    -- pending_bracket above -- without it, the completing key (e.g. the w of
    -- ciw/diw/yiw) also silently increments bare usage['w'].count on top of
    -- the correct cw/dw/yw and own-variant increments. See
    -- docs/adr/0026-state-machine-bookkeeping-invariants.md.
    seq.key_consumed = true

    -- Own tracked variant, alongside the shared op..'w' bucket set above —
    -- see docs/adr/0106-text-object-variant-own-usage-tracking.md.
    if TRACKED_TEXT_OBJ_CHARS[key] then
      seq.last_op_variant = op .. (inner and 'i' or 'a') .. key
    end

    -- ci"/ci' direct-path streak — see docs/adr/0020-ci-quote-streak-and-tolerance.md
    if op == 'c' and inner and key == '"' then
      seq.ci_squote_streak = 0
      seq.ci_dquote_streak = seq.ci_dquote_streak + 1
      if seq.ci_dquote_streak >= 3 then
        seq.ci_dquote_streak = 0
        return { pattern = 'ci_dquote_repeat', cmd = 'ya"', beats_macro = true }
      end
    elseif op == 'c' and inner and key == "'" then
      seq.ci_dquote_streak = 0
      seq.ci_squote_streak = seq.ci_squote_streak + 1
      if seq.ci_squote_streak >= 3 then
        seq.ci_squote_streak = 0
        return { pattern = 'ci_squote_repeat', cmd = "ya'", beats_macro = true }
      end
    else
      seq.ci_dquote_streak = 0
      seq.ci_squote_streak = 0
    end

    -- n-streak → change the match: suggest cgn (text-object path, e.g. ciw,
    -- ci", cit). Checked after the ci-quote streaks above so an
    -- already-qualifying ci_dquote_repeat/ci_squote_repeat keeps priority —
    -- see docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
    if op == 'c' and seq.n_change_watch then
      seq.n_change_watch = false
      return { pattern = 'n_then_change', cmd = 'cgn' }
    end

    return nil
  end

  -- ── pending_r: consume replacement character ──────────────────────────────
  -- Must also precede f/F/t/T below, same ordering rule as the prefix
  -- consumers above: r is a single-char prefix consuming exactly one
  -- following character, so r{f,F,t,T} must complete the replacement rather
  -- than being reinterpreted as a fresh f/t-search.
  if seq.pending_r then
    seq.pending_r = false
    -- This key resolves the r-prefix; r_streak is managed explicitly
    -- right below (hence except='r') — see reset_unclaimed_streaks's
    -- header.
    reset_unclaimed_streaks(seq, key, 'r')
    track_run(seq, key)
    seq.r_streak = seq.r_streak + 1
    if seq.r_streak >= 3 then
      seq.r_streak = 0
      return { pattern = 'r_run', cmd = 'R', beats_macro = true }
    end
    return nil
  end

  -- ── visual text-object tracking ───────────────────────────────────────────
  -- State: pending_visual → visual_inner → visual_obj → operator
  -- Must also precede f/F/t/T below, same ordering rule as pending_text_obj
  -- above: the tag text object (vit/vat) uses 't' as its text-object
  -- character.
  if seq.visual_obj then
    if key == 'c' or key == 'd' or key == 'y' then
      local cmd = key .. seq.visual_inner .. seq.visual_obj
      seq.visual_obj = nil
      seq.visual_inner = nil
      -- This key resolves the visual text-object chain — see
      -- reset_unclaimed_streaks's header (track_run only here: this
      -- chain's own characters are not one of the r/ca/ci/fold families).
      track_run(seq, key)
      return { pattern = 'visual_textobj', cmd = cmd }
    end
    -- Non-operator: cancel and fall through
    seq.visual_obj = nil
    seq.visual_inner = nil
  end

  if seq.visual_inner then
    seq.visual_obj = key
    track_run(seq, key)
    return nil
  end

  if seq.pending_visual then
    seq.pending_visual = false
    if key == '\27' then
      -- Tapped v and left immediately with no real usage — the v_repeat
      -- half of the streak. Fires here (on the confirming <Esc>), not on the
      -- v itself — see docs/adr/0021-visual-repeat-gv-detection.md
      seq.v_clean_exit = true
      track_run(seq, key)
      if seq.v_streak >= 3 then
        seq.v_streak = 0
        return { pattern = 'v_repeat', cmd = 'gv' }
      end
      return nil
    end
    seq.v_clean_exit = false
    seq.v_streak = 0
    if key == 'i' or key == 'a' then
      seq.visual_inner = key
    end
    track_run(seq, key)
    -- Whether accepted or cancelled, consume and return
    return nil
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

  -- ── pending_op ────────────────────────────────────────────────────────────
  if seq.pending_op then
    local op = seq.pending_op
    if key:match('^[1-9]$') then
      return nil
    end
    seq.pending_op = nil
    if key == '\27' then
      -- An aborted change is a resolved, non-qualifying action -- it must
      -- expire n_change_watch itself, the same as cc/cj/ck and c$ below, or
      -- the watch survives to fire on a later, wholly unrelated cw/ciw. See
      -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
      if op == 'c' then
        seq.n_change_watch = false
      end
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
            return { pattern = 'indent_run', cmd = '{n}>>', beats_macro = true }
          end
        else
          seq.dedent_streak = seq.dedent_streak + 1
          if seq.dedent_streak == 3 then
            seq.dedent_streak = 0
            return { pattern = 'dedent_run', cmd = '{n}<<', beats_macro = true }
          end
        end
      else
        seq.indent_streak = 0
        seq.dedent_streak = 0
      end
      return nil
    end

    -- ── y: track yy for yy_then_p, y$ for y_dollar, i/a text objects ──────
    -- i/a routes into pending_text_obj the same way d/c do below, so a
    -- following text-object key (e.g. the w of yiw) doesn't fall through as
    -- an ordinary standalone keystroke and corrupt seq.run's bare-motion
    -- streak. See docs/adr/0106-text-object-variant-own-usage-tracking.md.
    if op == 'y' then
      if key == 'y' then
        seq.last_op = 'yy'
        seq.op_completed = true
      elseif key == '$' then
        return { pattern = 'y_dollar', cmd = 'Y' }
      elseif key == 'i' or key == 'a' then
        seq.pending_text_obj = op
        seq.pending_text_obj_inner = key == 'i'
      end
      return nil
    end

    -- ── d / c operators ──────────────────────────────────────────────────
    if key == '$' then
      if op == 'c' then
        -- C is a resolved, non-qualifying 'c'-family completion (never
        -- becomes last_op == 'cw') -- must expire the watch itself, same
        -- reasoning as the <Esc>-abort case above. See
        -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
        seq.n_change_watch = false
        return { pattern = 'c_dollar', cmd = 'C' }
      elseif op == 'd' then
        return { pattern = 'd_dollar', cmd = 'D' }
      end
    elseif key == op or key == 'j' or key == 'k' then
      seq.last_op = op .. op -- 'dd' or 'cc' (also dj/dk, cj/ck: linewise, tracked the same)
      seq.op_completed = true
      if op == 'c' then
        -- cc/cj/ck (linewise) never become last_op == 'cw' either -- same
        -- non-qualifying-completion reasoning as c$/C and <Esc>-abort above.
        -- This is also what actually implements "cc is deliberately
        -- excluded": clearing here, not just declining to fire, is what
        -- stops a later unrelated cw from firing off this stale watch. See
        -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
        seq.n_change_watch = false
      end
      if key == op then
        if op == 'd' then
          seq.dd_streak = seq.dd_streak + 1
          if seq.dd_streak >= 3 then
            seq.dd_streak = 0
            return { pattern = 'dd_run', cmd = '{n}dd', beats_macro = true }
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
      seq.pending_text_obj_inner = key == 'i'
    else
      seq.last_op = op .. 'w'
      seq.op_completed = true
      -- n-streak → change the match: suggest cgn (charwise-motion path, e.g.
      -- cw, ce, c3w). Text-object path (ciw, ci", ...) is handled in the
      -- pending_text_obj block above. See
      -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
      if op == 'c' and seq.n_change_watch then
        seq.n_change_watch = false
        return { pattern = 'n_then_change', cmd = 'cgn' }
      end
    end
    return nil
  end

  -- ── d / c / y / > / < / = operator start ─────────────────────────────────
  -- '=': falls through the same generic pending_op machinery as >/< above —
  -- key==op sets last_op='==' via the shared "same operator" branch, with no
  -- streak tracking needed (nothing else uses == as a `requires` target;
  -- display-accuracy only).
  -- Starting an operator sequence (d/c/y/>/</=, e.g. the first 'd' of 'dd')
  -- resolves entirely inside the pending_op block above on every subsequent
  -- call and never reaches the "any unrelated key resets state" block below
  -- (key ~= 'p' check) -- so ctrl_w/fold streaks must be reset explicitly
  -- here too, or a streak like "zo" survives completely unrelated edits
  -- (e.g. 'zo', 'dd', 'zo' would wrongly fire fold_open_repeat on the 2nd
  -- zo). Independent QA finding on PR #288 -- see
  -- docs/adr/0108-fold-open-close-streak.md.
  if key == 'd' or key == 'c' or key == 'y' or key == '>' or key == '<' or key == '=' then
    seq.pending_op = key
    seq.run = { key = nil, count = 0 }
    seq.ctrl_w_close_streak = 0
    seq.ctrl_w_resize_streak = 0
    seq.fold_open_streak = 0
    seq.fold_close_streak = 0
    return nil
  end

  -- ── r: single-char replace ────────────────────────────────────────────────
  if key == 'r' then
    seq.pending_r = true
    return nil
  end

  -- ── <C-a>: sequential-increment streak tracking ────────────────────────────
  -- Raw byte for Ctrl-A (ASCII 1 / 0x01). See docs/adr/0027-tolerated-motion-streaks-r-and-ctrl-a.md
  if key == '\1' then
    seq.ca_streak = seq.ca_streak + 1
    if seq.ca_streak >= 3 then
      seq.ca_streak = 0
      return { pattern = 'ca_run', cmd = 'g<C-a>' }
    end
    return nil
  end

  -- ── v: start visual text-object tracking ─────────────────────────────────
  -- Also extends the v_repeat streak — see docs/adr/0021-visual-repeat-gv-detection.md
  if key == 'v' then
    seq.v_streak = seq.v_clean_exit and (seq.v_streak + 1) or 1
    seq.v_clean_exit = false
    seq.pending_visual = true
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
    -- stores the bracket char itself (not a plain true) so the consumer
    -- above can tell ]c apart from [c — see
    -- docs/adr/0099-diff-obtain-put-after-hunk-jump.md
    seq.pending_bracket = key
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

  -- ── ci_dquote_streak / ci_squote_streak reset for keys that break the ────
  -- ── ci"/ci' repeat flow ───────────────────────────────────────────────────
  -- Deliberately NOT folded into the generic reset block further down (unlike
  -- dd_streak/cc_streak/etc there, which really should hard-reset on any
  -- intervening key): reaching a different quoted string to ci" it again
  -- necessarily requires a motion in between, so CI_QUOTE_NAV_KEYS (above)
  -- tolerates the ordinary single-key motions a user presses to get there.
  -- Anything else reaching this point (an unrelated edit, another operator,
  -- ...) still resets both streaks.
  if not CI_QUOTE_NAV_KEYS[key] then
    seq.ci_dquote_streak = 0
    seq.ci_squote_streak = 0
  end

  -- ── fold_open_streak / fold_close_streak reset for keys that break the ──
  -- ── zo/zc repeat flow ─────────────────────────────────────────────────────
  -- Deliberately NOT folded into the generic reset block further down, same
  -- reasoning as ci_dquote_streak/ci_squote_streak just above: reaching a
  -- DIFFERENT fold to zo/zc it again necessarily requires a motion in
  -- between (unlike ctrl_w_close_streak, where <C-w>q naturally re-focuses
  -- the next window with no intervening key needed) -- a hard reset on any
  -- key made this streak nearly impossible to observe in realistic usage
  -- (independent QA finding on PR #288; see docs/adr/0020's own closing
  -- guidance for streaks that must "survive across a necessary motion", and
  -- docs/adr/0108-fold-open-close-streak.md). Reuses CI_QUOTE_NAV_KEYS as the
  -- tolerance set -- an unrelated edit, another operator, or a big jump
  -- (gg/G) still resets both streaks.
  if not CI_QUOTE_NAV_KEYS[key] then
    seq.fold_open_streak = 0
    seq.fold_close_streak = 0
  end

  -- ── yy → p (duplicate line) ──────────────────────────────────────────────
  -- Also arms pending_paste, so the generic "p / P: arm cursor-skip-past-
  -- paste tracking" code further below still runs for this same p — without
  -- it, gp is never suggested for a yyp/ddp paste. See
  -- docs/adr/0025-paste-motion-streak.md.
  if key == 'p' and seq.last_op == 'yy' then
    seq.last_op = nil
    seq.pending_paste = 'p'
    seq.paste_motion_streak = 0
    return { pattern = 'yy_then_p', cmd = 'yyp' }
  end

  -- ── dd → p (swap lines) ──────────────────────────────────────────────────
  -- Also arms pending_paste — see the yy_then_p comment above.
  if key == 'p' and seq.last_op == 'dd' then
    seq.last_op = nil
    seq.dd_streak = 0
    seq.pending_paste = 'p'
    seq.paste_motion_streak = 0
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

  -- ── diff-hunk jump → insert: suggest do/dp ────────────────────────────────
  -- While &diff is set, entering insert mode immediately after a ]c/[c jump
  -- means the user is about to manually retype a change do/dp would copy in
  -- one command. Direction is picked off which bracket was pressed — see
  -- docs/adr/0099-diff-obtain-put-after-hunk-jump.md
  if is_diff and seq.diff_jump_dir and INSERT_KEYS[key] then
    local dir = seq.diff_jump_dir
    seq.diff_jump_dir = nil
    if dir == ']' then
      return { pattern = 'diff_jump_then_insert_next', cmd = 'do' }
    else
      return { pattern = 'diff_jump_then_insert_prev', cmd = 'dp' }
    end
  end

  -- ── gq → <C-o>: jump back after format, suggest gw ────────────────────────
  -- Raw byte for Ctrl-O (ASCII 15 / 0x0F). <C-o> is already a complete
  -- "jump back" command on its own (unlike `` ` ``, which needs a second key),
  -- so this only needs a direct last_op check, not a pending_* prefix state.
  if key == '\15' and seq.last_op == 'gq' then
    seq.last_op = nil
    return { pattern = 'gq_then_jumpback', cmd = 'gw' }
  end

  -- ── gg → G: suggest '' (jump back to position before gg) ─────────────────
  -- Only captures a flag here; the actual fire-and-return happens later,
  -- inside the JUMP_MOTION_KEYS block below, after that block's own
  -- bookkeeping has run for this G — see docs/adr/0019-jumplist-changelist-underuse-detection.md
  local gg_then_G = key == 'G' and seq.last_op == 'gg'

  -- ci_dquote_streak/ci_squote_streak and fold_open_streak/fold_close_streak
  -- are deliberately NOT reset here — see their own dedicated tolerance
  -- checks (CI_QUOTE_NAV_KEYS) earlier in this function, right after the
  -- ca_streak reset.
  if key ~= 'p' then
    seq.last_op = nil
    seq.dd_streak = 0
    seq.cc_streak = 0
    seq.indent_streak = 0
    seq.dedent_streak = 0
    seq.ctrl_w_close_streak = 0
    seq.ctrl_w_resize_streak = 0
    seq.v_streak = 0
    seq.v_clean_exit = false
  end

  -- diff_jump_dir survives only until the very next key — any key reaching
  -- this point already failed the diff_jump_then_insert check above (an
  -- INSERT_KEYS match would have returned before here), so the "immediately
  -- following" window has closed. See docs/adr/0099-diff-obtain-put-after-hunk-jump.md
  seq.diff_jump_dir = nil

  -- ── consecutive-run patterns (count computed early) ────────────────────────
  -- track_run() must run unconditionally on every key — see
  -- docs/adr/0026-state-machine-bookkeeping-invariants.md
  local count = track_run(seq, key)

  -- ── jumplist-underuse detection ──────────────────────────────────────────
  -- Only reached for keys that fell through every operator/compound-pending
  -- state above uncontested. Does not return early on its own — see the
  -- arbitration block below. See docs/adr/0019-jumplist-changelist-underuse-detection.md
  local jump_ready = false
  if key == 'G' or JUMP_MOTION_KEYS[key] then
    seq.jump_last_at = now
    seq.jump_return_streak = 0
    -- Only reached when gg_then_G (above) did NOT already fire — so this
    -- only runs for a bare G with no immediately-preceding gg.
    -- Deliberately NOT paired with op_completed = true: G is already
    -- tracked as a plain single keystroke via logger.lua's TRACK table.
    if key == 'G' then
      seq.last_op = 'G'
      -- gg → G jump_back: fires here, after this G's own bookkeeping
      -- above has already run. See docs/adr/0019-jumplist-changelist-underuse-detection.md
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
  -- Like the jumplist block above, does not return early — see the
  -- arbitration block below. See docs/adr/0019-jumplist-changelist-underuse-detection.md
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

  -- ── zz cursor-centering streak: <C-e>/<C-y> repeated (any mix) ───────────
  -- Independent of the RETURN_MOTION_KEYS bookkeeping above — increments off
  -- the same two keys but is never reset or read by jump_return_streak /
  -- change_return_streak, and vice versa. See
  -- docs/adr/0097-cursor-centering-streak.md
  if key == '\5' or key == '\25' then
    seq.zz_streak = seq.zz_streak + 1
  else
    seq.zz_streak = 0
  end
  local zz_ready = seq.zz_streak >= CURSOR_CENTER_STREAK_THRESHOLD

  -- named-mark opportunity readiness — bookkeeping already ran at the top of
  -- this function; this only reads the counter. See
  -- docs/adr/0100-named-mark-repeated-line-return.md
  local mark_ready = seq.mark_return_count >= NAMED_MARK_RETURN_THRESHOLD

  -- ── arbitration (follow-up bug) ───────────────────────────────────────────
  -- jump_ready/change_ready/zz_ready/mark_ready can all be true on the same
  -- keystroke; jump vs. change already arbitrate by recency (the
  -- more-recently triggered one wins). zz_ready and mark_ready are lower
  -- priority than both — jump_back/manual_return/changelist_return are more
  -- specific, contextual suggestions for the same underlying keystrokes. The
  -- loser's streak resets without firing, not left dangling, so it can still
  -- legitimately fire later if it genuinely repeats. See
  -- docs/adr/0019-jumplist-changelist-underuse-detection.md,
  -- docs/adr/0097-cursor-centering-streak.md,
  -- docs/adr/0100-named-mark-repeated-line-return.md
  if jump_ready and change_ready then
    seq.zz_streak = 0
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
    seq.zz_streak = 0
    return { pattern = 'manual_return', cmd = '<C-o>' }
  elseif change_ready then
    seq.change_return_streak = 0
    seq.edit_second_seen = false
    seq.edit_last_at = nil
    seq.zz_streak = 0
    return { pattern = 'changelist_return', cmd = 'g;' }
  elseif zz_ready then
    seq.zz_streak = 0
    return { pattern = 'cursor_center_repeat', cmd = 'zz' }
  elseif mark_ready then
    seq.mark_return_count = 0
    seq.mark_anchor_line = nil
    seq.mark_left_anchor = false
    seq.mark_edited_away = false
    return { pattern = 'named_mark_opportunity', cmd = 'ma', beats_macro = true }
  end

  -- == (not >=): each threshold fires exactly once, enabling multi-threshold
  -- patterns like j_repeat(5) and j_many(10) for the same key.
  if key == 'x' and count == 3 then
    return { pattern = 'x_repeat', cmd = '{n}x' }
  elseif key == 'u' and count == 3 then
    return { pattern = 'u_repeat', cmd = '<C-r>' }
  elseif key == 'j' and count == 5 then
    -- While the cursor is on a genuinely wrapped (multi-screen-row) line with
    -- 'wrap' set, gj (display-line motion) beats a {n}j count prefix — {n}j
    -- would jump by buffer lines, which is not what "move down 5 more times"
    -- means visually on a wrapped line. is_wrapped is a plain parameter, not
    -- seq state, for the same reason is_diff is: see logger.lua for where
    -- it's computed and passed in.
    if is_wrapped then
      return { pattern = 'j_repeat_wrapped', cmd = 'gj' }
    end
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
    if is_wrapped then
      return { pattern = 'k_repeat_wrapped', cmd = 'gk' }
    end
    return { pattern = 'k_repeat', cmd = '{n}k' }
  elseif key == 'k' and count == 10 then
    if is_diff then
      return { pattern = 'k_many_diff', cmd = '[c' }
    end
    return { pattern = 'k_many', cmd = '{' }
  elseif key == 'n' and count == 2 then
    -- Arms n_change_watch (consumed by a 'c'-family change completing, or
    -- expired by an unrelated key — see the guard near the top of this
    -- function). Silent: an n-streak alone is not evidence of edit intent,
    -- only a lower, secondary threshold worth watching from — see
    -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
    seq.n_change_watch = true
    return nil
  elseif key == 'n' and count == 4 then
    -- Intent-neutral, like j_repeat/k_repeat: a bare n-streak is equally
    -- likely to be browsing as editing, so this suggests the count-prefix
    -- jump, not cgn. cgn is now only suggested reactively by n_then_change,
    -- once a change action actually confirms edit intent — see
    -- docs/adr/0107-n-repeat-intent-neutral-reactive-cgn.md.
    return { pattern = 'n_repeat', cmd = '{n}n' }
  elseif key == 'l' and count == 5 then
    return { pattern = 'l_repeat', cmd = 'w' }
  elseif key == 'h' and count == 5 then
    return { pattern = 'h_repeat', cmd = 'b' }
  elseif key == 'w' and count == 5 then
    return { pattern = 'w_repeat', cmd = 'W' }
  elseif key == 'b' and count == 5 then
    return { pattern = 'b_repeat', cmd = 'B' }
  elseif key == 'e' and count == 5 then
    return { pattern = 'e_repeat', cmd = 'ge' }
  elseif key == 'p' and count == 3 then
    return { pattern = 'p_repeat', cmd = '{n}p' }
  elseif key == 'P' and count == 3 then
    return { pattern = 'P_repeat', cmd = '{n}P' }
  elseif key == '~' and count == 3 then
    return { pattern = 'tilde_repeat', cmd = '{n}~' }
  elseif key == '~' and count == TILDE_WORD_THRESHOLD then
    -- Supersedes tilde_repeat once the streak plausibly spans a whole word —
    -- see docs/adr/0101-tilde-repeat-text-object-refinement.md
    return { pattern = 'tilde_word_repeat', cmd = 'g~iw' }
  elseif key == '~' and count == TILDE_LINE_THRESHOLD then
    return { pattern = 'tilde_line_repeat', cmd = 'g~$' }
  elseif key == '.' and count == 3 then
    return { pattern = 'dot_repeat', cmd = '{n}.' }
  elseif key == 'J' and count == 3 then
    return { pattern = 'J_repeat', cmd = '{n}J' }
  end

  return nil
end

-- Pure width comparison deciding whether a line would genuinely wrap across
-- more than one screen row: true when its rendered width exceeds the
-- window's usable text width (window width minus number/sign/fold column
-- offsets). Kept as a standalone pure function — no vim.* calls — so it's
-- directly unit-testable with synthetic width inputs, and so logger.lua can
-- feed it real vim.fn.strdisplaywidth()/getwininfo() values without
-- patterns.lua ever touching vim.* itself. See
-- docs/adr/0109-wrap-aware-gj-gk-redirect.md for why this technique was
-- chosen over comparing vim.fn.winline()/screenpos() deltas, and for its
-- known edge cases (folds, conceal, virtual text).
function M.is_wrapped_line(display_width, text_width)
  return text_width > 0 and display_width > text_width
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
--
-- is_wrapped: true when 'wrap' is set on the window AND the cursor's current
-- line genuinely spans multiple screen rows (see is_wrapped_line above).
-- Only consulted by j_repeat/k_repeat. Threaded in the same way as is_diff —
-- appended after `now` rather than inserted before it, so existing 3/4/5-arg
-- call sites (this module has hundreds across patterns_spec.lua) keep working
-- unchanged; an omitted argument is falsy, same as omitted is_diff.
function M.feed(seq, key, line, is_diff, now, is_wrapped)
  seq.key_consumed = false -- reset before each call; handlers set true when consuming
  seq.op_completed = false -- reset before each call; handlers set true when last_op is freshly set
  seq.last_op_variant = nil -- reset before each call; set only by the call that resolves pending_text_obj
  local result = inner_feed(seq, key, line, is_diff, now or 0, is_wrapped)
  return result
end

return M
