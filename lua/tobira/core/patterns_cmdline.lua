-- Pure Ex-command tokenizer. No vim.* calls.
--
-- Given the text of a command-line buffer (vim.fn.getcmdline(), NOT
-- including the leading ':'), M.tokenize() strips any leading range address
-- and returns a semantic command name like 'ex:s', 'ex:g', 'ex:norm', or nil
-- if the text is empty/unparseable.
--
-- see docs/adr/0002-ex-command-tokenizer-one-shot-parsing.md for why this is
-- a separate module, why tokenize() takes one complete string at <CR> time
-- rather than an incremental per-keystroke state machine, why strip_range()
-- only covers practical range forms rather than full Ex grammar, and why
-- command abbreviations are deliberately not canonicalized.

local M = {}

-- Consumes a leading Ex range address so the remaining text starts at the
-- command name. Handles, in any combination separated by ',' or ';':
--   %            (whole file)
--   . $          (current line / last line)
--   digits       (line number)
--   'x '< '>     (mark reference — a quote followed by exactly one char)
--   /pat/ ?pat?  (search address, honoring \-escaped delimiters)
--   + -          (line offsets, e.g. .+1)
local function strip_range(text)
  local i = 1
  local n = #text
  while i <= n do
    local c = text:sub(i, i)
    if c == '%' or c == '.' or c == '$' or c == ',' or c == ';' or c == '+' or c == '-' or c:match('%d') then
      i = i + 1
    elseif c == "'" then
      i = i + 2 -- mark reference: 'x, '<, '>
    elseif c == '/' or c == '?' then
      local closing = c
      local j = i + 1
      while j <= n and text:sub(j, j) ~= closing do
        if text:sub(j, j) == '\\' then
          j = j + 1
        end
        j = j + 1
      end
      i = j + 1
    else
      break
    end
  end
  return text:sub(i)
end

-- text: the command-line buffer content, without the leading ':'.
function M.tokenize(text)
  if not text then
    return nil
  end

  local trimmed = text:match('^%s*(.-)%s*$')
  if trimmed == '' then
    return nil
  end

  local rest = strip_range(trimmed)
  if rest == '' then
    return nil
  end

  local word = rest:match('^(%a+)')
  if word then
    return 'ex:' .. word:lower()
  end

  -- Non-letter command names (!, &, <, >, =, @, ~, ...): keep the literal
  -- leading character as the semantic name rather than dropping it silently.
  local sym = rest:match('^([%p])')
  if sym then
    return 'ex:' .. sym
  end

  return nil
end

-- Argument-aware counterpart to tokenize(): returns the command word plus
-- the trimmed argument text tokenize() discards. Shared by feed_tabnew() and
-- feed_pingpong() below; NOT reused by track_substitute() (it needs
-- delimiter-bounded pattern/replacement fields, not an opaque argument
-- string).
--
-- see docs/adr/0003-cmdline-command-arg-shared-argument-extraction.md for why
--
-- Returns word, arg: word is the lowercased command word (same casing rule
-- as tokenize()), or nil if there wasn't one to extract (empty / unparseable
-- / range-only / symbolic-command input — unlike tokenize(), command_arg()
-- only recognizes letter-word commands, with no punctuation fallback). arg
-- is the trimmed remainder, or nil for "no argument" (a bare ":e"/":b"/
-- ":tabnew"). Callers that want '' instead of nil (feed_tabnew below, whose
-- contract predates this shared function) convert that themselves at the
-- call site — see logger.lua.
function M.command_arg(text)
  if not text then
    return nil, nil
  end

  local trimmed = text:match('^%s*(.-)%s*$')
  if trimmed == '' then
    return nil, nil
  end

  local rest = strip_range(trimmed)
  if rest == '' then
    return nil, nil
  end

  local word, remainder = rest:match('^(%a+)(.*)$')
  if not word then
    return nil, nil
  end

  -- A force-bang (:e!, :b!, ...) sits directly after the command word, before
  -- any argument. Strip it so it never ends up glued onto the argument.
  remainder = remainder:gsub('^!', '', 1)
  local arg = remainder:match('^%s*(.-)%s*$')
  if arg == '' then
    arg = nil
  end

  return word:lower(), arg
end

-- Ex-command ping-pong detection (#114): a user repeatedly bouncing between
-- the same two files via :e/:b (:e A -> :e B -> :e A, or the :b equivalent)
-- is a direct signal for <C-^>, which jumps straight to the alternate file.
--
-- see docs/adr/0004-ex-file-pingpong-detection.md for why this lives in this
-- file rather than a sibling one, why command abbreviations aren't
-- recognized, why this is only one of potentially several <C-^> triggers,
-- and why credit is deferred/verified by the caller rather than here.
local PINGPONG_COMMANDS = { e = true, b = true }

-- Only remembers the two most recently *distinct* filenames touched via
-- :e/:b, not a full history — see ADR above for why.
function M.new_pingpong_seq()
  return { first = nil, second = nil, fired = false }
end

-- word: lowercased Ex command word, as returned by command_arg() above.
-- arg: the trimmed filename argument, or nil if there wasn't one.
-- Returns { pattern = 'ex_file_pingpong', cmd = '<C-^>' } the moment the
-- just-typed filename returns to the file used two distinct switches ago;
-- nil otherwise.
function M.feed_pingpong(seq, word, arg)
  if not (PINGPONG_COMMANDS[word] and arg) then
    return nil
  end

  if arg == seq.second then
    -- Reopening the current file isn't a new switch; leave state untouched.
    return nil
  end

  -- True the moment this switch returns to the file used two distinct
  -- switches ago. Computed from state as it stood BEFORE this call updates
  -- it below.
  local is_return = arg == seq.first and seq.second ~= nil
  local should_fire = is_return and not seq.fired

  seq.first = seq.second
  seq.second = arg
  -- Latches until a third, different file breaks the rotation — see ADR
  -- above for why.
  seq.fired = is_return

  if should_fire then
    return { pattern = 'ex_file_pingpong', cmd = '<C-^>' }
  end
  return nil
end

-- ── tabnew one-file-per-tab habit detection ─────────────────────────────────
-- Detects "tabs as a VSCode-style file browser" (#113): opening a new file
-- with :tabnew, one tab per file, 3+ times in a row with no window splits in
-- between, and suggests buffer commands (:b / <C-^>) instead — reuses
-- commands.lua's existing '<C-^>' entry rather than duplicating it.
--
-- see docs/adr/0005-tabnew-one-file-per-tab-detection.md for why this is a
-- second, independent state machine in this file, why a bare :tabnew or an
-- added window split resets the streak, and the QA bug behind resetting
-- (not ignoring) a repeated filename.
--
-- feed_tabnew() is called only for ":tabnew" submissions (logger.lua checks
-- M.tokenize()'s result first — any other Ex command is a no-op for this
-- streak, not a reset, since it says nothing about window layout).
--
--   arg: the trimmed file argument (command_arg()'s second return, '' for no
--     argument).
--   win_count: the CURRENT tabpage's window count (nvim_tabpage_list_wins,
--     read by logger.lua — this module stays vim.*-free). Since on_key fires
--     BEFORE this <CR>'s effect lands, "current tabpage" here is still the
--     tab the PREVIOUS :tabnew opened. Meaningless before the streak's first
--     :tabnew (seq.streak == 0); callers may pass anything then.
function M.new_tabnew_seq()
  return { streak = 0, files = {} }
end

local TABNEW_STREAK_THRESHOLD = 3

function M.feed_tabnew(seq, arg, win_count)
  if arg == '' then
    seq.streak = 0
    seq.files = {}
    return nil
  end

  if seq.files[arg] then
    -- Repeated filename this streak: reset, not ignore — see ADR above.
    seq.streak = 0
    seq.files = {}
    return nil
  end

  if seq.streak > 0 and win_count ~= 1 then
    -- Previous tab picked up a 2nd window before this one fired — reset;
    -- this :tabnew still starts a fresh streak of its own below.
    seq.streak = 0
    seq.files = {}
  end

  seq.streak = seq.streak + 1
  seq.files[arg] = true
  if seq.streak >= TABNEW_STREAK_THRESHOLD then
    seq.streak = 0
    seq.files = {}
    return { pattern = 'tabnew_run', cmd = '<C-^>' }
  end
  return nil
end

-- ── Repeated-substitute detection ───────────────────────────────────────────
--
-- M.track_substitute(state, text, line) parses the actual
-- `:s/{pattern}/{replacement}/{flags}` BODY (tokenize() only extracts the
-- command name and discards the rest) so identical manual substitutions
-- across different lines can be detected and answered with `&` (repeat on
-- this line) or `g&` (repeat file-wide) (#115). Stateful across calls
-- (unlike tokenize()) — state lives via M.new_substitute_state() for the
-- whole session, same lifetime as logger.lua's `seq`.
--
-- see docs/adr/0006-cmdline-substitute-repeat-detection.md for the scope
-- limits (bare :s only, abbreviation-prefix matching, delimiter handling,
-- the 2->& / 3->g& threshold) and the changedtick-based verify-before-credit
-- fix applied at the logger.lua call site.
local function is_valid_delimiter(c)
  return c ~= '' and c:match('%s') == nil and c:match('%w') == nil and c ~= '\\' and c ~= '"' and c ~= '|'
end

-- Shared by track_substitute() below and feed_history_recall() further down
-- (#241) -- both need to know whether a lowercased command word belongs to
-- the ":substitute" family, so this is factored out once rather than
-- duplicated across two functions in the same file (unlike the cross-file
-- duplication in logger.lua's looks_like_substitute(), which exists to keep
-- this module vim.*-free -- see docs/adr/0015).
local function is_substitute_word(lower_word)
  return ('substitute'):sub(1, #lower_word) == lower_word
end

-- Finds the index of the next unescaped occurrence of `delim` in `text`
-- starting at `start`. Returns nil if none is found before the end of the
-- string. `\`-escaped characters (including an escaped delimiter) are
-- skipped over as a pair, mirroring strip_range()'s search-address escaping.
local function find_unescaped(text, start, delim)
  local i = start
  local n = #text
  while i <= n do
    local c = text:sub(i, i)
    if c == '\\' then
      i = i + 2
    elseif c == delim then
      return i
    else
      i = i + 1
    end
  end
  return nil
end

function M.new_substitute_state()
  return { entries = {} }
end

-- state: from M.new_substitute_state(). text: the command-line buffer
-- content (same shape tokenize() takes). line: the buffer line number the
-- command will run on (caller-supplied — this module has no vim.* access;
-- see logger.lua's call site, which passes vim.fn.line('.')).
--
-- Returns { pattern = 'substitute_repeat' | 'substitute_repeat_wide',
-- cmd = '&' | 'g&' } the moment the threshold is crossed, or nil.
function M.track_substitute(state, text, line)
  if not text or not line then
    return nil
  end

  local trimmed = text:match('^%s*(.-)%s*$')
  if trimmed == '' then
    return nil
  end

  local stripped = strip_range(trimmed)
  if stripped ~= trimmed then
    return nil -- explicit range present — out of scope, see ADR above
  end

  local word = stripped:match('^(%a+)')
  if not word then
    return nil
  end
  local lower_word = word:lower()
  if not is_substitute_word(lower_word) then
    return nil -- not a recognized abbreviation of :substitute
  end

  local after_word = stripped:sub(#word + 1)
  local delim = after_word:sub(1, 1)
  if not is_valid_delimiter(delim) then
    return nil -- bare :s (repeat-last) or a flags-only form — nothing to compare
  end

  local pattern_start = 2
  local pattern_end = find_unescaped(after_word, pattern_start, delim)
  if not pattern_end then
    return nil -- no closing delimiter for the pattern — ambiguous, not tracked
  end
  local pattern = after_word:sub(pattern_start, pattern_end - 1)
  if pattern == '' then
    return nil -- empty pattern reuses the last search — can't verify equality
  end

  local replacement_start = pattern_end + 1
  local replacement_end = find_unescaped(after_word, replacement_start, delim)
  local replacement
  if replacement_end then
    replacement = after_word:sub(replacement_start, replacement_end - 1)
  else
    replacement = after_word:sub(replacement_start) -- trailing delimiter omitted
  end

  local key = pattern .. '\0' .. replacement
  local entry = state.entries[key]
  if not entry then
    entry = { lines = {}, count = 0 }
    state.entries[key] = entry
  end

  if entry.lines[line] then
    return nil -- same line re-run — not a new distinct line
  end
  entry.lines[line] = true
  entry.count = entry.count + 1

  if entry.count == 2 then
    return { pattern = 'substitute_repeat', cmd = '&' }
  elseif entry.count == 3 then
    return { pattern = 'substitute_repeat_wide', cmd = 'g&' }
  end
  return nil
end

-- ── Verbatim Ex-command retype detection ────────────────────────────────────
--
-- M.feed_history_recall(state, text, word) generalizes the "retyping instead
-- of recalling" insight behind the three detectors above to any OTHER Ex
-- command (#241): the exact same full command-line string submitted 2+ times
-- is a signal for `:` + <Up> (or q:) history recall, regardless of what the
-- command actually does.
--
-- word (command_arg()'s first return, already lowercased; nil for symbolic
-- commands like :!) gates out anything the three more specific detectors
-- above already claim, so this generic one never double-fires alongside them
-- and can never race to fire first:
--   - any abbreviation of :substitute (is_substitute_word) -- even scope
--     track_substitute() itself declines (e.g. a ranged :%s/../../) is
--     excluded here too, by word-family rather than by exact-scope match, so
--     the same edit habit never earns two different suggestions.
--   - :e / :b (PINGPONG_COMMANDS) -- regardless of whether an argument was
--     given, matching feed_pingpong()'s own literal-word-only scope (no
--     abbreviations recognized, so :edit/:buffer fall through to this
--     generic detector instead).
--   - :tabnew, exact word only -- same literal-word-only scope as
--     feed_tabnew()'s own ":tabnew" name check in logger.lua.
--
-- Unlike substitute/pingpong/tabnew (see
-- docs/adr/0015-ex-command-verify-before-credit.md), no defer-and-verify
-- credit is needed here -- the signal is the retyping ITSELF, not any effect
-- the command has. A command that fails identically both times still means
-- the user typed the same doomed text twice instead of recalling and fixing
-- it from history.
--
-- see docs/adr/0095-cmdline-history-recall-detection.md for the full
-- rationale and the fires-once-per-distinct-text latch.
function M.new_history_recall_state()
  return { entries = {} }
end

-- state: from M.new_history_recall_state(), persists for the whole session
-- (same lifetime as new_substitute_state()'s state).
-- text: the command-line buffer content (same shape tokenize() takes).
-- word: command_arg()'s first return for this same text, or nil.
--
-- Returns { pattern = 'cmdline_history_recall', cmd = 'q:' } the moment a
-- given full command line is submitted for the second time, or nil.
function M.feed_history_recall(state, text, word)
  if not text then
    return nil
  end
  if word and (is_substitute_word(word) or PINGPONG_COMMANDS[word] or word == 'tabnew') then
    return nil
  end

  local trimmed = text:match('^%s*(.-)%s*$')
  if trimmed == '' then
    return nil
  end

  local entry = state.entries[trimmed]
  if not entry then
    entry = { count = 0, fired = false }
    state.entries[trimmed] = entry
  end
  entry.count = entry.count + 1

  -- Latches after firing once -- see ADR above for why a 3rd+ identical
  -- resubmission must not notify again.
  if entry.count == 2 and not entry.fired then
    entry.fired = true
    return { pattern = 'cmdline_history_recall', cmd = 'q:' }
  end
  return nil
end

return M
