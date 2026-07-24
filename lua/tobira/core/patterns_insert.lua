-- Pure insert-mode key-streak detection. No vim.* calls.
--
-- A separate, much simpler state machine from patterns.lua's seq/feed (#99:
-- these two share no state and are never called from the same code path, so
-- they live in separate files rather than one file with two unrelated
-- concerns — see lua/tobira/CLAUDE.md's "Module splitting policy").
--
-- logger.lua only calls feed_insert() while its mode cache says the user is
-- in insert mode, passing a canonical key name ('<BS>', '<Left>', '<Right>',
-- '<Esc>') for the keys this cares about, or nil for any other ordinary
-- typed character.
--
-- Design note: bounce detection lives here (not as mode-transition bookkeeping
-- in logger.lua) because the <Esc> that exits insert mode is still delivered
-- to vim.on_key while the mode cache reads 'i' (the ModeChanged autocmd that
-- flips it to 'n' fires as a *result* of processing that key) — so by the
-- time feed_insert() sees '<Esc>', it is still routed as an insert-mode key,
-- exactly like every other key this function cares about.
--
-- #105 — insert-mode <C-o> one-shot detection (feed_after_escape, below):
-- unlike every other pattern in this file, this one's state lives here (it
-- is bookkeeping about leaving/returning to insert mode, the same concern
-- bounce detection already owns) but is *fed* from logger.lua's NORMAL-mode
-- branch, not its insert-mode branch. That is not a state-sharing violation
-- of the patterns.lua/patterns_insert.lua split (see lua/tobira/CLAUDE.md):
-- patterns.lua's `seq` and this file's `iseq` remain two separate objects
-- with no shared fields — only logger.lua's orchestration layer calls into
-- both for the same keystroke, which is exactly its job (keystroke → pattern
-- → increment → persist). See feed_after_escape's own doc comment for why the
-- detection has to cross the mode boundary this way.

local M = {}

function M.new_insert_seq()
  return {
    bs_streak = 0,
    left_streak = 0,
    right_streak = 0,
    had_input = false,
    bounce_streak = 0,
    -- #105: armed by feed_insert('<Esc>'); watches the normal-mode keystroke
    -- stream (via feed_after_escape) for the <Esc> -> {one command} -> i/a/A/I
    -- round trip that insert-mode <C-o> replaces.
    watching_co = false,
    post_esc_keys = 0,
  }
end

local function reset_streaks(iseq)
  iseq.bs_streak = 0
  iseq.left_streak = 0
  iseq.right_streak = 0
end

function M.feed_insert(iseq, canonical)
  if canonical == '<Esc>' then
    local fired = nil
    if iseq.had_input then
      iseq.bounce_streak = 0
    else
      iseq.bounce_streak = iseq.bounce_streak + 1
      if iseq.bounce_streak >= 2 then
        iseq.bounce_streak = 0
        fired = { pattern = 'insert_bounce', cmd = 'A' }
      end
    end
    iseq.had_input = false
    reset_streaks(iseq)
    -- #105: every exit from insert mode (re-)arms the one-shot watch fresh,
    -- overwriting whatever state a previous, never-resolved arm left behind
    -- (e.g. a normal-mode command that auto-entered insert without ever
    -- passing through feed_after_escape's return-key check — see the
    -- decision log for why this can't go stale).
    iseq.watching_co = true
    iseq.post_esc_keys = 0
    return fired
  end

  -- Any other key means this insert session is no longer "empty" — it
  -- cannot end in an insert_bounce even if <Esc> comes next.
  iseq.had_input = true

  if canonical == '<BS>' then
    iseq.left_streak = 0
    iseq.right_streak = 0
    iseq.bs_streak = iseq.bs_streak + 1
    if iseq.bs_streak == 5 then
      iseq.bs_streak = 0
      return { pattern = 'insert_bs_repeat', cmd = '<C-w>' }
    end
    return nil
  end

  if canonical == '<Left>' then
    iseq.bs_streak = 0
    iseq.right_streak = 0
    iseq.left_streak = iseq.left_streak + 1
    if iseq.left_streak == 5 then
      iseq.left_streak = 0
      return { pattern = 'insert_left_repeat', cmd = 'b' }
    end
    return nil
  end

  if canonical == '<Right>' then
    iseq.bs_streak = 0
    iseq.left_streak = 0
    iseq.right_streak = iseq.right_streak + 1
    if iseq.right_streak == 5 then
      iseq.right_streak = 0
      return { pattern = 'insert_right_repeat', cmd = 'w' }
    end
    return nil
  end

  -- Ordinary typed character: breaks any in-progress streak.
  reset_streaks(iseq)
  return nil
end

-- #105: called by logger.lua for every NORMAL-mode keystroke — not just while
-- iseq is "in insert mode" — for as long as iseq.watching_co stays armed
-- (i.e. since the most recent <Esc> out of insert). This is necessary
-- because the detection target spans the mode boundary: <Esc> exits insert,
-- then some number of ordinary normal-mode commands run, then i/a/A/I
-- re-enters insert. Only the <Esc> and the final return-key live inside an
-- insert-mode-adjacent keystroke; everything in between is genuinely
-- normal-mode input that patterns.lua already processes independently. This
-- function only ever mutates iseq's watching_co/post_esc_keys fields, never
-- patterns.lua's seq, and returns nil immediately (cheap) whenever the watch
-- isn't armed — see lua/tobira/CLAUDE.md's "vim.on_key() performance" note.
--
-- "One command" is defined structurally (exactly one raw keystroke before
-- the return-to-insert key), not temporally. patterns_insert.lua has zero
-- vim.* dependencies (see file header) so there is no clock available to
-- measure a literal "a few hundred ms" window against, and a keystroke count
-- is an equivalent, simpler proxy for the same intent — a genuine one-shot
-- vs. a multi-step detour — without adding a timing dependency this file
-- would otherwise never need. Known, accepted limitation: this also means a
-- single *compound* normal command (e.g. `dd`, `dw`, `ciw` — several raw
-- keystrokes for one conceptual edit) is not recognised as "one command"
-- here; replicating patterns.lua's operator-grammar tracking to fix that
-- would duplicate significant complexity for comparatively little value, so
-- this deliberately only catches single-keystroke round trips (j, k, x, p,
-- ~, ., u, and similar).
function M.feed_after_escape(iseq, key)
  if not iseq.watching_co then
    return nil
  end
  if key == 'i' or key == 'a' or key == 'A' or key == 'I' then
    local fired = nil
    if iseq.post_esc_keys == 1 then
      fired = { pattern = 'insert_co_oneshot', cmd = 'i_<C-o>' }
    end
    iseq.watching_co = false
    iseq.post_esc_keys = 0
    return fired
  end
  iseq.post_esc_keys = iseq.post_esc_keys + 1
  if iseq.post_esc_keys > 1 then
    -- 2+ commands: no longer a "one shot" — stop watching early so a long
    -- normal-mode detour unrelated to insert mode is never misread later.
    iseq.watching_co = false
  end
  return nil
end

return M
