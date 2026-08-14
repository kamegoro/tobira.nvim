-- Thin wrapper around the REAL patterns_cmdline.lua that replays exactly the
-- calls, order, and guards logger.lua's handle_cmdline_key() performs at
-- <CR> time (substitute -> pingpong -> tabnew -> history_recall), so the
-- differential spec compares against the real dispatch outcome, not just one
-- detector function in isolation.
--
-- Deliberately NOT a re-require of logger.lua itself: logger.lua also reads
-- vim.fn.getcmdline/getcmdtype/vim.schedule/nvim_buf_get_changedtick/
-- nvim_tabpage_list_wins, none of which this pure state-machine differential
-- test needs (no headless-Neovim requirement, no vim.schedule() deferral).
-- Every deferred verify-before-credit check
-- (docs/adr/0015-ex-command-verify-before-credit.md — the changedtick
-- comparison for :s, the vim.fn.expand('%:p') comparison for :e/:b) is
-- assumed to always succeed here: this differential test's scope is the pure
-- state machine four detectors implement, not the vim.schedule/changedtick
-- timing plumbing around them, mirroring how
-- tests/differential/real_model.lua doesn't model logger.lua's I/O either.
--
-- Unlike reference_model_cmdline.lua (which ROUTES an event straight to its
-- one eligible family based on event.kind), this wrapper independently
-- re-derives word/arg/name from the event's RENDERED TEXT via the REAL
-- tokenize()/command_arg(), then tries EACH of the four detectors under its
-- own real guard — exactly like logger.lua does. This is what lets the
-- differential spec's mutual-exclusivity check catch a genuine dispatch bug
-- (two guards both letting a detector run) rather than just asserting
-- something the wrapper's own routing already assumed.

local patterns_cmdline = require('tobira.core.patterns_cmdline')

local M = {}

-- Duplicated from logger.lua's own PINGPONG_WORDS (itself duplicated from
-- patterns_cmdline.lua's private PINGPONG_COMMANDS) rather than exported —
-- see docs/adr/0015-ex-command-verify-before-credit.md for why logger.lua
-- keeps its own copy instead of reaching into the module's internals.
local PINGPONG_WORDS = { e = true, b = true }

function M.new_state()
  return {
    substitute_state = patterns_cmdline.new_substitute_state(),
    pingpong_seq = patterns_cmdline.new_pingpong_seq(),
    tabnew_seq = patterns_cmdline.new_tabnew_seq(),
    history_state = patterns_cmdline.new_history_recall_state(),
    recalled_via_history = false,
  }
end

function M.press_history_key(state)
  state.recalled_via_history = true
end

function M.cancel_session(state)
  state.recalled_via_history = false
end

-- Feeds one full submitted (<CR>) command line's rendered TEXT through the
-- real tokenize()/command_arg() and all four real detectors, in logger.lua's
-- own order.
--
-- opts.line: vim.fn.line('.') stand-in, for track_substitute().
-- opts.win_count: nvim_tabpage_list_wins() stand-in, for feed_tabnew().
--
-- Returns { fires = { {pattern=, cmd=, source=}, ... }, name=, word=, arg= }.
-- `fires` is a LIST, not a single winner — the differential spec asserts
-- #fires <= 1 itself (docs/adr/0095's mutual-exclusivity-by-construction
-- claim) rather than this wrapper silently picking one, so a real violation
-- of that claim is visible instead of masked.
function M.submit(state, text, opts)
  opts = opts or {}
  local recalled = state.recalled_via_history
  state.recalled_via_history = false -- session over, one way or another

  local name = patterns_cmdline.tokenize(text)
  local word, arg = patterns_cmdline.command_arg(text)
  local fires = {}

  -- Cheap gate mirroring logger.lua's own looks_like_substitute() duplicate
  -- (docs/adr/0015) — track_substitute() re-checks the same word itself, so
  -- this pre-check is an optimization, not a correctness dependency.
  local sub_word = name and name:match('^ex:(%a+)$')
  local looks_like_substitute = sub_word ~= nil and ('substitute'):sub(1, #sub_word) == sub_word
  if looks_like_substitute then
    local line = opts.line or 1
    local sub_result = patterns_cmdline.track_substitute(state.substitute_state, text, line)
    if sub_result then
      table.insert(fires, { pattern = sub_result.pattern, cmd = sub_result.cmd, source = 'substitute' })
    end
  end

  if PINGPONG_WORDS[word] and arg then
    local pingpong_result = patterns_cmdline.feed_pingpong(state.pingpong_seq, word, arg)
    if pingpong_result then
      table.insert(fires, { pattern = pingpong_result.pattern, cmd = pingpong_result.cmd, source = 'pingpong' })
    end
  end

  if name == 'ex:tabnew' then
    local win_count = opts.win_count or 1
    local result = patterns_cmdline.feed_tabnew(state.tabnew_seq, arg or '', win_count)
    if result then
      table.insert(fires, { pattern = result.pattern, cmd = result.cmd, source = 'tabnew' })
    end
  end

  if name then
    local recall_result = patterns_cmdline.feed_history_recall(state.history_state, text, word, arg, recalled)
    if recall_result then
      table.insert(fires, { pattern = recall_result.pattern, cmd = recall_result.cmd, source = 'history' })
    end
  end

  return { fires = fires, name = name, word = word, arg = arg }
end

return M
