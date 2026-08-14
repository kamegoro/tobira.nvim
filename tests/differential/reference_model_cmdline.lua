-- A deliberately SIMPLE, obviously-correct reference model of what
-- patterns_cmdline.lua's four independent cmdline detectors SHOULD do:
-- substitute_repeat/substitute_repeat_wide, ex_file_pingpong, tabnew_run, and
-- cmdline_history_recall.
--
-- This is NOT a reimplementation of patterns_cmdline.lua's own tokenize()/
-- command_arg() text parsing (strip_range, delimiter-escape scanning, ...).
-- It shares no code with that module. Instead it consumes the SAME
-- structured "submission" events tests/differential/generator_cmdline.lua
-- produces (word/arg/pattern/replacement/etc. as explicit fields, not text
-- to be parsed) and independently re-derives each detector's own
-- count/threshold/latch logic from those fields — see
-- tests/differential/real_model_cmdline.lua for the counterpart that drives
-- the REAL module by actually parsing the rendered text, which is what lets
-- the differential spec catch a genuine tokenizer/dispatch divergence, not
-- just a threshold-logic one.
--
-- The central claim under test (docs/adr/0095-cmdline-history-recall-detection.md,
-- "mutually exclusive by construction: for any given submitted command
-- line, at most one of the four cmdline detectors can ever return
-- non-nil") is modeled here as ROUTING, not as four independently-tried
-- detectors: M.submit() dispatches each event to exactly one family based on
-- event.kind, mirroring the real word-based exclusion design rather than
-- re-deriving it from scratch. The differential spec's OWN direct check
-- against the REAL functions (which really are four separate guarded calls,
-- not a router) is what actually verifies the construction holds — this
-- model's routing is the "should be true" reference, not proof by itself.
--
-- recalled_via_history (#259) is modeled as one boolean field on `state`,
-- set by M.press_history_key() and cleared by M.submit()/M.cancel_session()
-- — mirroring logger.lua's `cmdline_recalled_via_history`, scoped to one
-- open-to-close cmdline session (see docs/adr/0095's "State shape" section).

local M = {}

function M.new_state()
  return {
    substitute = { entries = {} }, -- (pattern..'\0'..replacement) -> { lines = {}, count }
    pingpong = { first = nil, second = nil, fired = false },
    tabnew = { streak = 0, files = {} },
    history = { entries = {} }, -- trimmed full text -> { count, fired }
    recalled_via_history = false,
  }
end

-- <Up>/<Down> pressed while a ':' cmdline session is open — see header.
function M.press_history_key(state)
  state.recalled_via_history = true
end

-- <Esc>/<C-c> aborted the session without submitting — the flag must not
-- carry into the next session, same as logger.lua's CMDLINE_ESC/CTRL_C branch.
function M.cancel_session(state)
  state.recalled_via_history = false
end

-- event.kind == 'sub': { pattern=, replacement=, ranged=(bool), line=(int) }
local function submit_sub(state, event)
  if event.ranged or event.pattern == '' then
    return nil -- out of scope for substitute_repeat -- see docs/adr/0006
  end
  local key = event.pattern .. '\0' .. event.replacement
  local entry = state.substitute.entries[key]
  if not entry then
    entry = { lines = {}, count = 0 }
    state.substitute.entries[key] = entry
  end
  if entry.lines[event.line] then
    return nil -- same line re-run -- not a new distinct line
  end
  entry.lines[event.line] = true
  entry.count = entry.count + 1
  if entry.count == 2 then
    return { pattern = 'substitute_repeat', cmd = '&' }
  elseif entry.count == 3 then
    return { pattern = 'substitute_repeat_wide', cmd = 'g&' }
  end
  return nil
end

-- event.kind == 'ex_file': { word='e'|'b', arg=(string or nil) }
local function submit_ex_file(state, event)
  if not event.arg then
    return nil -- no filename signal -- see docs/adr/0004
  end
  local pp = state.pingpong
  if event.arg == pp.second then
    return nil -- reopening the current file isn't a new switch
  end
  local is_return = event.arg == pp.first and pp.second ~= nil
  local should_fire = is_return and not pp.fired
  pp.first = pp.second
  pp.second = event.arg
  pp.fired = is_return
  if should_fire then
    return { pattern = 'ex_file_pingpong', cmd = '<C-^>' }
  end
  return nil
end

-- event.kind == 'tabnew': { arg=(string, '' for bare), win_count=(int) }
local TABNEW_STREAK_THRESHOLD = 3
local function submit_tabnew(state, event)
  local tn = state.tabnew
  if event.arg == '' then
    tn.streak = 0
    tn.files = {}
    return nil
  end
  if tn.files[event.arg] then
    tn.streak = 0
    tn.files = {}
    return nil
  end
  if tn.streak > 0 and event.win_count ~= 1 then
    tn.streak = 0
    tn.files = {}
  end
  tn.streak = tn.streak + 1
  tn.files[event.arg] = true
  if tn.streak >= TABNEW_STREAK_THRESHOLD then
    tn.streak = 0
    tn.files = {}
    return { pattern = 'tabnew_run', cmd = '<C-^>' }
  end
  return nil
end

-- event.kind == 'other': { text=, word=(string or nil), arg=(string or nil) }
-- Covers everything NOT claimed by the three families above: trivial/bare Ex
-- commands (#241), symbolic commands (word == nil), and command
-- abbreviations the specific detectors don't recognize (:edit, :buffer).
local function submit_other(state, event, recalled)
  if recalled then
    return nil -- genuine recall, not retyping -- entire submission skipped
  end
  if event.word and not event.arg then
    return nil -- bare command word, nothing worth recalling
  end
  local trimmed = event.text:match('^%s*(.-)%s*$')
  if trimmed == '' then
    return nil
  end
  local entry = state.history.entries[trimmed]
  if not entry then
    entry = { count = 0, fired = false }
    state.history.entries[trimmed] = entry
  end
  entry.count = entry.count + 1
  if entry.count == 2 and not entry.fired then
    entry.fired = true
    return { pattern = 'cmdline_history_recall', cmd = 'q:' }
  end
  return nil
end

-- Feeds one full submitted (<CR>) command line. `event.kind` selects which
-- of the four families is even eligible to fire — the word-based exclusion
-- ADR 0095 documents, modeled here as routing (see header). Returns
-- { pattern=, cmd= } or nil.
function M.submit(state, event)
  local recalled = state.recalled_via_history
  state.recalled_via_history = false -- session over, one way or another

  if event.kind == 'sub' then
    return submit_sub(state, event)
  elseif event.kind == 'ex_file' then
    return submit_ex_file(state, event)
  elseif event.kind == 'tabnew' then
    return submit_tabnew(state, event)
  else
    return submit_other(state, event, recalled)
  end
end

M.TRACKED_PATTERNS = {
  substitute_repeat = true,
  substitute_repeat_wide = true,
  ex_file_pingpong = true,
  tabnew_run = true,
  cmdline_history_recall = true,
}

return M
