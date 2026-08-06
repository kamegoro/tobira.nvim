local patterns = require('tobira.core.patterns')
local patterns_insert = require('tobira.core.patterns_insert')
local patterns_cmdline = require('tobira.core.patterns_cmdline')
local patterns_terminal = require('tobira.core.patterns_terminal')
local commands = require('tobira.commands')

local M = {}

local data_dir = vim.fn.stdpath('data') .. '/tobira'
local data_file = data_dir .. '/usage.json'

local usage = {}
local meta = { guide_seen = false }
local _initialized = false
local seq = patterns.new_seq()
-- Persists across separate :s invocations (unlike seq/insert_seq above, which
-- reset on every cmdline keystroke) -- repeated-substitute detection needs to
-- remember pattern+replacement pairs across invocations minutes apart.
local substitute_state = patterns_cmdline.new_substitute_state()
-- Persists across separate :tabnew submissions within a session (unlike
-- seq/insert_seq) -- not reset alongside them in handle_cmdline_key below.
local tabnew_seq = patterns_cmdline.new_tabnew_seq()
-- Persists across separate Ex-command submissions within a session (#241),
-- same lifetime as substitute_state/tabnew_seq above.
local history_recall_state = patterns_cmdline.new_history_recall_state()
local session_counts = {}
-- Snapshot of {count, shown, suppressed, pinned, celebrated} as of the last
-- disk sync. See docs/adr/0014-usage-json-concurrent-merge-and-migration.md
-- for why this exists and how merge_with_disk() uses it.
local _baseline = {}
-- Count of sessions[] entries appended locally since _baseline was last
-- synced. See docs/adr/0014-usage-json-concurrent-merge-and-migration.md.
local _sessions_appended = {}
-- Commands flushed early via mark_adopted() this session, so close_session()
-- does not also zero-pad or re-append them (see its zero-pad loop below).
local session_adopted = {}

-- Wired by init.lua — logger has no direct dependency on suggest.
M.on_pattern = nil

local current_mode = 'n'

-- vim.fn.mode()'s three Visual submodes (charwise/linewise/blockwise). Select
-- and Replace mode are deliberately excluded — see
-- docs/adr/0017-mode-cache-state-reset-boundaries.md for why.
local VISUAL_MODES = { v = true, V = true, ['\22'] = true }

local MAX_SESSIONS = 10

local function ensure_dir()
  vim.fn.mkdir(data_dir, 'p')
end

-- Migrate a single entry from the old format (adopted field) to the new format
-- (sessions array + suppressed). Returns the mutated entry.
local function migrate_entry(entry)
  if not entry.sessions then
    entry.sessions = entry.adopted == true and { 10 } or {}
  end
  if entry.suppressed == nil then
    entry.suppressed = false
  end
  if entry.pinned == nil then
    entry.pinned = false
  end
  if entry.celebrated == nil then
    entry.celebrated = false
  end
  entry.adopted = nil
  return entry
end

-- Default baseline shape for a command never before synced with disk —
-- mirrors the zero-value defaults used everywhere a fresh entry is created.
local function baseline_of(entry)
  entry = entry or {}
  return {
    count = entry.count or 0,
    shown = entry.shown or 0,
    suppressed = entry.suppressed == true,
    pinned = entry.pinned == true,
    celebrated = entry.celebrated == true,
  }
end

-- guide_seen only ever gets set true (no "unsee"), so OR-merging disk's value
-- in is always safe. Callers must have already checked
-- `type(disk_meta) == 'table'` (see load() / save()).
local function merge_meta(disk_meta)
  meta.guide_seen = (meta.guide_seen == true) or (disk_meta.guide_seen == true)
end

-- Rebuild _baseline/_sessions_appended from the current `usage` table.
-- Called whenever `usage` is freshly (re)synced with disk: setup(),
-- load_from_disk(), and the end of every save() once the merged result has
-- been written.
local function sync_baseline()
  _baseline = {}
  _sessions_appended = {}
  for cmd, entry in pairs(usage) do
    if type(entry) == 'table' then
      _baseline[cmd] = baseline_of(entry)
    end
  end
end

local function read_disk()
  local f = io.open(data_file, 'r')
  if not f then
    return {}
  end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not (ok and type(data) == 'table') then
    return {}
  end
  return data
end

local function load()
  local data = read_disk()
  if type(data._meta) == 'table' then
    merge_meta(data._meta)
  end
  data._meta = nil
  -- Migrate entries from old format on load; reset shown so max_shown is per-session
  for _, entry in pairs(data) do
    if type(entry) == 'table' then
      migrate_entry(entry)
      entry.shown = 0
    end
  end
  return data
end

-- Merge in-memory `usage` with disk before writing, so a concurrent Neovim
-- instance's writes are never overwritten. Every save-triggering function
-- goes through save() → this single merge point. See
-- docs/adr/0014-usage-json-concurrent-merge-and-migration.md for the
-- per-field merge strategy and why each field is handled the way it is.
local function merge_with_disk(disk_data)
  local merged = {}

  local all_cmds = {}
  for cmd, entry in pairs(usage) do
    if type(entry) == 'table' then
      all_cmds[cmd] = true
    end
  end
  for cmd, entry in pairs(disk_data) do
    if type(entry) == 'table' then
      all_cmds[cmd] = true
    end
  end

  for cmd in pairs(all_cmds) do
    local mem_entry = usage[cmd]
    local disk_entry = type(disk_data[cmd]) == 'table' and disk_data[cmd] or nil

    if mem_entry and disk_entry then
      local baseline = _baseline[cmd] or baseline_of(nil)

      local mem_sessions = mem_entry.sessions or {}
      local mem_count = mem_entry.count or 0
      local mem_suppressed = mem_entry.suppressed == true
      local mem_pinned = mem_entry.pinned == true
      local mem_celebrated = mem_entry.celebrated == true

      local count_delta = math.max(0, mem_count - baseline.count)

      local appended = math.min(_sessions_appended[cmd] or 0, #mem_sessions)
      local new_sessions = vim.deepcopy(disk_entry.sessions or {})
      for i = #mem_sessions - appended + 1, #mem_sessions do
        table.insert(new_sessions, mem_sessions[i])
      end
      while #new_sessions > MAX_SESSIONS do
        table.remove(new_sessions, 1)
      end

      local function merge_flag(mem_val, base_val, disk_val)
        if mem_val ~= base_val then
          return mem_val
        end
        return disk_val == true
      end

      merged[cmd] = {
        count = (disk_entry.count or 0) + count_delta,
        shown = mem_entry.shown or 0,
        sessions = new_sessions,
        suppressed = merge_flag(mem_suppressed, baseline.suppressed, disk_entry.suppressed),
        pinned = merge_flag(mem_pinned, baseline.pinned, disk_entry.pinned),
        celebrated = merge_flag(mem_celebrated, baseline.celebrated, disk_entry.celebrated),
      }
    elseif mem_entry then
      merged[cmd] = mem_entry
    else
      merged[cmd] = migrate_entry(disk_entry)
    end
  end

  return merged
end

-- Write to a temp file then rename so a crash mid-write can never corrupt the data file.
local function write_file()
  ensure_dir()
  local tmp = data_file .. '.tmp'
  local f = io.open(tmp, 'w')
  if not f then
    return
  end
  local payload = vim.deepcopy(usage)
  payload._meta = meta
  f:write(vim.json.encode(payload))
  f:close()
  os.rename(tmp, data_file)
end

local function save()
  ensure_dir()

  local disk_data = read_disk()
  if type(disk_data._meta) == 'table' then
    merge_meta(disk_data._meta)
  end
  disk_data._meta = nil

  usage = merge_with_disk(disk_data)
  sync_baseline()

  write_file()
end

local function increment(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].count = usage[cmd].count + 1
  session_counts[cmd] = (session_counts[cmd] or 0) + 1
end

-- Maps raw keystroke bytes -> registry key name for increment(). Multi-char
-- notation (<C-d> etc.) is converted via nvim_replace_termcodes so the raw
-- byte matches what on_key delivers.
local function build_track_table()
  -- Base single-char keys not in the registry but needed for level detection.
  -- 'g' is omitted (always part of a compound, tracked via last_op). 'y' is
  -- needed for graph.is_register_underused()'s total-yank count — see
  -- commands.lua's '"+y' entry for the other half of that gate.
  local t = {
    f = 'f',
    F = 'F',
    n = 'n',
    ['0'] = '0',
    h = 'h',
    j = 'j',
    k = 'k',
    l = 'l',
    w = 'w',
    b = 'b',
    x = 'x',
    p = 'p',
    u = 'u',
    i = 'i',
    a = 'a',
    o = 'o',
    y = 'y',
    G = 'G',
    v = 'v',
    ['*'] = '*',
  }
  for cmd, entry in pairs(commands.registry) do
    if entry.track then
      if #cmd == 1 then
        t[cmd] = cmd
      else
        -- Multi-char notation like <C-d>: convert to raw byte for on_key lookup.
        local raw = vim.api.nvim_replace_termcodes(cmd, true, true, true)
        if raw ~= '' then
          t[raw] = cmd
        end
      end
    end
  end
  return t
end
local TRACK = build_track_table()

-- Keys that make is_diff worth reading vim.wo.diff for: j/k (j_many_diff/
-- k_many_diff) plus the plain insert-entry keys (diff_jump_then_insert_next/
-- _prev, #237) — mirrors patterns.lua's own unexported INSERT_KEYS. See the
-- is_diff computation below for why this stays a separate local table
-- instead of exporting patterns.lua's internal one.
local DIFF_GATE_KEYS = {
  j = true,
  k = true,
  i = true,
  I = true,
  a = true,
  A = true,
  o = true,
  O = true,
  s = true,
  S = true,
}

-- Raw on_key bytes -> canonical name for the handful of insert-mode-only keys
-- patterns_insert.feed_insert() cares about. <C-w>/<C-n>/<C-o> each mean
-- something different in Normal mode — see
-- docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md for why that
-- coexistence is safe.
local INSERT_SPECIAL = {}
for _, name in ipairs({ '<BS>', '<Left>', '<Right>', '<Esc>', '<C-w>', '<C-n>', '<C-o>' }) do
  local raw = vim.api.nvim_replace_termcodes(name, true, true, true)
  if raw ~= '' then
    INSERT_SPECIAL[raw] = name
  end
end

local insert_seq = patterns_insert.new_insert_seq()

-- Raw on_key bytes → canonical name, for the one terminal-mode key
-- patterns_terminal.feed_terminal() cares about. Only <Esc> matters —
-- see patterns_terminal.lua for why <C-w> is deliberately not detected here.
local TERMINAL_SPECIAL = {}
do
  local raw = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
  if raw ~= '' then
    TERMINAL_SPECIAL[raw] = '<Esc>'
  end
end

local terminal_seq = patterns_terminal.new_terminal_seq()

-- :e/:b file ping-pong detection. Persists across separate Ex commands typed
-- minutes apart (unlike seq/insert_seq/terminal_seq) — only touched at <CR>
-- time, alongside tokenize().
local pingpong_seq = patterns_cmdline.new_pingpong_seq()

-- Words command_arg() must return before a switch is worth verifying.
-- Duplicated from patterns_cmdline.lua's private PINGPONG_COMMANDS rather
-- than exported — see docs/adr/0015-ex-command-verify-before-credit.md for why.
local PINGPONG_WORDS = { e = true, b = true }

local _recording_macro = false

-- Raw bytes for the two ways an Ex command line can end. <C-c> is treated
-- the same as <Esc> — both abort without submitting; nothing else reliably
-- ends cmdline editing from vim.on_key's vantage point.
local CMDLINE_CR = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
local CMDLINE_ESC = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
local CMDLINE_CTRL_C = vim.api.nvim_replace_termcodes('<C-c>', true, true, true)

-- <Up>/<Down> (command-line history recall) -- #259. Tracked separately from
-- the terminating keys above: these don't end the cmdline session, they're a
-- signal observed WHILE it's open, consumed at the terminating key.
local CMDLINE_UP = vim.api.nvim_replace_termcodes('<Up>', true, true, true)
local CMDLINE_DOWN = vim.api.nvim_replace_termcodes('<Down>', true, true, true)

-- Whether <Up>/<Down> was pressed at least once during the CURRENTLY-OPEN ':'
-- cmdline session (#259). Scoped to one open-to-close cmdline session --
-- reset the moment that session ends (<CR>/<Esc>/<C-c> below) -- unlike
-- history_recall_state above, which persists across the whole plugin
-- session. This has to live here rather than inside patterns_cmdline.lua:
-- that module is intentionally vim.*-free and only ever sees one complete
-- string at <CR> time (see its file header) -- it has no per-keystroke entry
-- point to observe an <Up>/<Down> press itself, only the RESULT (the recalled
-- text already sitting in the buffer) once the terminating key arrives.
local cmdline_recalled_via_history = false

-- Tobira's own UI commands (:Tobira, :TobiraStats, :TobiraGuide,
-- :TobiraProgress, :TobiraReset) must never be tracked as Ex-command usage.
-- See docs/adr/0015-ex-command-verify-before-credit.md for why this lives
-- here rather than in patterns_cmdline.lua or commands.lua.
--
-- tokenize() always lowercases the command word, so a lowercase prefix match
-- here is correct regardless of how the user capitalized it.
local OWN_CMD_PREFIX = 'ex:tobira'

-- Cheap gate deciding whether a completed Ex command is even worth deferring
-- a changedtick-based success check for. Duplicates track_substitute()'s own
-- "is the word a prefix of 'substitute'" check rather than exporting it — see
-- docs/adr/0015-ex-command-verify-before-credit.md for why.
local function looks_like_substitute(tokenized_name)
  local word = tokenized_name and tokenized_name:match('^ex:(%a+)$')
  return word ~= nil and ('substitute'):sub(1, #word) == word
end

-- Ex-command tracking: the tokenizable cmdline content only exists once, in
-- full, at the terminating key, so there is no per-keystroke buffer here.
-- See docs/adr/0015-ex-command-verify-before-credit.md for the vim.on_key
-- timing this relies on and why credit below is deferred and re-verified.
--
-- Resets seq/insert_seq on every cmdline keystroke — otherwise a stale
-- pending_op from just before ':' was pressed would still be sitting there
-- once normal mode resumes.
local function handle_cmdline_key(key)
  seq = patterns.new_seq()
  insert_seq = patterns_insert.new_insert_seq()

  if vim.fn.getcmdtype() ~= ':' then
    return -- search (/ ?) or expression (=) cmdline — not an Ex command
  end

  if key == CMDLINE_CR then
    local cmdline_text = vim.fn.getcmdline()
    local name = patterns_cmdline.tokenize(cmdline_text)
    if name and name:sub(1, #OWN_CMD_PREFIX) ~= OWN_CMD_PREFIX then
      increment(name)
    end
    -- Feed the same completed cmdline text to the substitute-repeat tracker,
    -- alongside tokenize() above. vim.fn.line('.') here is still the
    -- pre-substitution cursor line — the line the bare (no-range) :s is
    -- about to run on. Credit is deferred and re-verified via changedtick —
    -- see docs/adr/0015-ex-command-verify-before-credit.md for why.
    if looks_like_substitute(name) then
      local target_line = vim.fn.line('.')
      local bufnr = vim.api.nvim_get_current_buf()
      local before_tick = vim.api.nvim_buf_get_changedtick(bufnr)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_changedtick(bufnr) == before_tick then
          return -- :s made no real change — nothing to credit
        end
        local sub_result = patterns_cmdline.track_substitute(substitute_state, cmdline_text, target_line)
        if sub_result and M.on_pattern then
          M.on_pattern(sub_result.pattern, sub_result.cmd)
        end
      end)
    end

    -- Both detectors below are reactive patterns (reported via on_pattern
    -- immediately, not gated on a usage-count threshold) sharing one
    -- command_arg() call for the filename/argument text tokenize() discards
    -- by design. Credit is deferred and re-verified by comparing the RESULT
    -- against the TARGET — see docs/adr/0015-ex-command-verify-before-credit.md
    -- for why.
    local word, arg = patterns_cmdline.command_arg(cmdline_text)
    if PINGPONG_WORDS[word] and arg then
      local target = vim.fn.fnamemodify(arg, ':p')
      vim.schedule(function()
        if vim.fn.expand('%:p') ~= target then
          return -- rejected, or never actually switched to this file
        end
        local pingpong_result = patterns_cmdline.feed_pingpong(pingpong_seq, word, arg)
        if pingpong_result and M.on_pattern then
          M.on_pattern(pingpong_result.pattern, pingpong_result.cmd)
        end
      end)
    end

    -- Only pays the nvim_tabpage_list_wins() call for an actual :tabnew
    -- submission. Reads the CURRENT tabpage's windows; since on_key runs
    -- before this <CR>'s effect lands, that's still the tab the PREVIOUS
    -- :tabnew opened, not the one about to be created. Reuses `arg` from
    -- command_arg() above (nil → '') instead of re-parsing the cmdline.
    if name == 'ex:tabnew' then
      local win_count = #vim.api.nvim_tabpage_list_wins(0)
      local result = patterns_cmdline.feed_tabnew(tabnew_seq, arg or '', win_count)
      if result and M.on_pattern then
        M.on_pattern(result.pattern, result.cmd)
      end
    end

    -- Verbatim Ex-command retype detection (#241): reuses the same `word`
    -- AND `arg` command_arg() already extracted above -- `arg` is also what
    -- feed_history_recall() uses to decline bare commands with nothing
    -- worth recalling (`:w`, `:q`, `:noh`, ...), see that function's header
    -- comment. Unlike the substitute/pingpong/tabnew detectors above, no
    -- vim.schedule()/verify-before-credit deferral is needed here -- the
    -- signal is the retyping itself, not the command's effect. Tobira's own
    -- UI commands are excluded the same way increment() above excludes them
    -- (OWN_CMD_PREFIX has no meaning inside the vim.*-free
    -- patterns_cmdline.lua, hence the check living here — see
    -- docs/adr/0015-ex-command-verify-before-credit.md).
    -- See docs/adr/0095-cmdline-history-recall-detection.md for the
    -- exclusion-by-word design this relies on to never double-fire alongside
    -- substitute_repeat/ex_file_pingpong/tabnew_run above.
    --
    -- recalled_via_history (#259): captured BEFORE the flag is reset below,
    -- so this <CR> still sees whether <Up>/<Down> was pressed earlier in
    -- THIS cmdline session.
    if name and name:sub(1, #OWN_CMD_PREFIX) ~= OWN_CMD_PREFIX then
      local recall_result = patterns_cmdline.feed_history_recall(
        history_recall_state,
        cmdline_text,
        word,
        arg,
        cmdline_recalled_via_history
      )
      if recall_result and M.on_pattern then
        M.on_pattern(recall_result.pattern, recall_result.cmd)
      end
    end
    cmdline_recalled_via_history = false -- session over, one way or another
    return
  end

  if key == CMDLINE_ESC or key == CMDLINE_CTRL_C then
    cmdline_recalled_via_history = false -- aborted session over — do not carry the flag into the next one
    return -- aborted or canceled — do not count
  end

  if key == CMDLINE_UP or key == CMDLINE_DOWN then
    cmdline_recalled_via_history = true
  end
  -- Any other key: still typing. Nothing to do until the terminating key.
end

-- Handles one Insert-mode keystroke: tracks <C-w>/<C-n>/<C-o> under their
-- insert-mode composite keys, feeds patterns_insert's streak detection, and
-- feeds patterns.lua's cross-mode macro-opportunity watch. See
-- docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md for why.
local function handle_insert_key(key)
  local canonical = INSERT_SPECIAL[key]
  if canonical == '<C-w>' then
    increment('<C-w>')
  elseif canonical == '<C-n>' then
    increment('<C-n>')
  end
  -- Counted under the composite 'i_<C-o>' key, never the raw '<C-o>' registry
  -- key, which TRACK already claims for the Normal-mode jumplist-back meaning.
  if canonical == '<C-o>' then
    increment('i_<C-o>')
  end
  -- canonical is nil for ordinary characters; feed_insert() reads `key` then.
  local result = patterns_insert.feed_insert(insert_seq, canonical, key)

  -- Fed from both this function and the Normal-mode branch of handle_key()
  -- below — see docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md
  -- for why macro-opportunity detection has to cross the mode boundary.
  local macro_result = patterns.feed_macro(seq, canonical or key, vim.loop.now())

  -- Priority: macro_result > result — see the ADR above.
  local fired = macro_result or result
  if fired and M.on_pattern then
    M.on_pattern(fired.pattern, fired.cmd)
  end
end

local function handle_terminal_key(key)
  local canonical = TERMINAL_SPECIAL[key]
  local result = patterns_terminal.feed_terminal(terminal_seq, canonical)
  if result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  end
end

local function handle_key(key)
  if current_mode:sub(1, 1) == 'i' then
    local _re = vim.fn.reg_executing()
    if not (_recording_macro or _re ~= '') then
      handle_insert_key(key)
    end
    return
  end

  if current_mode:sub(1, 1) == 'c' then
    -- Same macro exclusion as the normal-mode path below: a macro that types
    -- and runs an Ex command should not double-count it every replay on top
    -- of whatever recorded the macro invocation itself (q/@).
    local _re = vim.fn.reg_executing()
    if not (_recording_macro or _re ~= '') then
      handle_cmdline_key(key)
    end
    return
  end

  if current_mode == 't' then
    local _re = vim.fn.reg_executing()
    if not (_recording_macro or _re ~= '') then
      handle_terminal_key(key)
    end
    return
  end

  if VISUAL_MODES[current_mode] then
    -- Routes through patterns.feed(), same as the Normal-mode branch below,
    -- instead of the generic non-Normal-mode reset further down. See
    -- docs/adr/0017-mode-cache-state-reset-boundaries.md for why this branch
    -- exists and the #179 bug it fixes.
    -- insert_seq/terminal_seq are still reset here — Visual mode is neither
    -- Insert nor Terminal, so any half-finished state in those two would
    -- otherwise sit stale until the next real mode switch.
    insert_seq = patterns_insert.new_insert_seq()
    terminal_seq = patterns_terminal.new_terminal_seq()

    local _re = vim.fn.reg_executing()
    if _recording_macro or _re ~= '' then
      return
    end

    local line = vim.fn.line('.')
    local result = patterns.feed(seq, key, line, false, vim.loop.now())
    if result and M.on_pattern then
      M.on_pattern(result.pattern, result.cmd)
    end
    return
  end

  if current_mode:sub(1, 1) ~= 'n' then
    seq = patterns.new_seq()
    insert_seq = patterns_insert.new_insert_seq()
    terminal_seq = patterns_terminal.new_terminal_seq()
    return
  end
  -- Skip keystrokes while recording or replaying a macro so they don't pollute
  -- usage counts. _recording_macro is set by RecordingEnter/Leave autocmd
  -- (cheaper); reg_executing() covers macro replay where no autocmd fires.
  local _re = vim.fn.reg_executing()
  if _recording_macro or _re ~= '' then
    return
  end

  local line = vim.fn.line('.')

  -- Feeds the Normal-mode keystroke into the insert-mode <C-o> one-shot watch
  -- (armed by feed_insert('<Esc>')). Mutates only insert_seq — seq
  -- (patterns.lua's own state) below is untouched by it, and vice versa.
  -- Computed here, but not reported via on_pattern yet — see the priority
  -- reconciliation below.
  local co_result = patterns_insert.feed_after_escape(insert_seq, key)

  -- Only reads vim.wo.diff for keys patterns.lua's is_diff branches actually
  -- consult (j/k for j_many_diff/k_many_diff, plus the insert-entry keys for
  -- diff_jump_then_insert_next/_prev, #237) to keep the vim.on_key hot path
  -- cheap — see "vim.on_key() performance" in lua/tobira/CLAUDE.md.
  -- patterns.lua stays vim.*-free; this is the one call site that reads the
  -- option and threads it in as a parameter. DIFF_GATE_KEYS mirrors
  -- patterns.lua's own (unexported) INSERT_KEYS plus j/k — kept as a
  -- separate local table rather than exporting patterns.lua's internal one,
  -- since Vim's insert-entry key set is fixed and effectively never changes.
  local is_diff = DIFF_GATE_KEYS[key] and vim.wo.diff or false
  -- Read once, reused for feed_macro() below too — patterns.lua stays
  -- vim.*-free and only ever sees this caller-supplied monotonic ms value.
  local now = vim.loop.now()
  local result = patterns.feed(seq, key, line, is_diff, now)

  -- Fed from both this branch and handle_insert_key()'s matching call — see
  -- docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md for why.
  local macro_result = patterns.feed_macro(seq, key, now)

  -- Compound operators (dw, dd, gg, >>, …) are tracked via seq.op_completed,
  -- never a before/after comparison on seq.last_op — see
  -- docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md for why.
  if seq.op_completed then
    increment(seq.last_op)
  end

  -- Priority: macro_result > result > co_result — all three can fire for the
  -- same keystroke. See
  -- docs/adr/0016-pattern-dispatch-priority-and-key-collisions.md for the
  -- full reasoning.
  if macro_result and M.on_pattern then
    M.on_pattern(macro_result.pattern, macro_result.cmd)
  elseif result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  elseif co_result and M.on_pattern then
    M.on_pattern(co_result.pattern, co_result.cmd)
  end

  -- Skip counting a key already consumed as the 2nd character of a multi-key
  -- compound (gj, zz, "a, ]c …) — seq.key_consumed is set by patterns.feed()
  -- for those.
  if not seq.key_consumed then
    local registry_key = TRACK[key]
    if registry_key then
      increment(registry_key)
    end
  end
end

function M.setup()
  if _initialized then
    return
  end
  _initialized = true

  usage = load()
  sync_baseline()

  local mode_group = vim.api.nvim_create_augroup('tobira_mode', { clear = true })

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = mode_group,
    callback = function()
      local new_mode = vim.fn.mode()
      -- Reset terminal_seq the moment mode() actually changes away from 't'
      -- — see docs/adr/0017-mode-cache-state-reset-boundaries.md for why.
      if current_mode == 't' and new_mode ~= 't' then
        terminal_seq = patterns_terminal.new_terminal_seq()
      end
      current_mode = new_mode
    end,
  })

  vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group = mode_group,
    callback = function(ev)
      _recording_macro = ev.event == 'RecordingEnter'
      if _recording_macro then
        seq = patterns.new_seq()
        insert_seq = patterns_insert.new_insert_seq()
        terminal_seq = patterns_terminal.new_terminal_seq()
      end
    end,
  })

  local ns = vim.api.nvim_create_namespace('tobira_logger')
  vim.on_key(function(key, typed)
    -- typed == '' means the key was generated internally (mapping expansion or
    -- built-in command implementation), not physically typed by the user.
    -- Skip it so that pressing D does not also fire 'd' and '$' through the
    -- pattern state machine. typed is nil on Neovim < 0.10; fall back to key.
    if typed == '' then
      return
    end
    handle_key(typed or key)
  end, ns)

  vim.api.nvim_create_autocmd('VimLeave', {
    group = mode_group,
    callback = M.close_session,
  })
end

-- Flush current-session key counts into usage.sessions, then save.
-- Called on VimLeave and exposed for testing.
function M.close_session()
  for cmd, count in pairs(session_counts) do
    table.insert(usage[cmd].sessions, count)
    _sessions_appended[cmd] = (_sessions_appended[cmd] or 0) + 1
    while #usage[cmd].sessions > MAX_SESSIONS do
      table.remove(usage[cmd].sessions, 1)
    end
  end

  -- Zero-pad every known command untouched this session, so decay-based
  -- scoring has a real "time passed, no use" signal instead of a missing
  -- entry. Runs once per VimLeave, never on the vim.on_key hot path.
  for cmd, entry in pairs(usage) do
    if session_counts[cmd] == nil and not session_adopted[cmd] then
      table.insert(entry.sessions, 0)
      _sessions_appended[cmd] = (_sessions_appended[cmd] or 0) + 1
      while #entry.sessions > MAX_SESSIONS do
        table.remove(entry.sessions, 1)
      end
    end
  end

  session_counts = {}
  session_adopted = {}

  -- save() re-reads disk and merges before writing (see merge_with_disk()),
  -- so a concurrent Neovim instance's writes are never overwritten here.
  save()
end

function M.get(cmd)
  return usage[cmd] or { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
end

-- Exposed only for testing — lets specs verify in-session counts before close_session.
function M.get_session_counts()
  return session_counts
end

function M.get_all()
  return usage
end

function M.mark_shown(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].shown = usage[cmd].shown + 1
  save()
end

-- Treat an explicit in-session adoption as a strong session signal.
-- Immediately flushes a boosted count to sessions so is_adopted() returns true
-- without waiting for the next VimLeave.
function M.mark_adopted(cmd)
  local count = math.max(session_counts[cmd] or 0, 5)
  session_counts[cmd] = nil
  session_adopted[cmd] = true
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  table.insert(usage[cmd].sessions, count)
  _sessions_appended[cmd] = (_sessions_appended[cmd] or 0) + 1
  while #usage[cmd].sessions > MAX_SESSIONS do
    table.remove(usage[cmd].sessions, 1)
  end
  save()
end

function M.is_celebrated(cmd)
  return usage[cmd] ~= nil and usage[cmd].celebrated == true
end

function M.mark_celebrated(cmd)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].celebrated = true
  save()
end

function M.set_suppressed(cmd, value)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].suppressed = value
  save()
end

function M.set_pinned(cmd, value)
  if not usage[cmd] then
    usage[cmd] = { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
  end
  usage[cmd].pinned = value
  save()
end

function M.reset()
  usage = {}
  session_counts = {}
  session_adopted = {}
  _baseline = {}
  _sessions_appended = {}
  meta = { guide_seen = false }
  seq = patterns.new_seq()
  insert_seq = patterns_insert.new_insert_seq()
  terminal_seq = patterns_terminal.new_terminal_seq()
  substitute_state = patterns_cmdline.new_substitute_state()
  pingpong_seq = patterns_cmdline.new_pingpong_seq()
  tabnew_seq = patterns_cmdline.new_tabnew_seq()
  history_recall_state = patterns_cmdline.new_history_recall_state()
  cmdline_recalled_via_history = false
  current_mode = 'n'
  _recording_macro = false
  _initialized = false
  -- Intentionally no disk I/O here. Callers that want disk cleared
  -- (e.g. :TobiraReset) invoke clear_disk() explicitly afterwards.
end

-- Re-read usage from disk without resetting in-memory state.
-- Used in tests to verify migration of old-format JSON.
function M.load_from_disk()
  usage = load()
  sync_baseline()
end

-- Merge-on-save (see merge_with_disk()) — every other public save path goes
-- through this.
function M.save()
  save()
end

-- Overwrites usage.json unconditionally, bypassing the merge-on-save that
-- M.save() otherwise does. Used only by :TobiraReset. See
-- docs/adr/0014-usage-json-concurrent-merge-and-migration.md for why a full
-- reset needs this rather than the normal merge-aware save path.
function M.clear_disk()
  write_file()
  sync_baseline()
end

-- Exposed for :checkhealth so health.lua doesn't recompute or duplicate
-- this path independently.
function M.data_dir()
  return data_dir
end

function M.data_file()
  return data_file
end

function M.is_guide_seen()
  return meta.guide_seen == true
end

function M.mark_guide_seen()
  meta.guide_seen = true
  save()
end

return M
