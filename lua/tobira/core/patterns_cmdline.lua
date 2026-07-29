-- Pure Ex-command tokenizer. No vim.* calls.
--
-- Given the text of a command-line buffer (vim.fn.getcmdline(), NOT
-- including the leading ':'), M.tokenize() strips any leading range address
-- and returns a semantic command name like 'ex:s', 'ex:g', 'ex:norm', or nil
-- if the text is empty/unparseable.
--
-- New sibling file (not folded into patterns.lua): tokenize() takes one
-- already-complete string handed to it once, at <CR> time, rather than a
-- per-keystroke incremental state machine — the same "shares nothing, never
-- on the same call path" test that split patterns_insert.lua out (see
-- lua/tobira/CLAUDE.md's "Module splitting policy"). The
-- getcmdtype()/getcmdline() orchestration deciding *when* to call tokenize()
-- lives in logger.lua instead, which already does vim.* work.
--
-- Deliberately NOT a full Vim range-grammar parser: strip_range() below only
-- covers the address forms actually seen in practice (%, N, N,M, '<,'>,
-- 'a,'b, /pat/,/pat2/), not Ex's entire address grammar.
--
-- Deliberately does NOT canonicalize Vim's command abbreviations (:s vs :su
-- vs :sub vs :substitute). Keying by the literal typed word avoids silently
-- guessing wrong on ambiguous short forms — disambiguating them correctly
-- requires knowing every Vim command name, which this feature doesn't need.
-- ':s' and ':sub' are tracked as two distinct buckets; revisit if usage data
-- ever shows that matters for suggestion quality.

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

-- Argument-aware counterpart to tokenize(): tokenize() deliberately discards
-- everything after the command word (see its header comment — Ex-command
-- tracking never needed it), but two later detectors need the argument text
-- itself: the tabnew one-tab-per-file streak needs to tell a bare ":tabnew"
-- apart from ":tabnew foo.txt", and the ex_file_pingpong detector needs the
-- filename argument to tell ":e A" apart from ":e B".
-- Both share this single implementation rather than each re-parsing the
-- cmdline text on their own. Reuses the same strip_range() range handling so
-- a leading range prefix never leaks into the returned argument, same as
-- tokenize().
--
-- Returns word, arg: word is the lowercased command word (same casing rule
-- as tokenize()), or nil if there wasn't one to extract (empty / unparseable
-- / range-only / symbolic-command input — command_arg() only ever needs to
-- recognize letter-word commands (:tabnew, :e, :b), unlike tokenize(), which
-- falls back to a literal punctuation character for symbolic commands). arg
-- is the trimmed remainder, or nil if there wasn't one (a bare ":e" / ":b" /
-- ":tabnew" with no argument at all). Callers that want '' instead of nil for
-- "no argument" (feed_tabnew below, whose contract predates this shared
-- function) convert that themselves at the call site — see logger.lua.
--
-- Note: this is NOT reused by track_substitute() below even though
-- both parse "the rest of the line after the command word" — command_arg()
-- treats everything after the word as one opaque trimmed string, but
-- track_substitute() needs the delimiter-bounded PATTERN and REPLACEMENT
-- fields inside that remainder (":s/foo/bar/"), which
-- command_arg()'s contract has no concept of. Forcing that through
-- command_arg() would mean immediately re-parsing its `arg` return value
-- with the same delimiter logic anyway, so track_substitute() parses the
-- post-word text itself instead of layering on top.
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

-- Ex-command ping-pong detection: a user repeatedly bouncing between the
-- same two files via :e/:b (:e A -> :e B -> :e A, or the :b equivalent) is a
-- direct signal for <C-^>, which jumps straight to the alternate file. Kept
-- in this same file rather than a new sibling one because it's fed from the
-- exact same call site as tokenize()/command_arg() (logger.lua's
-- handle_cmdline_key, at <CR> time), even though it shares no actual state
-- with either — call path, not shared state, is the deciding question (see
-- lua/tobira/CLAUDE.md's module-splitting policy).
--
-- Deliberately literal command words only ('e', 'b'), not abbreviation
-- expansion (:edit, :ed, :buffer, :bu, ...) — same "no abbreviation table"
-- call tokenize() makes for the same reason (see its header). Revisit if
-- usage data ever shows real users typing :edit/:buffer for this habit.
--
-- Coexistence with other <C-^> triggers: this is one signal among
-- potentially several that can all suggest '<C-^>' — commands.lua has
-- exactly one '<C-^>' registry entry regardless of how many patterns
-- recommend it. Only the "why am I seeing this" reason line differs per
-- trigger (locales/*.lua float.reasons); the suggestion's title/body/example
-- stay shared, since what the command DOES doesn't change based on how
-- tobira noticed you needed it.
local PINGPONG_COMMANDS = { e = true, b = true }

-- Only remembers the two most recently *distinct* filenames touched via
-- :e/:b, not a full history: this is what makes bouncing among 3+ different
-- files never satisfy "is this the file from two switches ago" below (a
-- genuinely third file always overwrites the older of the two remembered
-- names, permanently forgetting it for this rotation).
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
    -- Reopening the file that's already current isn't a new switch; leave
    -- the two-file history (and the fired latch below) untouched so an
    -- in-progress or already-fired rotation is never disturbed by it.
    return nil
  end

  -- True the moment this switch returns to the file used two distinct
  -- switches ago -- exactly the ':e A' -> ':e B' -> ':e A' shape. Computed
  -- from state as it stood BEFORE this call updates it below.
  local is_return = arg == seq.first and seq.second ~= nil
  local should_fire = is_return and not seq.fired

  seq.first = seq.second
  seq.second = arg
  -- Latches true for as long as the user keeps bouncing between exactly
  -- these two files, so continuing to alternate never re-fires the
  -- suggestion on every single switch -- the same "fire once per streak"
  -- precedent as patterns_terminal.lua's terminal_esc_repeat. A switch to a
  -- genuinely third file clears it, re-arming detection for the next
  -- two-file rotation.
  seq.fired = is_return

  if should_fire then
    return { pattern = 'ex_file_pingpong', cmd = '<C-^>' }
  end
  return nil
end

-- ── tabnew one-file-per-tab habit detection ─────────────────────────────────
-- A second, independent state machine in this same file — shares no state
-- with M.tokenize() above, but stays here because it fires from the exact
-- same call site: the tokenized Ex-command name at <CR> time, inside
-- logger.lua's handle_cmdline_key (call path, not shared state, decides
-- module splitting — see lua/tobira/CLAUDE.md).
--
-- Detects "tabs as a VSCode-style file browser": opening a new file with
-- :tabnew, one tab per file, 3+ times in a row with no window splits in
-- between, and suggests buffer commands (:b / <C-^>) instead — reuses
-- commands.lua's existing '<C-^>' entry rather than duplicating it.
--
-- feed_tabnew() is called only for ":tabnew" submissions (logger.lua checks
-- M.tokenize()'s result first — any other Ex command is a no-op for this
-- streak, not a reset, since it says nothing about window layout).
--
--   arg: the trimmed file argument (command_arg()'s second return, '' for no
--     argument). A bare ":tabnew" opens an empty scratch tab, not "one more
--     file browsed", so it RESETS the streak. A non-empty arg only advances
--     the streak the first time that exact filename is seen this streak
--     (tracked in seq.files) — Vim reuses the existing buffer for a filename
--     already open elsewhere, so repeating it can't mean one-tab-per-file
--     (QA bug: the pre-fix version tracked only "was *some* argument given",
--     so opening the same file 3x via :tabnew fired the suggestion anyway).
--     A repeat resets the streak rather than being ignored or counted as a
--     new streak's first file, for the same reason a bare :tabnew doesn't.
--
--   win_count: the CURRENT tabpage's window count (nvim_tabpage_list_wins,
--     read by logger.lua — this module stays vim.*-free). Since on_key fires
--     BEFORE this <CR>'s effect lands, "current tabpage" here is still the
--     tab the PREVIOUS :tabnew opened — exactly the one that needs checking
--     for an added split. Meaningless before the streak's first :tabnew
--     (seq.streak == 0); callers may pass anything then.
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
    -- Same filename already seen earlier in this streak: reusing an
    -- existing buffer, not browsing a new file — reset (see this file's
    -- feed_tabnew doc comment for why reset, not ignore).
    seq.streak = 0
    seq.files = {}
    return nil
  end

  if seq.streak > 0 and win_count ~= 1 then
    -- The tab opened by the previous :tabnew in this streak picked up a
    -- second window (:split, <C-w>v, ...) before this one fired — a
    -- legitimate multi-window layout, not one-tab-per-file browsing. This
    -- :tabnew still starts a fresh potential streak of its own (falls
    -- through to the streak = streak + 1 below), it just cannot build on
    -- the broken one.
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
-- this line) or `g&` (repeat file-wide). Stateful across calls (unlike
-- tokenize()) — state lives via M.new_substitute_state() for the whole
-- session, same lifetime as logger.lua's `seq`.
--
-- Deliberate scope limits:
--
-- 1. Only a BARE (no explicit range) `:s` is tracked (strip_range() detects
--    a range prefix; if anything was stripped, returns nil). The targeted
--    workflow is "move to another line, retype the same :s/// there" — the
--    target line is then unambiguously the cursor line at <CR> time. An
--    explicit range (:5s, :%s) is a different, already one-shot workflow.
--
-- 2. Command-word recognition accepts any prefix of "substitute" (s, su,
--    sub, ...) — unlike tokenize()'s general refusal to canonicalize
--    abbreviations, this is a safe special case: every prefix of
--    "substitute" diverges from other s-commands (:sort, :set, :split) well
--    before Vim's own ambiguity resolution would need to kick in.
--
-- 3. The delimiter is whatever character immediately follows the command
--    word (Vim allows anything except alphanumerics, '\', '"', '|' — :help
--    :s). Escaped delimiters (`\/`) are honored, same rule strip_range()
--    uses for search addresses.
--
-- 4. The trailing delimiter after the replacement is optional (":s/foo/bar"
--    == ":s/foo/bar/"). Anything after a present trailing delimiter (flags,
--    count) is ignored for equality — the criterion is "identical pattern
--    AND replacement", not "identical flags too".
--
-- 5. A missing closing delimiter for the PATTERN (":s/foo") and an empty
--    explicit pattern (":s//bar/", reusing the last search pattern) are both
--    treated as unparseable — comparing "the same pattern" needs literal
--    text, and neither case provides it without guessing at implicit state
--    this pure module can't access.
--
-- Threshold heuristic for `&` vs `g&`: the same (pattern, replacement) pair
-- reaching a 2nd distinct line fires `&`; a 3rd distinct line upgrades to
-- `g&` instead of firing `&` again. Distinct LINE COUNT (not line-number
-- distance) is the signal because this module has no access to the buffer's
-- total line count to judge relative distance — a count-based threshold is
-- self-contained, at the cost of not distinguishing "3 adjacent lines" from
-- "3 lines scattered across the file". Each key fires once at count==2 and
-- once at count==3, then stays silent — the same exact-count-not-threshold
-- precedent as patterns.lua's x_repeat/j_repeat.
local function is_valid_delimiter(c)
  return c ~= '' and c:match('%s') == nil and c:match('%w') == nil and c ~= '\\' and c ~= '"' and c ~= '|'
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
    return nil -- explicit range present — out of scope, see header comment
  end

  local word = stripped:match('^(%a+)')
  if not word then
    return nil
  end
  local lower_word = word:lower()
  if ('substitute'):sub(1, #lower_word) ~= lower_word then
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

return M
