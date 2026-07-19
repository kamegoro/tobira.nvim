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

local M = {}

function M.new_insert_seq()
  return {
    bs_streak = 0,
    left_streak = 0,
    right_streak = 0,
    had_input = false,
    bounce_streak = 0,
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

return M
