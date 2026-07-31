-- Pure terminal-mode key-streak detection: fires once when the user hits
-- <Esc> twice in a row with nothing else in between while in terminal-job
-- mode. No vim.* calls.
--
-- see docs/adr/0001-terminal-mode-escape-streak-detection.md for why this
-- module is separate from patterns.lua/patterns_insert.lua, why the
-- threshold is 2 not 1, why detection latches until the streak breaks, and
-- why a repeated-<C-w> trigger was deliberately not added.
--
-- logger.lua only calls feed_terminal() while its mode cache says
-- mode() == 't', passing the canonical key name '<Esc>' for the one key
-- this cares about, or nil for anything else.

local M = {}

function M.new_terminal_seq()
  return {
    esc_streak = 0,
    fired = false,
  }
end

-- 2, not 1 — a lone <Esc> is ordinary terminal-job behavior; see ADR above.
local ESC_THRESHOLD = 2

function M.feed_terminal(tseq, canonical)
  if canonical ~= '<Esc>' then
    -- Any other key breaks the streak and re-arms detection (see ADR above).
    tseq.esc_streak = 0
    tseq.fired = false
    return nil
  end

  tseq.esc_streak = tseq.esc_streak + 1
  if tseq.esc_streak >= ESC_THRESHOLD and not tseq.fired then
    tseq.fired = true
    return { pattern = 'terminal_esc_repeat', cmd = '<C-\\><C-n>' }
  end
  return nil
end

return M
