-- Thin wrapper around the REAL patterns_terminal.lua that replays exactly
-- the same raw-byte-to-canonical translation logger.lua's handle_terminal_key()
-- performs before calling feed_terminal() — see logger.lua's TERMINAL_SPECIAL
-- table and handle_terminal_key().
--
-- Deliberately NOT a re-require of logger.lua itself: logger.lua also reads
-- vim.fn.reg_executing/current_mode/etc. and persists usage.json, none of
-- which this pure dispatch-layer differential test needs (see real_model.lua's
-- own header for the same reasoning, applied here to the terminal-mode
-- module). The one piece of logger.lua behavior this DOES replicate on
-- purpose is the vim.api.nvim_replace_termcodes()-built TERMINAL_SPECIAL
-- map, because that translation (raw on_key bytes -> the canonical '<Esc>'
-- string patterns_terminal.lua actually keys off) is real dispatch logic
-- that tests/spec/unit/patterns_terminal_spec.lua never exercises (it always
-- calls feed_terminal() with an already-canonical string or nil).

local patterns_terminal = require('tobira.core.patterns_terminal')

local M = {}

local TERMINAL_SPECIAL = {}
do
  local raw = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
  if raw ~= '' then
    TERMINAL_SPECIAL[raw] = '<Esc>'
  end
end

function M.new_state()
  return {
    tseq = patterns_terminal.new_terminal_seq(),
  }
end

-- raw_key: a single vim.on_key()-shaped raw key string — see
-- reference_model_terminal.lua's M.step doc comment for the shapes this
-- takes.
--
-- Returns whatever feed_terminal() returns, exactly as logger.lua's
-- handle_terminal_key() would report to on_pattern for this keystroke.
function M.step(state, raw_key)
  local canonical = TERMINAL_SPECIAL[raw_key]
  return patterns_terminal.feed_terminal(state.tseq, canonical)
end

return M
