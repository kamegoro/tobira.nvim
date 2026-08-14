-- Thin wrapper around the REAL patterns.lua that replays exactly the same
-- per-keystroke calls and priority arbitration logger.lua's Normal-mode
-- handle_key() performs (patterns.feed() + patterns.feed_macro(), with
-- macro_result taking priority over result — see
-- docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md), so the
-- differential spec compares against the real dispatch outcome, not just
-- patterns.feed() in isolation.
--
-- Deliberately NOT a re-require of logger.lua itself: logger.lua also reads
-- vim.fn.stdpath/vim.on_key/vim.loop.now/etc. and persists usage.json, none
-- of which this pure state-machine differential test needs or wants (no
-- headless-Neovim requirement, no disk I/O, no session/buffer bookkeeping —
-- see reference_model.lua's header for why buffer-global `seq` state, #309,
-- is out of this test's scope). is_diff/is_wrapped are always passed as
-- false — this test's scope (issue #316) is the streak-family patterns
-- listed in reference_model.lua, none of which need those two parameters to
-- differ from their default.
--
-- named_mark_opportunity (the one pattern with its own narrower priority
-- exception over macro_result, #280) is not one of the 10 patterns tracked
-- here, so that exception can never engage for any keystroke this test
-- feeds — the plain "macro_result > result" priority is complete and
-- correct for this test's scope.

local patterns = require('tobira.core.patterns')

local M = {}

function M.new_state()
  return {
    seq = patterns.new_seq(),
    now = 0,
  }
end

-- Advances the fake clock by a plausible inter-keystroke gap so
-- feed_macro()'s MACRO_WINDOW_MS/nav_run bookkeeping behaves the way it
-- would for an actual typing session, rather than every keystroke landing on
-- the same millisecond. Also keeps patterns.lua's own jumplist/changelist
-- 15s tolerance window (docs/adr/0019, unrelated to this test's 10 tracked
-- patterns but fed the same clock) from spanning an entire generated
-- sequence — a value close to real human inter-keystroke timing keeps that
-- window's width proportionate to realistic usage instead of swallowing
-- hundreds of keys at once.
local STEP_MS = 300

-- Returns { pattern=, cmd= } or nil, mirroring patterns.feed()'s own return
-- shape — exactly what the real Normal-mode dispatch would report to
-- on_pattern for this keystroke.
function M.step(state, key)
  state.now = state.now + STEP_MS
  local line = 1 -- no cursor-line-dependent pattern is in this test's scope
  local result = patterns.feed(state.seq, key, line, false, state.now, false)
  local macro_result = patterns.feed_macro(state.seq, key, state.now)
  return macro_result or result
end

return M
