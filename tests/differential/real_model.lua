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
-- is out of this test's scope).
--
-- Extended by issue #328 (was: always is_diff=false/is_wrapped=false/line=1,
-- scoped to #316's original 10 streak patterns) to thread ctx.line/is_diff/
-- is_wrapped through to patterns.feed(), since the expanded pattern surface
-- now includes patterns gated on all three (named_mark_opportunity/f_repeat
-- on line, diff_jump_then_insert_*/j_many_diff/k_many_diff on is_diff,
-- j_repeat_wrapped/k_repeat_wrapped on is_wrapped).
--
-- Also implements the ONE narrow exception to "macro_result > result"
-- documented in ADR 0016 and shipped for #280: named_mark_opportunity wins
-- over macro_result specifically (every other pattern pair keeps the
-- unqualified macro_result > result priority). #316/#323 scoped this out
-- because named_mark_opportunity wasn't tracked yet; #328 tracks it, so this
-- wrapper now mirrors logger.lua's real arbitration exactly instead of the
-- simpler "macro_result or result" it used to be.

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
-- 15s tolerance window (docs/adr/0019) from spanning an entire generated
-- sequence — a value close to real human inter-keystroke timing keeps that
-- window's width proportionate to realistic usage instead of swallowing
-- hundreds of keys at once.
local STEP_MS = 300

-- ctx (optional): { line=, is_diff=, is_wrapped= }. line defaults to 1
-- (matches reference_model.lua's own default) so callers that don't care
-- about line-dependent patterns (f_repeat, named_mark_opportunity) don't
-- need to pass it.
--
-- Returns { pattern=, cmd= } or nil, mirroring patterns.feed()'s own return
-- shape — exactly what the real Normal-mode dispatch would report to
-- on_pattern for this keystroke.
function M.step(state, key, ctx)
  ctx = ctx or {}
  local line = ctx.line or 1
  state.now = state.now + STEP_MS
  local result = patterns.feed(state.seq, key, line, ctx.is_diff, state.now, ctx.is_wrapped)
  local macro_result = patterns.feed_macro(state.seq, key, state.now)

  -- Priority: macro_result > result, EXCEPT named_mark_opportunity wins over
  -- macro_result specifically — see this file's header (#280 / ADR 0016).
  local named_mark_collision = macro_result and result and result.pattern == 'named_mark_opportunity'
  return (named_mark_collision and result) or macro_result or result
end

return M
