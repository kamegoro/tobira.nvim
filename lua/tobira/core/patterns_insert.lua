-- Pure insert-mode key-streak detection. No vim.* calls.
--
-- A separate, much simpler state machine from patterns.lua's seq/feed — see
-- lua/tobira/CLAUDE.md's "Module splitting policy" for why insert-mode
-- detection lives in its own file.
--
-- logger.lua only calls feed_insert() while its mode cache says the user is
-- in insert mode, passing a canonical key name ('<BS>', '<Left>', '<Right>',
-- '<Esc>') for the keys this cares about, or nil for any other ordinary
-- typed character. It also calls feed_after_escape() for every NORMAL-mode
-- keystroke while the <C-o> one-shot watch (below) is armed.
--
-- see docs/adr/0038-insert-bounce-detection-lives-in-patterns-insert.md for
-- why bounce detection lives here rather than as mode-transition bookkeeping
-- in logger.lua.
-- see docs/adr/0037-insert-co-oneshot-crosses-mode-boundary.md for why
-- feed_after_escape's state lives here but is fed from logger.lua's
-- NORMAL-mode branch.
-- see docs/adr/0039-insert-completion-repeat-token-reconstruction.md for the
-- completion-repeat design: token reconstruction, TOKEN_LEN_THRESHOLD,
-- RING_SIZE, and why <Left>/<Right> abandon the in-progress token while
-- <BS> truncates it.

local M = {}

local TOKEN_LEN_THRESHOLD = 6
local RING_SIZE = 8

function M.new_insert_seq()
  return {
    bs_streak = 0,
    left_streak = 0,
    right_streak = 0,
    had_input = false,
    bounce_streak = 0,
    -- Armed by feed_insert('<Esc>'); consumed by feed_after_escape() — see
    -- docs/adr/0037-insert-co-oneshot-crosses-mode-boundary.md.
    watching_co = false,
    post_esc_keys = 0,
    -- In-progress completion token + ring-buffer history — see
    -- docs/adr/0039-insert-completion-repeat-token-reconstruction.md.
    token = '',
    ring = {},
  }
end

local function reset_streaks(iseq)
  iseq.bs_streak = 0
  iseq.left_streak = 0
  iseq.right_streak = 0
end

-- A "word" character continues the in-progress token; anything else (a
-- multi-byte UTF-8 sequence included — identifiers are assumed ASCII here)
-- is treated as a boundary.
local function is_word_char(char)
  return type(char) == 'string' and char:match('^[%w_]$') ~= nil
end

-- Closes the in-progress token: checks it against the ring buffer (firing
-- insert_completion_repeat on an exact match), then records it, evicting the
-- oldest entry once the buffer is full. See
-- docs/adr/0039-insert-completion-repeat-token-reconstruction.md for why
-- short tokens are discarded before ever entering the ring.
local function finalize_token(iseq)
  local tok = iseq.token
  iseq.token = ''
  if #tok < TOKEN_LEN_THRESHOLD then
    return nil
  end

  local fired = nil
  for _, seen in ipairs(iseq.ring) do
    if seen == tok then
      fired = { pattern = 'insert_completion_repeat', cmd = '<C-n>' }
      break
    end
  end

  table.insert(iseq.ring, tok)
  while #iseq.ring > RING_SIZE do
    table.remove(iseq.ring, 1)
  end

  return fired
end

function M.feed_insert(iseq, canonical, char)
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
    -- Re-arms the <C-o> one-shot watch on every exit, overwriting any
    -- unresolved previous arm — see
    -- docs/adr/0037-insert-co-oneshot-crosses-mode-boundary.md.
    iseq.watching_co = true
    iseq.post_esc_keys = 0
    -- bounce_streak and token are disjoint fields, and a bounce (nothing
    -- typed) always means iseq.token is already empty, so checking both and
    -- keeping whichever fired is always safe.
    fired = fired or finalize_token(iseq)
    return fired
  end

  -- Any other key means this insert session is no longer "empty" — it
  -- cannot end in an insert_bounce even if <Esc> comes next.
  iseq.had_input = true

  if canonical == '<BS>' then
    iseq.left_streak = 0
    iseq.right_streak = 0
    iseq.bs_streak = iseq.bs_streak + 1
    iseq.token = iseq.token:sub(1, -2)
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
    iseq.token = ''
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
    iseq.token = ''
    if iseq.right_streak == 5 then
      iseq.right_streak = 0
      return { pattern = 'insert_right_repeat', cmd = 'w' }
    end
    return nil
  end

  -- Ordinary typed character: breaks any in-progress streak.
  reset_streaks(iseq)
  if is_word_char(char) then
    iseq.token = iseq.token .. char
    return nil
  end
  return finalize_token(iseq)
end

-- Called by logger.lua for every NORMAL-mode keystroke while iseq.watching_co
-- stays armed (since the most recent <Esc> out of insert). Mutates only
-- watching_co/post_esc_keys, never patterns.lua's seq, and returns nil
-- immediately when the watch isn't armed (cheap — see
-- lua/tobira/CLAUDE.md's "vim.on_key() performance" note). See
-- docs/adr/0037-insert-co-oneshot-crosses-mode-boundary.md for why this
-- crosses the mode boundary, why "one command" is a keystroke count rather
-- than a timing window, and the known limitation on compound normal
-- commands (dd, dw, ciw).
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
