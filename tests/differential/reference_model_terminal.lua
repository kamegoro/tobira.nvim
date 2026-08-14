-- A deliberately SIMPLE, independently-written reference model of what
-- terminal-mode <Esc> streak detection SHOULD do, derived directly from
-- docs/adr/0001-terminal-mode-escape-streak-detection.md rather than from
-- reading patterns_terminal.lua's own source.
--
-- patterns_terminal.lua has exactly one pattern (terminal_esc_repeat), and
-- its real implementation is already a 2-line threshold+latch check — there
-- is no web of pending-state branches for this model to independently
-- verify the way reference_model.lua does for patterns.lua's much larger
-- seq state machine (see issue #331's design guidance: a full
-- generator/reference-model apparatus is overkill here). What this model
-- DOES meaningfully double-check, by being independently written, is the
-- raw-byte-to-"is this actually <Esc>" decision itself — see ESC_BYTE below
-- and tests/differential/real_model_terminal.lua, which replays logger.lua's
-- own TERMINAL_SPECIAL translation table. If that translation table were
-- ever wrong (e.g. mapped some OTHER raw byte to '<Esc>', or failed to
-- recognize the real one), this model's independent byte comparison is what
-- would catch it — the existing tests/spec/unit/patterns_terminal_spec.lua
-- only ever calls feed_terminal() with an already-canonicalized string and
-- so cannot see that layer at all.

local M = {}

-- The literal ASCII/ANSI escape byte (0x1B) — a universal terminal fact, not
-- derived from logger.lua's or patterns_terminal.lua's own
-- nvim_replace_termcodes() call. Two independent routes to the same byte
-- value is what makes this model's "did the real dispatch see <Esc>?" check
-- meaningful rather than circular.
local ESC_BYTE = string.char(27)

-- 2, not 1 — see docs/adr/0001. Duplicated as a literal (not required from
-- patterns_terminal.lua) so a future accidental threshold change there has
-- an independent witness.
local ESC_THRESHOLD = 2

function M.new_state()
  return {
    esc_streak = 0,
    fired = false,
  }
end

-- raw_key: a single vim.on_key()-shaped raw key string (e.g. '\27' for
-- <Esc>, '\3' for <C-c>, a K_SPECIAL-prefixed multi-byte string for <Up> or
-- an <M-x>-style Meta chord, or an ordinary printable character).
--
-- Returns { pattern = 'terminal_esc_repeat', cmd = '<C-\\><C-n>' } or nil,
-- mirroring feed_terminal()'s own return shape.
function M.step(state, raw_key)
  if raw_key ~= ESC_BYTE then
    -- Any non-<Esc> key breaks the streak and re-arms detection — this
    -- includes the escape hatch itself (<C-\><C-n>), every ordinary shell
    -- control key, and any Meta/special-key raw sequence. See ADR above.
    state.esc_streak = 0
    state.fired = false
    return nil
  end

  state.esc_streak = state.esc_streak + 1
  if state.esc_streak >= ESC_THRESHOLD and not state.fired then
    state.fired = true
    return { pattern = 'terminal_esc_repeat', cmd = '<C-\\><C-n>' }
  end
  return nil
end

return M
