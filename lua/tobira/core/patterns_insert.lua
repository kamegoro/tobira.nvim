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
-- Completion-repeat detection (#112): logger.lua now also passes the raw
-- typed character as a third argument whenever canonical is nil (an ordinary
-- key). This reconstructs whole tokens purely from keystrokes — never from
-- buffer content, per the "on_key only" tracking principle in
-- lua/tobira/CLAUDE.md — by accumulating word characters and treating any
-- non-word character (whitespace, punctuation, newline) or <Esc> as a token
-- boundary. Completed tokens of at least TOKEN_LEN_THRESHOLD characters are
-- kept in a small ring buffer (RING_SIZE entries); typing the exact same
-- token again fires insert_completion_repeat, suggesting <C-n>.
--
-- TOKEN_LEN_THRESHOLD = 6: short words are typed repeatedly and legitimately
-- all the time ('const', 'class', 'value', 'break', 'while' are all 5
-- characters) — 6 clears every common short keyword while still catching the
-- identifiers/method names this pattern actually targets.
--
-- RING_SIZE = 8: large enough to span a typical line or two of real code (a
-- handful of tokens per line), small enough that memory stays bounded and old
-- tokens don't linger indefinitely. Since matches are always exact-string
-- repeats, a bigger buffer would only mean more (still valid) matches, not
-- more false positives — 8 is a deliberately modest starting point rather
-- than a value tuned against a specific failure.
--
-- <Left>/<Right> abandon (rather than finalize) the in-progress token: once
-- the cursor moves off the end of what's been typed, further characters may
-- land in the middle of the word rather than being appended, so the
-- accumulated string can no longer be trusted to match what's actually in the
-- buffer. Dropping it is a conservative false-negative, not a false-positive
-- risk. <BS> instead truncates the last accumulated character, since deleting
-- backward from the end keeps the append-only assumption valid.

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

-- Closes out the in-progress token: checks it against the ring buffer (firing
-- insert_completion_repeat on an exact match), then records it, evicting the
-- oldest entry once the buffer is full. Tokens under the length threshold are
-- discarded without ever entering the ring buffer, so short words can never
-- accumulate enough history to match later regardless of how often they
-- repeat.
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
    -- Bounce (nothing typed) and completion-repeat (a full token typed twice)
    -- are mutually exclusive, so it's always safe to check both and keep
    -- whichever actually fired.
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

return M
