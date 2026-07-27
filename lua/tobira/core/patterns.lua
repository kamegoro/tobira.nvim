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
    -- <C-a> sequential-increment tracking: <C-a> j <C-a> j <C-a> → g<C-a> (#108)
    ca_streak = 0,
    -- visual text-object tracking: v i {obj} c/d/y → c/d/yiw etc.
    pending_visual = false,
    visual_inner = nil,
    visual_obj = nil,
    -- g* / z* two-key compound tracking
    pending_g = false,
    pending_z = false,
    -- gq operator-pending tracking (#109): unlike the simple two-key pending_g
    -- targets (gg, gj, gd, …), gq is a real Vim operator that needs a further
    -- motion (gqq, gqap, gq}) before it's complete — see pending_gq below.
    pending_gq = false,
    pending_gq_text_obj = false,
    -- true only while the immediately-preceding mark-prefix key (`) started
    -- right after a completed gq — lets the very next key tell "`` (jump back,
    -- suggest gw)" apart from an unrelated "`a (jump to mark a)".
    pending_gq_backtick = false,
    -- <C-w>X window-command two-key compound tracking (#120)
    pending_ctrl_w = false,
    -- <C-w>q / <C-w>c repeated (or alternated) 2+ times in a row → <C-w>o (#107)
    ctrl_w_close_streak = 0,
    -- prefixes that consume exactly one following character
    pending_register = false, -- " or @ (register / macro name)
    pending_mark = false, -- m / ' / ` (mark name or target)
    pending_bracket = false, -- [ or ] (navigation pair)
    -- "+ register-select immediately followed by y → "+y system-clipboard
    -- yank compound (#59). Set by the pending_register consumer below only
    -- when the register name was '+'; consumed by the very next key.
    pending_clipboard_yank = false,
    -- True for exactly one key right after the "+y compound above fires.
    -- "+y is deliberately tracked as complete the moment the register-select
    -- 'y' arrives (3 keystrokes total), without waiting for the further
    -- motion a bare 'y' operator would normally need. In real Vim that same
    -- 'y' is still operator-pending, so its most common completion — another
    -- 'y', forming "+yy (yank current line to the system clipboard) — is
    -- still coming right behind it. Without this guard that trailing 'y'
    -- falls through to the generic "d/c/y operator start" branch below and
    -- sets pending_op = 'y', which then silently swallows whatever key comes
    -- after THAT as if it were y's motion (bug: dangling pending_op eats the
    -- next real keystroke, e.g. "+yy followed by 5 j's needed a 6th to fire
    -- j_repeat).
    clipboard_yank_tail = false,
    -- p / P → rightward motion: cursor skipped past a paste, suggest gp/gP (#106)
    pending_paste = nil, -- 'p' | 'P' | nil
    paste_motion_streak = 0,
    -- set true by M.feed when the key was the second char of a compound;
    -- logger uses this to skip standalone TRACK counting for that key
    key_consumed = false,
    -- set true by M.feed on the exact call that freshly assigns seq.last_op
    -- (a compound operation just completed). logger.lua increments usage
    -- from this flag rather than comparing last_op's value before/after —
    -- a value comparison can't tell "the same compound completed again"
    -- from "nothing happened", which undercounted back-to-back repeats of
    -- the same compound (dd dd, dw dw, …) — see #119.
    op_completed = false,
    -- jumplist-underuse tracking (#61): timestamp of the last "significant"
    -- jump motion (G / gg / n / N / <C-d> / <C-u> / <C-f> / <C-b>), and how
    -- many consecutive manual "return" motions (j / k / <C-e> / <C-y>) have
    -- followed it since. now (the 4th M.feed argument) is caller-supplied so
    -- this file stays vim.*-free — see M.feed's doc comment.
    jump_last_at = nil,
    jump_return_streak = 0,
    -- true once <C-o> has been pressed this session — the user already knows
    -- about jumplist-back, so manual_return stops suggesting it (#61).
    ctrl_o_seen = false,
    -- changelist-underuse tracking (#61): timestamp of the most recent
    -- edit-op key (i/I/a/A/o/O/s/S/x/X), whether some other key has been
    -- seen since (a passive proxy for "moved away" from that spot — patterns.lua
    -- may not snapshot the buffer or read marks), and whether a *second*,
    -- separately-located edit has happened yet.
    edit_last_at = nil,
    edit_moved_away = false,
    edit_second_seen = false,
    change_return_streak = 0,
    -- true once g; has been pressed this session — mirrors ctrl_o_seen (#61).
    g_semi_seen = false,
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
-- checked by the p/P → gp/gP cursor-skip-past-paste pattern (#106).
local RIGHTWARD_KEYS = {
  l = true,
  w = true,
  W = true,
  e = true,
  E = true,
  ['$'] = true,
}

-- ── jumplist / changelist underuse detection (#61) ──────────────────────────
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

-- Keys that mutate the buffer on their own — either by entering insert mode
-- (i/I/a/A/o/O/s/S, reusing INSERT_KEYS above) or by editing directly without
-- ever leaving normal mode (x/X). Each one is a point where Vim would add a
-- changelist entry.
local EDIT_OP_KEYS = { x = true, X = true }
for k in pairs(INSERT_KEYS) do
  EDIT_OP_KEYS[k] = true
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
  -- ── changelist-underuse bookkeeping (#61) ─────────────────────────────────
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

  -- ── <C-o> observation (#61) ────────────────────────────────────────────────
  -- Raw byte for Ctrl-O (ASCII 15 / 0x0F). Recorded unconditionally (unlike
  -- the gq_then_jumpback check further down, which only fires its own
  -- suggestion when last_op == 'gq') so manual_return can permanently stop
  -- suggesting <C-o> once the user has demonstrably already used it.
  if key == '\15' then
    seq.ctrl_o_seen = true
  end

  -- ── p / P → rightward motion: cursor skipped past a paste (#106) ─────────
  -- Checked first, before any other handler, so it observes every key that
  -- follows a paste — including keys other handlers would otherwise consume
  -- (e.g. g, ", m). Unlike those handlers this one does NOT return early on
  -- a non-firing key: rightward motions still fall through to their own
  -- patterns (l_repeat, w_repeat, zero_then_w, ...), and non-motion keys
  -- just cancel the pending streak and fall through unchanged. p/P re-press
  -- is exempted from cancelling so p_repeat / P_repeat below are unaffected.
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
    -- hand it off to pending_gq instead of the flat dispatch table (#109).
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
      seq.last_op = g_targets[key]
      seq.op_completed = true
      -- gg / g; are themselves significant jumplist / changelist motions
      -- (#61), recorded the moment the compound resolves — neither key of
      -- "gg" (or "g;") ever reaches the bare-key tables below on its own,
      -- since pending_g consumes both.
      if seq.last_op == 'gg' then
        seq.jump_last_at = now
        seq.jump_return_streak = 0
      elseif seq.last_op == 'g;' then
        seq.g_semi_seen = true
      end
    end
    return nil
  end

  -- ── pending_gq: gq operator awaiting its motion (#109) ────────────────────
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

  -- ── pending_ctrl_w: <C-w>X window-command two-key compound (#120) ─────────
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
      -- closing windows one at a time — suggest <C-w>o instead (#107).
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

  -- ── pending_clipboard_yank: "+ immediately followed by y (#59) ────────────
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

  -- ── clipboard_yank_tail: the key right after "+y completes (#59) ──────────
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
    -- "+ specifically arms pending_clipboard_yank (#59); every other register
    -- name (including "* — see the issue's scope note) keeps the existing
    -- consume-and-forget behavior below.
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
    -- where they started — exactly what gw does automatically (#109).
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

    -- ── y: track yy for yy_then_p ────────────────────────────────────────
    if op == 'y' then
      if key == 'y' then
        seq.last_op = 'yy'
        seq.op_completed = true
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

  -- ── <C-a>: sequential-increment streak tracking (#108) ────────────────────
  -- Raw byte for Ctrl-A (ASCII 1 / 0x01). Detects the "increment → move →
  -- increment" hand-rolled sequence (<C-a> j <C-a> j <C-a>, 3+ times) that
  -- means the user is manually building a numbered sequence one line at a
  -- time, and suggests selecting the block with <C-v> and running g<C-a>
  -- once instead. Same streak-counter shape as r_streak above: increment on
  -- every occurrence, fire at the 3rd, reset via the tolerated-motion check
  -- further down (j/k here, in place of r_streak's h/l).
  if key == '\1' then
    seq.ca_streak = seq.ca_streak + 1
    if seq.ca_streak >= 3 then
      seq.ca_streak = 0
      return { pattern = 'ca_run', cmd = 'g<C-a>' }
    end
    return nil
  end

  -- ── v: start visual text-object tracking ─────────────────────────────────
  if key == 'v' then
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

  -- ── <C-w>: start window-command two-key compound tracking (#120) ─────────
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

  -- ── ca_streak reset for keys that break the C-a increment flow (#108) ────
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

  -- ── p / P: arm cursor-skip-past-paste tracking (#106) ────────────────────
  -- Not consumed here — p/P still fall through to p_repeat / P_repeat via
  -- the track_run() call at the bottom of this function. The top-of-function
  -- check above uses this state to detect several rightward moves right
  -- after this paste.
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

  -- ── gq → <C-o>: jump back after format, suggest gw (#109) ────────────────
  -- Raw byte for Ctrl-O (ASCII 15 / 0x0F). <C-o> is already a complete
  -- "jump back" command on its own (unlike `` ` ``, which needs a second key),
  -- so this only needs a direct last_op check, not a pending_* prefix state.
  if key == '\15' and seq.last_op == 'gq' then
    seq.last_op = nil
    return { pattern = 'gq_then_jumpback', cmd = 'gw' }
  end

  if key ~= 'p' then
    seq.last_op = nil
    seq.dd_streak = 0
    seq.cc_streak = 0
    seq.indent_streak = 0
    seq.dedent_streak = 0
    seq.ctrl_w_close_streak = 0
  end

  -- ── consecutive-run patterns (count computed early, #61) ──────────────────
  -- track_run() must run unconditionally on every key, even one that the
  -- jumplist/changelist blocks below are about to return early on — skipping
  -- it here would freeze seq.run's same-key counter for that keystroke, and
  -- the very next same-key press would then jump it forward by 2 instead of
  -- 1, making j_repeat/k_repeat/j_many/k_many fire one press "early" right
  -- after a manual_return/changelist_return — which then cancels and
  -- replaces the just-shown suggestion via suggest.queue()'s debounce
  -- (observed via the docs/RECORDING.md-style live regression pass for #61,
  -- not caught by patterns_spec.lua's per-call assertions).
  local count = track_run(seq, key)

  -- ── jumplist-underuse detection (#61) ────────────────────────────────────
  -- Only reached for keys that fell through every operator/compound-pending
  -- state above uncontested — e.g. `dj` never reaches this: pending_op
  -- already consumed the j as part of a linewise delete, not a "return".
  -- NOTE: this no longer returns early on its own — see the arbitration
  -- block below for why (#61 follow-up bug).
  local jump_ready = false
  if key == 'G' or JUMP_MOTION_KEYS[key] then
    seq.jump_last_at = now
    seq.jump_return_streak = 0
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

  -- ── changelist-underuse detection (#61) ──────────────────────────────────
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

  -- ── jumplist vs. changelist arbitration (#61 follow-up bug) ──────────────
  -- Both patterns key off the same evidence — "5+ consecutive j/k after some
  -- earlier event" — so a single keystroke can legitimately satisfy both at
  -- once (e.g. jump far, edit, jump far again, edit, then k×5 back). The two
  -- blocks above therefore no longer return early on their own: they only
  -- record whether each pattern's threshold was reached this keystroke
  -- (jump_ready / change_ready), and this block decides what to do once both
  -- are known.
  --
  -- When only one is ready, it fires exactly as before (no behavior change
  -- for the existing single-pattern cases). When both are ready on the same
  -- keystroke, the one whose triggering "away" event — the significant jump
  -- for manual_return, the second edit for changelist_return — happened MORE
  -- RECENTLY wins: that's the more likely thing the user is actually trying
  -- to get back to right now. The other side's streak is reset without
  -- firing rather than left dangling, so it doesn't immediately re-fire on
  -- the very next keystroke; it can still build back up and fire later if
  -- the underlying pattern genuinely repeats.
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
    -- #111: while &diff is set, hunting for the next changed hunk with plain
    -- j is better served by ]c (jump to next hunk) than } (paragraph jump).
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

-- is_diff: optional boolean — true when &diff is set on the window the
-- keystroke came from (#111). Only consulted by the j_many/k_many branches
-- above; every other pattern ignores it. Passed in by the caller (logger.lua
-- reads vim.wo.diff) rather than read here, because patterns.lua has zero
-- vim.* dependencies by design (see lua/tobira/CLAUDE.md's module dependency
-- rules) — it is pure Lua so it can be unit-tested and reasoned about without
-- a running Neovim instance.
--
-- now: optional caller-supplied clock reading (milliseconds, any
-- monotonic-ish source is fine) used only by the jumplist/changelist
-- tolerance-window checks (#61). Omitted calls behave as if now == 0 on
-- every call, which keeps every pre-#61 call site (and every test not
-- exercising the time-sensitive patterns) working unchanged, since a
-- constant clock never lets a tolerance window "expire". Real callers
-- (logger.lua) pass vim.loop.now(); tests pass a fake, deterministic value.
function M.feed(seq, key, line, is_diff, now)
  seq.key_consumed = false -- reset before each call; handlers set true when consuming
  seq.op_completed = false -- reset before each call; handlers set true when last_op is freshly set
  local result = inner_feed(seq, key, line, is_diff, now or 0)
  return result
end

return M
