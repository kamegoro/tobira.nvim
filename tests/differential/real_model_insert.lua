-- Thin wrapper around the REAL patterns_insert.lua (plus the real
-- patterns.lua it shares no state with, but whose feed_macro()/feed() this
-- module's own dispatch is threaded through by logger.lua) that replays
-- exactly the same per-keystroke calls and priority arbitration
-- logger.lua's handle_insert_key()/handle_key() perform, so the
-- differential spec compares against the real end-to-end dispatch outcome,
-- not patterns_insert.feed_insert() in isolation.
--
-- Deliberately NOT a re-require of logger.lua itself — same reasoning as
-- real_model.lua's own header: no headless-Neovim requirement, no disk I/O,
-- no vim.* dependency.
--
-- Two entry points, matching the two places logger.lua feeds
-- patterns_insert.lua's state (see docs/adr/0037):
--
--   step_insert(state, canonical, char) — one INSERT-mode keystroke.
--     logger.lua's handle_insert_key() computes:
--       result       = patterns_insert.feed_insert(insert_seq, canonical, key)
--       macro_result = patterns.feed_macro(seq, canonical or key, now)
--       fired        = macro_result or result
--     Both patterns_insert.feed_insert AND patterns.feed_macro are real,
--     unmodified requires — this is the actual collision surface issue
--     #327's umbrella flags: an insert-mode keystroke stream feeds the SAME
--     macro_buf a Normal-mode "dd dd dd" edit-repeat would, and typed
--     characters that happen to collide with MACRO_EDIT_KEYS (i, a, o, s,
--     x, d, c, y — patterns.lua's insert-mode-entry keys doing double duty
--     as ordinary letters) can make an insert-mode-only sequence anchor-match
--     macro_opportunity/visual_block_opportunity for reasons that have
--     nothing to do with "the user is repeating an edit".
--
--   step_normal_watch(state, key) — one NORMAL-mode keystroke while the
--     <C-o> one-shot watch is armed. logger.lua's handle_key() (Normal-mode
--     branch) computes:
--       co_result    = patterns_insert.feed_after_escape(insert_seq, key)
--       result       = patterns.feed(seq, key, line, is_diff, now, is_wrapped)
--       macro_result = patterns.feed_macro(seq, key, now)
--       named_mark_collision = macro_result and result
--         and result.pattern == 'named_mark_opportunity'
--       fired = (named_mark_collision and result) or macro_result or result
--         or co_result
--     is_diff/is_wrapped are always passed as false here — same rationale
--     as real_model.lua: no pattern this test cares about needs them to
--     differ from their default, and line is always 1 (no cursor-line-
--     dependent pattern is in scope for either differential suite).

local patterns = require('tobira.core.patterns')
local patterns_insert = require('tobira.core.patterns_insert')

local M = {}

function M.new_state()
  return {
    seq = patterns.new_seq(),
    insert_seq = patterns_insert.new_insert_seq(),
    now = 0,
  }
end

-- Advances the fake clock by a plausible inter-keystroke gap, same
-- rationale as real_model.lua's own STEP_MS: keeps patterns.lua's
-- MACRO_WINDOW_MS/jumplist-tolerance windows proportionate to realistic
-- typing speed instead of every keystroke landing on the same millisecond.
local STEP_MS = 150

function M.step_insert(state, canonical, char)
  state.now = state.now + STEP_MS
  local result = patterns_insert.feed_insert(state.insert_seq, canonical, char)
  local macro_result = patterns.feed_macro(state.seq, canonical or char, state.now)
  return macro_result or result
end

function M.step_normal_watch(state, key)
  state.now = state.now + STEP_MS
  local co_result = patterns_insert.feed_after_escape(state.insert_seq, key)
  local result = patterns.feed(state.seq, key, 1, false, state.now, false)
  local macro_result = patterns.feed_macro(state.seq, key, state.now)
  local named_mark_collision = macro_result and result and result.pattern == 'named_mark_opportunity'
  return (named_mark_collision and result) or macro_result or result or co_result
end

return M
