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
-- Accumulates across the whole session (unlike seq/insert_seq above, which
-- reset on every cmdline keystroke) — repeated-substitute detection needs
-- to remember pattern+replacement pairs across separate, distinct :s
-- invocations that can be minutes apart.
local substitute_state = patterns_cmdline.new_substitute_state()
-- Session-scoped tabnew-habit streak — see
-- patterns_cmdline.new_tabnew_seq()'s doc comment. Deliberately NOT reset
-- alongside seq/insert_seq on every cmdline keystroke (see
-- handle_cmdline_key below): it must persist ACROSS separate :tabnew
-- submissions within a session, unlike seq/insert_seq which represent
-- normal/insert-mode grammar that is meaningless while typing a command.
local tabnew_seq = patterns_cmdline.new_tabnew_seq()
local session_counts = {}
-- Per-command snapshot of {count, shown, suppressed, pinned, celebrated} as
-- of the last time `usage` was synced with disk (initial load, or the end of
-- a previous save()'s merge). merge_with_disk() diffs against this to tell
-- "I changed this locally" apart from "this has always been the default" —
-- see merge_with_disk()'s comment for why that distinction matters.
local _baseline = {}
-- Per-command count of sessions[] entries appended locally since _baseline
-- was last synced. An array-length diff can't recover this once the rolling
-- MAX_SESSIONS cap has evicted entries from either side, so it's tracked
-- explicitly instead (see merge_with_disk()).
local _sessions_appended = {}
-- Commands flushed early via mark_adopted() this session, so close_session()
-- doesn't also zero-pad or re-append them (see close_session's zero-pad loop).
local session_adopted = {}

-- Wired by init.lua — logger has no direct dependency on suggest.
M.on_pattern = nil

local current_mode = 'n'

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

-- guide_seen has no "unsee" path (mark_guide_seen only ever sets it true), so
-- OR-merging is both correct and safe here: it can never flip a value this
-- process just set back to false because of a stale disk read, and it still
-- picks up a concurrent instance's dismissal of the first-run guide instead
-- of discarding it.
-- Callers are expected to have already checked `type(disk_meta) == 'table'`
-- (see load() / save()) — corrupt/absent _meta is filtered out there.
local function merge_meta(disk_meta)
  meta.guide_seen = (meta.guide_seen == true) or (disk_meta.guide_seen == true)
end

-- Rebuild _baseline/_sessions_appended from the current `usage` table.
-- Called whenever `usage` is freshly (re)synced with disk: setup(),
-- load_from_disk(), and the end of every save() once the merged result has
-- been written. Every later save() diffs local changes against this
-- snapshot (see merge_with_disk()).
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

-- Merge in-memory `usage` with whatever is currently on disk before writing,
-- so a concurrent Neovim instance's writes are never silently overwritten.
-- Every save-triggering function goes through save() → this single merge
-- point instead of duplicating its own merge logic.
--
-- Per-field strategy:
--
--   .count : additive. This instance's growth since its own last sync
--     (`_baseline`) is real new data from this process; stacking that delta
--     on disk's current value preserves what other concurrent instances
--     already contributed.
--
--   .shown : local only, never combined with disk. `load()` always resets
--     in-memory `shown` to 0 so the max_shown display cap is per-launch, not
--     lifetime — folding disk's old value back in would make it cumulative.
--
--   .sessions : union, not overwrite. Two concurrent instances can each
--     close a real session; both entries matter to graph.lua's
--     decay/mastery scoring. Disk's array is kept as-is, and only the
--     entries THIS instance appended since its own baseline are added —
--     tracked via `_sessions_appended` rather than an array-length diff,
--     since the rolling MAX_SESSIONS cap can evict entries from either side
--     without meaning "no new data". The cap is re-applied after merging.
--
--   .suppressed / .pinned / .celebrated : sticky booleans. If THIS instance
--     changed the flag since its baseline, that's a deliberate local
--     decision and wins outright (keeps "suppress then un-suppress" working
--     within one instance). Otherwise disk's current value is adopted
--     as-is, so instance A's change survives instance B's unrelated save.
--     In the pure concurrent-write case this behaves like an OR: once set
--     by any instance, it stays set. `.celebrated` is only ever set, never
--     unset (no "uncelebrate" call exists), so the same stickiness matches
--     how it's actually used.
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

-- Maps raw keystroke bytes → registry key name for increment().
-- Values are the canonical registry key string (e.g. '\x04' → '<C-d>').
-- Single ASCII keys map to themselves; multi-char notation (<C-d> etc.) is
-- converted via nvim_replace_termcodes so the raw byte matches what on_key
-- delivers.
local function build_track_table()
  -- Base single-char ASCII keys (not in registry but needed for level detection).
  -- 'g' omitted: it's always part of a compound (gg, gj…) tracked via last_op.
  -- 'y' is added because graph.is_register_underused() needs a total "how
  -- many times has the user yanked" count, independent of which compound
  -- (yy, yw, "+y, …) the operator ends up completing as — see commands.lua's
  -- '"+y' entry for the other half of that gate.
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

-- Raw on_key bytes → canonical name, for the handful of insert-mode keys
-- patterns_insert.feed_insert() cares about (built via nvim_replace_termcodes,
-- like TRACK above). '<C-w>', '<C-n>', and '<C-o>' each mean something
-- different in Normal mode (window-prefix, down-motion, jumplist-back) than
-- they do in insert mode (delete-word, completion, one-shot command) — safe
-- to coexist only because INSERT_SPECIAL is consulted exclusively from
-- handle_insert_key, once the mode cache already says insert mode. See
-- commands.lua's 'i_<C-o>' registry comment for the full collision story.
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

-- :e/:b file ping-pong detection. Persistent module-level state, like
-- seq/insert_seq/terminal_seq above -- but unlike those, handle_cmdline_key
-- must NOT reset it on every cmdline keystroke, since the whole point is to
-- remember the last two distinct files across separate Ex commands typed
-- minutes apart. Only touched at <CR> time, alongside tokenize().
local pingpong_seq = patterns_cmdline.new_pingpong_seq()

-- Words command_arg() must return before a switch is worth verifying (see
-- the verify-before-credit comment below). Duplicated from
-- patterns_cmdline.lua's private PINGPONG_COMMANDS rather than exported —
-- that module stays a pure, vim.*-free tokenizer, and feed_pingpong()
-- re-validates the word itself regardless, so a mismatch here would only
-- waste one vim.schedule() call, never cause an incorrect credit.
local PINGPONG_WORDS = { e = true, b = true }

local _recording_macro = false

-- Raw bytes for the two ways an Ex command line can end. <C-c> is
-- treated the same as <Esc> — both abort without submitting; nothing else
-- reliably ends cmdline editing from vim.on_key's vantage point (<C-\><C-n>
-- exists but is obscure enough to not be worth a third branch here).
local CMDLINE_CR = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
local CMDLINE_ESC = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
local CMDLINE_CTRL_C = vim.api.nvim_replace_termcodes('<C-c>', true, true, true)

-- Tobira's own UI commands (:Tobira, :TobiraStats, :TobiraGuide,
-- :TobiraProgress, :TobiraReset) must never be tracked as Ex-command usage —
-- otherwise checking your own stats becomes tracked usage itself, polluting
-- the data being displayed (QA found :TobiraReset making "ex:tobirastats"
-- show up as a top command in :TobiraStats).
--
-- Lives here rather than patterns_cmdline.lua (a generic tokenizer with no
-- tobira-specific knowledge) or commands.lua (the registry of *teachable*
-- commands — tobira's own are never suggested, so excluding them is an
-- unrelated concern) — this is purely a "when to record" decision, which is
-- this file's job.
--
-- tokenize() always lowercases the command word, so a lowercase prefix match
-- here is correct regardless of how the user capitalized it.
local OWN_CMD_PREFIX = 'ex:tobira'

-- Cheap gate deciding whether a completed Ex command is even worth deferring
-- a changedtick-based success check for (see the fix comment at the call
-- site below). Deliberately duplicates track_substitute()'s own "is the word
-- a prefix of 'substitute'" check rather than exporting it — same precedent
-- as PINGPONG_WORDS below: the tokenizer module stays pure, and
-- track_substitute() re-validates the full command regardless, so a mismatch
-- here only ever costs one unnecessary snapshot, never an incorrect credit.
local function looks_like_substitute(tokenized_name)
  local word = tokenized_name and tokenized_name:match('^ex:(%a+)$')
  return word ~= nil and ('substitute'):sub(1, #word) == word
end

-- Ex-command tracking: vim.on_key sees every cmdline keystroke, but the
-- tokenizable content only exists once, in full, at the terminating key —
-- so there is no per-keystroke buffer here (see patterns_cmdline.lua's
-- header for why). vim.fn.getcmdtype()/getcmdline() are the vim.* half;
-- patterns_cmdline stays pure and only ever sees a complete string.
--
-- Confirmed empirically: vim.on_key's callback for the terminating keystroke
-- fires BEFORE Neovim processes it, so getcmdtype()/getcmdline() still
-- report the pre-submission state at the exact moment this function
-- inspects them — the same timing patterns_insert.lua's <Esc>-vs-insert-mode
-- bounce detection relies on.
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
    -- Same completed-cmdline text, fed to the substitute-repeat tracker
    -- alongside tokenize() above. vim.fn.line('.') at this point is
    -- still the pre-substitution cursor line — the line the bare (no-range)
    -- :s is about to run on (see patterns_cmdline.lua's header for why an
    -- explicit range is out of scope and skipped instead of guessed at).
    --
    -- Verify-before-credit (fix for a QA-found false positive, same problem
    -- class and timing fix as ex_file_pingpong's below): this on_key callback
    -- runs BEFORE Neovim validates or executes the command (see this
    -- function's header comment), so `cmdline_text` alone can't tell whether
    -- the substitution actually matched anything — E486 "Pattern not found"
    -- lets Neovim run the command and still change nothing.
    --
    -- Signal chosen: the target buffer's changedtick, snapshotted here and
    -- re-checked inside vim.schedule() once Neovim has fully processed the
    -- command — credit only if it increased.
    --
    -- v:errmsg was tried first and rejected: every way this test suite drives
    -- keystrokes (feedkeys/nvim_feedkeys/vim.cmd) goes through the API/RPC
    -- dispatch layer, which wraps execution in try_start()/try_end() and
    -- converts errors straight into Lua exceptions without ever touching
    -- v:errmsg (confirmed by hand) — a signal this fix's own mandatory
    -- regression test could never observe.
    --
    -- changedtick avoids that and also gets the edge cases right where
    -- errmsg (or a plain text diff) wouldn't: ":s/foo/foo/" (text unchanged
    -- but a real substitution) still increments it, while ":s///n"
    -- (report-only) and a ":s///c" where every confirm is declined correctly
    -- leave it flat — none of those raise an error or change the text, so
    -- neither "no error" nor "no text diff" was ever the right question.
    --
    -- Ordering: the only realistic risk is a single-main-loop-tick race
    -- (same shape ex_file_pingpong's fix already accepts) if something else
    -- mutates this buffer between the snapshot and the scheduled check —
    -- negligible in real use, handled in tests via a short vim.wait().
    --
    -- The credit itself (track_substitute(), not just the notification) is
    -- what's deferred. `looks_like_substitute` above gates this whole cost
    -- so it's only paid for commands that could plausibly be a :s.
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

    -- Independent of the usage-count tracking above — both detectors below
    -- share a single command_arg() call for the filename/argument text
    -- tokenize() discards by design (see tokenize()'s header and
    -- patterns_cmdline.command_arg's doc comment). Both are reactive
    -- patterns, like patterns_insert/patterns_terminal elsewhere in this
    -- file: reported via on_pattern immediately rather than waiting on a
    -- usage-count threshold.
    --
    -- Verify-before-credit (fix for a QA-found false positive, same timing
    -- issue as the substitute fix above): this <CR> callback runs BEFORE
    -- Neovim validates/executes the command, so typing ":e"/":b" isn't the
    -- same as the file switch actually happening — Neovim can still reject
    -- it (E94 "No matching buffer", E37 "No write since last change").
    --
    -- Fix: defer credit to vim.schedule(), then verify by comparing the
    -- RESULT against the TARGET (is the named file the current buffer now),
    -- not a before/after diff — a before/after diff stops meaning "did THIS
    -- command succeed" once a later command changes the buffer first. The
    -- literal `arg` text still goes into feed_pingpong(); verification only
    -- gates whether to call it.
    --
    -- Ordering: on_key and vim.schedule() share the main-loop thread, so
    -- there's no data race — only the question of a second :e/:b landing
    -- before this callback runs. The RESULT-vs-TARGET check still asks the
    -- right question for THIS command in that case; the only residual edge
    -- case (a later command coincidentally targeting the same filename) is
    -- self-correcting, since the user really is mid-bounce between those two
    -- files. This window essentially never matters outside synthetic
    -- back-to-back feedkeys in tests.
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

    -- Only reads nvim_tabpage_list_wins for an actual :tabnew submission —
    -- every other command is a no-op for this streak, so there's no reason
    -- to pay that vim.api call for :s, :g, etc. It reads the CURRENT
    -- tabpage's windows; since on_key runs before this <CR>'s effect lands,
    -- that's still the tab the PREVIOUS :tabnew opened, not the one about to
    -- be created. Reuses `arg` from command_arg() above (nil → '') instead
    -- of re-parsing the cmdline.
    if name == 'ex:tabnew' then
      local win_count = #vim.api.nvim_tabpage_list_wins(0)
      local result = patterns_cmdline.feed_tabnew(tabnew_seq, arg or '', win_count)
      if result and M.on_pattern then
        M.on_pattern(result.pattern, result.cmd)
      end
    end
    return
  end

  if key == CMDLINE_ESC or key == CMDLINE_CTRL_C then
    return -- aborted or canceled — do not count
  end
  -- Any other key: still typing. Nothing to do until the terminating key.
end

local function handle_insert_key(key)
  local canonical = INSERT_SPECIAL[key]
  if canonical == '<C-w>' then
    increment('<C-w>')
  elseif canonical == '<C-n>' then
    increment('<C-n>')
  end
  -- Counted explicitly under the composite 'i_<C-o>' key, exactly like
  -- '<C-w>' above — never under the raw '<C-o>' registry key, which TRACK
  -- (built from commands.registry) already claims for the Normal-mode
  -- jumplist-back meaning.
  if canonical == '<C-o>' then
    increment('i_<C-o>')
  end
  -- `key` doubles as the ordinary-character payload feed_insert() uses to
  -- reconstruct tokens — canonical is nil for anything other than the
  -- special keys above, and feed_insert() only ever reads `char` in that case.
  local result = patterns_insert.feed_insert(insert_seq, canonical, key)

  -- Macro-opportunity detection spans the mode boundary — the repeated
  -- *edit* it watches for (e.g. "cwFooBar<Esc>") includes the insert-mode
  -- typed replacement text, not just the normal-mode c/w/<Esc> keys around
  -- it. Same cross-file orchestration shape as feed_after_escape() above:
  -- patterns.lua's seq is fed from here too, in addition to the normal-mode
  -- branch below — see patterns.lua's M.feed_macro doc comment. canonical
  -- (when present) is the same readable name patterns_insert.feed_insert()
  -- just used above, so the same physical key always tokenises the same way
  -- regardless of which branch of handle_key() happened to see it.
  local macro_result = patterns.feed_macro(seq, canonical or key, vim.loop.now())

  -- macro_result wins when both fire on the same keystroke (see the matching
  -- priority note in the Normal-mode branch below for the full reasoning —
  -- retyping the same 6+ character word twice, as part of retyping the same
  -- WHOLE edit sequence 3 times, satisfies both insert_completion_repeat and
  -- macro_opportunity on the same <Esc>; the 3x-repeated-sequence insight is
  -- strictly the bigger win of the two).
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

  -- Feed the same Normal-mode keystroke into the insert-mode <C-o>
  -- one-shot watch (armed by feed_insert('<Esc>') — see patterns_insert.lua's
  -- feed_after_escape doc comment for why this detection has to cross into
  -- the Normal-mode keystroke stream at all). This mutates only insert_seq's
  -- watching_co/post_esc_keys fields — seq (patterns.lua's own state) below
  -- is completely untouched by it, and vice versa. Computed here, but NOT
  -- reported via on_pattern yet — see the priority reconciliation below.
  local co_result = patterns_insert.feed_after_escape(insert_seq, key)

  -- Only read vim.wo.diff (a window-local option lookup) for j/k —
  -- the only two keys patterns.lua's is_diff branches ever consult. This
  -- keeps the vim.on_key hot path from paying that read's cost on every one
  -- of the dozens of other keys a normal editing session sends through here,
  -- in the same spirit as caching vim.fn.mode() via ModeChanged instead of
  -- calling it per-keystroke (see "vim.on_key() performance" in this
  -- project's CLAUDE.md) — except here the existing key check already gates
  -- it for free, so no separate cache/autocmd is needed. patterns.lua stays
  -- vim.*-free (module dependency rules in lua/tobira/CLAUDE.md); this is the
  -- one call site that reads the option and threads it in as a parameter.
  local is_diff = (key == 'j' or key == 'k') and vim.wo.diff or false
  -- vim.loop.now() (ms, monotonic) is the real clock for patterns.lua's
  -- jumplist/changelist tolerance-window detection — patterns.lua itself
  -- stays vim.*-free and only ever sees this caller-supplied number. Read
  -- once and reused for feed_macro() below too — no reason to pay for a
  -- second vim.loop.now() call for the same keystroke.
  local now = vim.loop.now()
  local result = patterns.feed(seq, key, line, is_diff, now)

  -- See handle_insert_key()'s matching call for why this has to be fed
  -- from both branches. Normal-mode keys are passed through as-is (no
  -- canonical translation needed — every key this branch ever sees is
  -- already a plain, single-token raw byte, exactly what inner_feed() above
  -- already treats `key` as).
  local macro_result = patterns.feed_macro(seq, key, now)

  -- Track compound operators (dw, dd, gg, >>, …) the moment they complete.
  -- Single-char keys are handled by the TRACK lookup below; compound ones
  -- are only visible here through seq.op_completed, which patterns.feed()
  -- sets on the exact call that freshly assigns seq.last_op. This must NOT
  -- be a before/after value comparison on seq.last_op — two identical
  -- compounds back-to-back (dd dd, dw dw, …) re-assign the same string, so
  -- a value-change check would silently drop the second occurrence.
  if seq.op_completed then
    increment(seq.last_op)
  end

  -- Priority reconciliation between patterns.lua's `result`, patterns_insert's
  -- `co_result`, and `macro_result` — all three are fed the same keystroke
  -- and can all produce a suggestion for it (e.g. <Esc>0i matches both
  -- zero_col_then_insert (-> gI) and insert_co_oneshot (-> insert-mode
  -- <C-o>)), so an explicit priority is needed rather than letting
  -- source-code order decide by accident.
  --
  -- `result` wins over `co_result`: patterns.lua's suggestions here are
  -- specific, single-purpose tips (gI for 0i, s for xi, A for $a) that are
  -- objectively more direct than the generic "you could have stayed in
  -- insert mode" hint. `co_result` only fires when `result` is nil, the
  -- common case for motions with no competing specific pattern (h, l, w, b,
  -- e, j, k, …).
  --
  -- macro_result is checked FIRST, ahead of both: it only fires after 3 full
  -- repetitions of an entire edit sequence, a rarer and bigger win than any
  -- single-keystroke pattern that also happens to match the same key (e.g.
  -- retyping "cwFooBar<Esc>" 3 times also satisfies
  -- patterns_insert.lua's insert_completion_repeat on that same final <Esc>,
  -- but "you retyped this whole edit 3 times" beats "you retyped one word").
  if macro_result and M.on_pattern then
    M.on_pattern(macro_result.pattern, macro_result.cmd)
  elseif result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
  elseif co_result and M.on_pattern then
    M.on_pattern(co_result.pattern, co_result.cmd)
  end

  -- Only count as a standalone key when it was not consumed as the second
  -- character of a multi-key compound (gj, zz, "a, ]c …).
  -- patterns.feed() sets seq.key_consumed = true in those cases.
  -- TRACK values are registry key strings; raw Ctrl bytes map to their
  -- canonical name (e.g. '\x04' → '<C-d>').
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
      -- Mode cache extension: terminal_seq's <Esc>-streak is only
      -- meaningful within one continuous stay in terminal-job mode. Reset it
      -- the moment mode() actually changes away from 't' (successful escape,
      -- or the terminal buffer closing under the user), so a leftover
      -- half-streak from a previous terminal session can never combine with
      -- the first <Esc> of a later, unrelated one.
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

  -- Zero-pad every already-known command that went untouched this session, so
  -- sessions[] reflects real elapsed sessions rather than only sessions where
  -- the command happened to be used. Without this, decay-based scoring
  -- has no signal that time passed with no use — "idle" was previously
  -- invisible, not recorded as 0. Runs once per VimLeave, never on the
  -- vim.on_key hot path.
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
-- M.save() otherwise does. Used only by :TobiraReset. A full reset is an
-- explicit "erase everything" user action, not an incremental update — if it
-- went through the normal merge, an empty in-memory `usage` would just
-- resurrect every entry a concurrent instance (or a previous run) still has
-- on disk, and :TobiraReset would silently stop actually resetting anything.
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
