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
-- #115: accumulates across the whole session (unlike seq/insert_seq above,
-- which reset on every cmdline keystroke) — repeated-substitute detection
-- needs to remember pattern+replacement pairs across separate, distinct :s
-- invocations that can be minutes apart.
local substitute_state = patterns_cmdline.new_substitute_state()
local session_counts = {}
-- Per-command snapshot of {count, shown, suppressed, pinned, celebrated} as
-- of the last time `usage` was synced with disk (initial load, or the end of
-- a previous save()'s merge). merge_with_disk() diffs against this to tell
-- "I changed this locally" apart from "this has always been the default" —
-- see merge_with_disk()'s comment for why that distinction matters (#122).
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
-- so a concurrent Neovim instance's writes are never silently overwritten
-- (#122). Every save-triggering function (mark_shown, mark_adopted,
-- set_suppressed, set_pinned, mark_celebrated, close_session, ...) goes
-- through save() → this single merge point, instead of each duplicating its
-- own merge logic. Previously only close_session() merged anything, and
-- only its `.count` field.
--
-- Per-field strategy, decided deliberately field by field:
--
--   .count : additive. This instance's growth since ITS OWN last sync with
--     disk (`_baseline`) is real new data (keystrokes counted) that
--     happened in this process; stacking that delta on top of disk's
--     current value preserves what every other concurrently running
--     instance already contributed. This generalizes the delta logic
--     close_session() already had.
--
--   .shown : local value only, never combined with disk. `load()` always
--     resets in-memory `shown` to 0 so the max_shown display cap is
--     per-launch, not lifetime. Folding disk's old `.shown` back in the way
--     `.count` does would quietly turn a per-launch counter into a
--     cumulative-forever one, which is not what "reset shown so max_shown
--     is per-session" (see load()) means.
--
--   .sessions : union, not overwrite. Two concurrently running instances
--     can each close a real session; both entries are meaningful input to
--     the decay/mastery scoring in graph.lua, and neither should be
--     dropped. Disk's current array (which may already include another
--     instance's entries) is kept as-is, and only the entries THIS instance
--     appended since its own baseline are added on top — tracked via
--     `_sessions_appended` rather than an array-length diff, because the
--     rolling MAX_SESSIONS cap can evict old entries from either side
--     without that meaning "no new data". The rolling cap is then
--     re-applied to the merged result.
--
--   .suppressed / .pinned / .celebrated : sticky booleans. If THIS instance
--     changed the flag since its own baseline, that's a deliberate local
--     decision (e.g. the user just un-suppressed a command from
--     :TobiraGuide) and wins outright — this is what keeps the existing
--     "suppress then un-suppress" round trip working within one instance.
--     If this instance never touched the flag, whatever is currently on
--     disk is adopted as-is, which is what lets instance A's set_suppressed
--     survive instance B's unrelated save. In the pure concurrent-write
--     case (neither instance touches the other's flag) this behaves like an
--     OR: once suppressed/pinned by any instance, it stays that way.
--     `.celebrated` gets the same treatment: it is only ever set, never
--     unset (there is no "uncelebrate" call anywhere in the codebase — see
--     suggest.lua's `not logger.is_celebrated(cmd)` guard), so the same
--     OR-like stickiness matches how it's actually used.
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
  -- 'y' added for #59: graph.is_register_underused() needs a total "how many
  -- times has the user yanked" count, independent of which compound (yy, yw,
  -- "+y, …) the operator ends up completing as — see commands.lua's '"+y'
  -- entry for the other half of that gate.
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
-- patterns_insert.feed_insert() cares about (#58). Built once via the same
-- nvim_replace_termcodes approach as TRACK above. '<C-w>' is included so its
-- adoption can be measured — this is safe from the normal-mode window-prefix
-- meaning of Ctrl-W because INSERT_SPECIAL is only consulted while the mode
-- cache says insert mode (handle_insert_key), never from the normal-mode path.
-- '<C-n>' (#112) is the same shape of problem: in normal mode it's Vim's
-- built-in down-motion (never tracked by tobira today), while in insert mode
-- it's keyword completion — the suggestion this file's insert_completion_repeat
-- pattern recommends. Listing it here keeps its insert-mode adoption count
-- (incremented explicitly below) from ever being conflated with the unrelated
-- normal-mode keystroke, exactly like '<C-w>'.
--
-- '<C-o>' (#105) is included for exactly the same reason and resolves the
-- exact same kind of collision: the raw <C-o> byte already means "jump back
-- in the jumplist" in Normal mode (commands.lua's '<C-o>' entry, tracked via
-- TRACK below). Insert-mode <C-o> is a different command bound to that same
-- physical key. Consulting INSERT_SPECIAL only from handle_insert_key (i.e.
-- only once the mode cache already says insert mode) is what makes both
-- meanings safe to coexist — see commands.lua's 'i_<C-o>' registry comment
-- for the full collision story and why a composite key was needed there too.
local INSERT_SPECIAL = {}
for _, name in ipairs({ '<BS>', '<Left>', '<Right>', '<Esc>', '<C-w>', '<C-n>', '<C-o>' }) do
  local raw = vim.api.nvim_replace_termcodes(name, true, true, true)
  if raw ~= '' then
    INSERT_SPECIAL[raw] = name
  end
end

local insert_seq = patterns_insert.new_insert_seq()

-- Raw on_key bytes → canonical name, for the one terminal-mode key
-- patterns_terminal.feed_terminal() cares about (#110). Only <Esc> matters —
-- see patterns_terminal.lua for why <C-w> is deliberately not detected here.
local TERMINAL_SPECIAL = {}
do
  local raw = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
  if raw ~= '' then
    TERMINAL_SPECIAL[raw] = '<Esc>'
  end
end

local terminal_seq = patterns_terminal.new_terminal_seq()

local _recording_macro = false

-- Raw bytes for the two ways an Ex command line can end (#57). <C-c> is
-- treated the same as <Esc> — both abort without submitting; nothing else
-- reliably ends cmdline editing from vim.on_key's vantage point (<C-\><C-n>
-- exists but is obscure enough to not be worth a third branch here).
local CMDLINE_CR = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
local CMDLINE_ESC = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
local CMDLINE_CTRL_C = vim.api.nvim_replace_termcodes('<C-c>', true, true, true)

-- Tobira's own UI commands (see plugin/tobira.lua: Tobira, TobiraStats,
-- TobiraGuide, TobiraProgress, TobiraReset — all share this prefix) must
-- never be tracked as Ex-command usage. Without this, checking your own
-- stats (:TobiraStats) becomes tracked usage itself, polluting the very
-- data being displayed (found by QA: running :TobiraReset once made
-- "ex:tobirastats" show up as a top command in :TobiraStats).
--
-- This lives here rather than in patterns_cmdline.lua because that module
-- is a generic, reusable Ex-command tokenizer with no knowledge of
-- tobira-specific concerns (see its header comment) — teaching it about its
-- own plugin name would break that purity for a concern that's really about
-- *when to record*, which is this file's job. It also doesn't belong in
-- commands.lua: that file is explicitly "the master registry of teachable
-- commands" (things tobira suggests learning), and tobira's own commands are
-- never suggested — a self-exclusion guard is an unrelated concern.
--
-- patterns_cmdline.tokenize() always lowercases the command word into its
-- 'ex:<word>' result, so a lowercase literal prefix match here is correct
-- regardless of how the user capitalized the command (':TobiraStats',
-- ':tobirastats', etc. all resolve to the same Ex command in Vim, and both
-- tokenize to the same lowercase key).
local OWN_CMD_PREFIX = 'ex:tobira'

-- #115 fix (verify-before-credit): cheap gate deciding whether a completed
-- Ex command is even worth deferring a changedtick-based success check for
-- at all (see the full fix comment at the call site below). Deliberately
-- duplicates track_substitute()'s own "is the word a prefix of 'substitute'"
-- check rather than exporting it from patterns_cmdline.lua — same
-- duplication precedent as #114's ex_file_pingpong fix's PINGPONG_WORDS
-- table: that module stays a pure, vim.*-free tokenizer, and
-- track_substitute() already re-validates the full command (range,
-- delimiters, ...) for real regardless of what this gate decides. A
-- mismatch here (e.g. this matching a ranged ":%s/foo/bar/" that
-- track_substitute() will go on to reject anyway) only ever costs one
-- unnecessary changedtick snapshot + scheduled callback, never an incorrect
-- credit — tokenize()'s 'name' already strips any range the same way
-- track_substitute() does, so this only has to check the command word.
local function looks_like_substitute(tokenized_name)
  local word = tokenized_name and tokenized_name:match('^ex:(%a+)$')
  return word ~= nil and ('substitute'):sub(1, #word) == word
end

-- Ex-command tracking (#57): vim.on_key sees every cmdline keystroke, but
-- the actual tokenizable content only exists once, in full, right when the
-- terminating key arrives — so there is no per-keystroke buffer to
-- accumulate here (see patterns_cmdline.lua's header for why that's a
-- deliberate design choice, not a missing feature). vim.fn.getcmdtype() and
-- vim.fn.getcmdline() are the vim.* half of this feature; patterns_cmdline
-- stays pure and only ever sees a complete string.
--
-- Confirmed empirically (see the PR description / logger_spec.lua's Ex
-- command tracking tests): vim.on_key's callback for the <CR>/<Esc> keystroke
-- that ends cmdline mode fires BEFORE Neovim processes that keystroke, so
-- getcmdtype() still reports ':' and getcmdline() still holds the complete
-- pre-submission buffer at the exact moment this function inspects them —
-- the same "on_key runs before the key's effect lands" timing
-- patterns_insert.lua's <Esc>-vs-insert-mode bounce detection relies on.
--
-- Resets seq/insert_seq on every cmdline keystroke, same as the pre-#57
-- generic "current_mode is neither n nor i" branch this replaces for mode
-- 'c' — otherwise a stale pending_op from just before the ':' was pressed
-- (e.g. a stray 'd') would still be sitting there once normal mode resumes.
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
    -- #115: same completed-cmdline text, fed to the substitute-repeat
    -- tracker alongside tokenize() above. vim.fn.line('.') at this point is
    -- still the pre-substitution cursor line — the line the bare (no-range)
    -- :s is about to run on (see patterns_cmdline.lua's header for why an
    -- explicit range is out of scope and skipped instead of guessed at).
    --
    -- Verify-before-credit (fix for a QA-found false positive, same problem
    -- class and same timing fix as #114's ex_file_pingpong verify-before-
    -- credit): this on_key callback for <CR> runs BEFORE Neovim validates or
    -- executes the command (see this function's header comment above), so
    -- `cmdline_text` says nothing about whether the substitution actually
    -- matched anything. Typing and submitting ":s/pat/repl/" is not the same
    -- thing as a replacement actually happening — Neovim can run the command
    -- and still do nothing (E486 "Pattern not found" when {pattern} matches
    -- nothing on the target line), yet the pre-<CR> text alone is
    -- indistinguishable from a real successful repeat of the same edit.
    --
    -- Signal chosen: the target buffer's changedtick (nvim_buf_get_changedtick),
    -- snapshotted here (before <CR> is processed) and re-checked inside
    -- vim.schedule() (after Neovim has fully executed or rejected the
    -- command) — credit only if it increased.
    --
    -- v:errmsg was tried first (it's the obvious "did the last command fail"
    -- signal, and is what the original bug report suggested), but was
    -- empirically found unusable in THIS codebase: every way this project's
    -- test suite can simulate a keystroke (vim.fn.feedkeys / nvim_feedkeys /
    -- vim.cmd, used throughout logger_spec.lua — there is no other way to
    -- drive Ex commands from a headless test) executes the command through
    -- Neovim's API/RPC dispatch layer, which internally wraps command
    -- execution in the same try_start()/try_end() mechanism :try/:catch uses.
    -- An error caught that way is converted straight into a Lua-catchable
    -- exception and NEVER touches v:errmsg — confirmed by hand: a failing
    -- ":s/nonexistent/x/" driven via feedkeys leaves v:errmsg as '' even
    -- though the same command run via a plain Vimscript path (e.g. a timer
    -- callback, with no Lua API call anywhere in its stack) does set it to
    -- "E486: Pattern not found: nonexistent" as documented. Since a
    -- regression test is mandatory for every bug fix here (see this repo's
    -- CLAUDE.md) and this project's entire test harness is built on the API
    -- path that suppresses v:errmsg, that signal could not be verified by
    -- the very tests this fix is required to ship with — and there is no
    -- confidence it would even behave correctly for other Lua-driven
    -- automation (macros calling into Lua, other plugins scripting :s via
    -- vim.cmd) that shares the same dispatch path as the tests do.
    --
    -- changedtick has none of that ambiguity: it is a plain per-buffer
    -- counter Neovim increments on every real content mutation, regardless
    -- of what triggered it (typed, fed, or scripted) — not routed through
    -- the message/error subsystem at all. It also captures this feature's
    -- actual intent ("was a replacement really performed") more precisely
    -- than "did an error occur" would: confirmed by hand that a successful
    -- but textually-identical substitution (":s/foo/foo/", matching text
    -- replaced with itself) still increments changedtick, while a failed
    -- E486 substitution leaves it unchanged — through this exact feedkeys-
    -- driven harness. It also does the right thing for flag combinations
    -- outside v:errmsg's reach entirely: ":s///n" (report-only, no text
    -- ever replaced) or a ":s///c" where the user declines every confirm
    -- prompt raise no error at all, yet correctly leave changedtick flat, so
    -- neither would wrongly credit the streak — an errmsg-based check would
    -- have missed both, since "no error" is not the same question as "was
    -- anything actually replaced". Diffing the buffer's TEXT instead of its
    -- changedtick was considered and rejected for the same byte-identical
    -- case (":s/foo/foo/" performs a real substitution while leaving the
    -- text unchanged, which a text diff would misread as a failure).
    --
    -- Ordering: the only realistic risk is a single-main-loop-tick race,
    -- identical in shape to the one #114's fix already accepts (see that
    -- fix's comment) — if something else mutates this same buffer in the
    -- gap between the snapshot below and this scheduled check running, a
    -- failed :s could look like it succeeded. In real interactive use that
    -- gap is one tick wide and nothing else runs inside it besides this
    -- command's own execution; it only matters for synthetic back-to-back
    -- feedkeys in tests (handled there via a short vim.wait() between
    -- commands, same as #114's test suite).
    --
    -- The actual credit (the track_substitute() call itself, not just the
    -- on_pattern notification) is what's deferred, not just the
    -- notification — track_substitute() mutates substitute_state and must
    -- not mark a failed line as tracked.
    --
    -- The `looks_like_substitute` gate above avoids paying this snapshot +
    -- scheduled-callback cost for every unrelated completed Ex command (:w,
    -- :qa, ...) — mirroring #114's PINGPONG_WORDS gate for the same reason.
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
  -- #105: counted explicitly under the composite 'i_<C-o>' key, exactly like
  -- '<C-w>' above — never under the raw '<C-o>' registry key, which TRACK
  -- (built from commands.registry) already claims for the Normal-mode
  -- jumplist-back meaning.
  if canonical == '<C-o>' then
    increment('i_<C-o>')
  end
  -- `key` doubles as the ordinary-character payload feed_insert() uses to
  -- reconstruct tokens (#112) — canonical is nil for anything other than the
  -- special keys above, and feed_insert() only ever reads `char` in that case.
  local result = patterns_insert.feed_insert(insert_seq, canonical, key)
  if result and M.on_pattern then
    M.on_pattern(result.pattern, result.cmd)
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

  -- #105: feed the same Normal-mode keystroke into the insert-mode <C-o>
  -- one-shot watch (armed by feed_insert('<Esc>') — see patterns_insert.lua's
  -- feed_after_escape doc comment for why this detection has to cross into
  -- the Normal-mode keystroke stream at all). This mutates only insert_seq's
  -- watching_co/post_esc_keys fields — seq (patterns.lua's own state) below
  -- is completely untouched by it, and vice versa. Computed here, but NOT
  -- reported via on_pattern yet — see the priority reconciliation below.
  local co_result = patterns_insert.feed_after_escape(insert_seq, key)

  -- #111: only read vim.wo.diff (a window-local option lookup) for j/k —
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
  -- jumplist/changelist tolerance-window detection (#61) — patterns.lua
  -- itself stays vim.*-free and only ever sees this caller-supplied number.
  local result = patterns.feed(seq, key, line, is_diff, vim.loop.now())

  -- Track compound operators (dw, dd, gg, >>, …) the moment they complete.
  -- Single-char keys are handled by the TRACK lookup below; compound ones
  -- are only visible here through seq.op_completed, which patterns.feed()
  -- sets on the exact call that freshly assigns seq.last_op. This must NOT
  -- be a before/after value comparison on seq.last_op — two identical
  -- compounds back-to-back (dd dd, dw dw, …) re-assign the same string, so
  -- a value-change check would silently drop the second occurrence (#119).
  if seq.op_completed then
    increment(seq.last_op)
  end

  -- Priority reconciliation between patterns.lua's `result` and
  -- patterns_insert.lua's `co_result` (#105): both are fed the same
  -- keystroke above and can both produce a suggestion for it — e.g. <Esc>0i
  -- matches both patterns.lua's zero_col_then_insert (-> gI) and
  -- patterns_insert.lua's generic insert_co_oneshot (-> insert-mode <C-o>).
  -- Without an explicit rule, whichever call happened to run second in this
  -- function's source order would win the race in suggest.queue() (it
  -- cancels any pending timer and starts a new one) purely by accident of
  -- code order — not by design.
  --
  -- `result` always wins when both fire: patterns.lua's suggestions here are
  -- pre-existing, specific, single-purpose tips (gI for 0i, s for xi, A for
  -- $a) that are objectively more direct than the generic "you could have
  -- done this without leaving insert mode" hint — e.g. `A` (1 keystroke)
  -- beats teaching <C-o> for a `$a` round trip that <C-o> would still take 2
  -- keystrokes to replace. `co_result` is only ever reported when `result`
  -- is nil, which is also the common case: motions with no competing
  -- specific pattern (h, l, w, b, e, j, k, …) still report insert_co_oneshot
  -- exactly as before, since patterns.feed() returns nil for those.
  if result and M.on_pattern then
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
      -- Mode cache extension for #110: terminal_seq's <Esc>-streak is only
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
  -- the command happened to be used. Without this, decay-based scoring (#62)
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
-- on disk, and :TobiraReset would silently stop actually resetting anything
-- (#122).
function M.clear_disk()
  write_file()
  sync_baseline()
end

-- Exposed for :checkhealth (#42) so health.lua doesn't recompute or duplicate
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
