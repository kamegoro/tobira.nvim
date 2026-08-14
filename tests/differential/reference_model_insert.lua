-- A deliberately SIMPLE, obviously-correct reference model of what
-- patterns_insert.lua's insert-mode state machine SHOULD do.
--
-- This is a parallel, independent apparatus to reference_model.lua (the
-- patterns.lua/seq differential suite) — NOT a shared one. See
-- lua/tobira/CLAUDE.md's "Module splitting policy": patterns_insert.lua
-- shares no state with patterns.lua's seq, so this model shares no state
-- (and no file) with reference_model.lua either.
--
-- Patterns modeled (all 6 that patterns_insert.lua can fire — see issue
-- #329): insert_bs_repeat, insert_left_repeat, insert_right_repeat,
-- insert_bounce, insert_co_oneshot, insert_completion_repeat.
--
-- Unlike patterns.lua's inner_feed (a genuinely intricate shared-pending-
-- state dispatcher), patterns_insert.lua's own logic is already small and
-- direct — see its own header comment. So the interesting differential
-- surface here isn't "does a complex algorithm match a simple one" so much
-- as "does the REAL end-to-end dispatch (which also feeds every insert-mode
-- keystroke through patterns.feed_macro(), and feeds every post-<Esc>
-- Normal-mode keystroke through patterns.feed() + patterns.feed_macro() too
-- — see logger.lua's handle_insert_key/handle_key) silently let some OTHER
-- pattern's dispatch priority swallow one of these 6 patterns". This model
-- has no opinion about macro_opportunity/visual_block_opportunity or any
-- patterns.lua pattern — it only tracks what patterns_insert.lua's own
-- per-pattern rules say SHOULD happen, in isolation. The differential spec
-- is what compares this against the real, full-priority dispatch outcome.
--
-- Token-reconstruction rules (insert_completion_repeat) mirror
-- docs/adr/0039 exactly, since that ADR IS the spec for what "correct"
-- means here, not an implementation detail to second-guess:
--   - word chars (%w_) accumulate; anything else (or <Esc>) closes a token
--   - tokens shorter than the threshold are discarded, never enter the ring
--   - <Left>/<Right> ABANDON the in-progress token (reset to '')
--   - <BS> TRUNCATES the in-progress token (drops its last character)

local M = {}

local TOKEN_LEN_THRESHOLD = 6
local RING_SIZE = 8

local function is_word_char(c)
  return type(c) == 'string' and c:match('^[%w_]$') ~= nil
end

function M.new_state()
  return {
    bs = 0,
    left = 0,
    right = 0,
    had_input = false,
    bounce = 0,
    token = '',
    ring = {},
    watching = false,
    post_esc = 0,
  }
end

-- Closes the in-progress token against the ring buffer, then records it
-- (evicting the oldest once full). Always runs, even for a too-short token
-- (which is simply never recorded) — see docs/adr/0039.
local function close_token(state)
  local tok = state.token
  state.token = ''
  if #tok < TOKEN_LEN_THRESHOLD then
    return nil
  end

  local matched = false
  for _, seen in ipairs(state.ring) do
    if seen == tok then
      matched = true
      break
    end
  end

  table.insert(state.ring, tok)
  while #state.ring > RING_SIZE do
    table.remove(state.ring, 1)
  end

  if matched then
    return { pattern = 'insert_completion_repeat', cmd = '<C-n>' }
  end
  return nil
end

-- One INSERT-mode keystroke, mirroring what logger.lua's handle_insert_key
-- passes to patterns_insert.feed_insert: canonical is one of '<BS>',
-- '<Left>', '<Right>', '<Esc>', or nil for an ordinary character (in which
-- case char is that character).
function M.step_insert(state, canonical, char)
  if canonical == '<Esc>' then
    local bounce_fired = nil
    if state.had_input then
      state.bounce = 0
    else
      state.bounce = state.bounce + 1
      if state.bounce >= 2 then
        state.bounce = 0
        bounce_fired = { pattern = 'insert_bounce', cmd = 'A' }
      end
    end
    state.had_input = false
    state.bs, state.left, state.right = 0, 0, 0
    -- Re-arms the <C-o> one-shot watch unconditionally on every exit from
    -- insert mode — see docs/adr/0037.
    state.watching = true
    state.post_esc = 0
    -- bounce_fired and the token-close result are disjoint: a bounce means
    -- nothing was typed this session, so token is already ''.
    return bounce_fired or close_token(state)
  end

  -- Any other key means this insert session is no longer empty.
  state.had_input = true

  if canonical == '<BS>' then
    state.left, state.right = 0, 0
    state.bs = state.bs + 1
    state.token = state.token:sub(1, -2) -- truncate: append-only assumption still holds
    if state.bs == 5 then
      state.bs = 0
      return { pattern = 'insert_bs_repeat', cmd = '<C-w>' }
    end
    return nil
  end

  if canonical == '<Left>' then
    state.bs, state.right = 0, 0
    state.left = state.left + 1
    state.token = '' -- abandon: cursor moved off the end
    if state.left == 5 then
      state.left = 0
      return { pattern = 'insert_left_repeat', cmd = 'b' }
    end
    return nil
  end

  if canonical == '<Right>' then
    state.bs, state.left = 0, 0
    state.right = state.right + 1
    state.token = '' -- abandon: cursor moved off the end
    if state.right == 5 then
      state.right = 0
      return { pattern = 'insert_right_repeat', cmd = 'w' }
    end
    return nil
  end

  -- Ordinary typed character: breaks any BS/Left/Right streak.
  state.bs, state.left, state.right = 0, 0, 0
  if is_word_char(char) then
    state.token = state.token .. char
    return nil
  end
  return close_token(state)
end

-- One NORMAL-mode keystroke while the <C-o> one-shot watch is armed —
-- mirrors patterns_insert.feed_after_escape exactly (this IS the whole
-- spec per docs/adr/0037: "one command" is a raw keystroke count, not a
-- timing window). Independent of step_insert's state fields other than
-- watching/post_esc.
function M.step_normal_watch(state, key)
  if not state.watching then
    return nil
  end
  if key == 'i' or key == 'a' or key == 'A' or key == 'I' then
    local fired = nil
    if state.post_esc == 1 then
      fired = { pattern = 'insert_co_oneshot', cmd = 'i_<C-o>' }
    end
    state.watching = false
    state.post_esc = 0
    return fired
  end
  state.post_esc = state.post_esc + 1
  if state.post_esc > 1 then
    state.watching = false
  end
  return nil
end

-- The exact set of pattern names this model has an opinion about — used by
-- the differential spec to tell "a real pattern outside this module's own
-- 6" (e.g. macro_opportunity) apart from "one of our own 6, just wrong".
M.TRACKED_PATTERNS = {
  insert_bs_repeat = true,
  insert_left_repeat = true,
  insert_right_repeat = true,
  insert_bounce = true,
  insert_co_oneshot = true,
  insert_completion_repeat = true,
}

return M
