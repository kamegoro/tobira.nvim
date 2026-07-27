-- Pure Ex-command tokenizer. No vim.* calls.
--
-- Given the text of a command-line buffer (as returned by vim.fn.getcmdline(),
-- i.e. NOT including the leading ':'), M.tokenize() strips any leading range
-- address and returns a semantic command name like 'ex:s', 'ex:g', 'ex:norm',
-- or nil if the text is empty / unparseable.
--
-- New sibling file (not folded into patterns.lua) because this shares no
-- state with patterns.lua's normal-mode operator-pending seq/feed machine:
-- tokenize() takes one already-complete string handed to it once, at <CR>
-- time, rather than a per-keystroke incremental state machine — the same
-- "shares nothing, never on the same call path" test that split
-- patterns_insert.lua out in #99 (see lua/tobira/CLAUDE.md's "Module
-- splitting policy"). The vim.fn.getcmdtype()/getcmdline() orchestration
-- that decides *when* to call tokenize() lives in logger.lua instead, which
-- already does vim.* work — this file stays pure and independently testable.
--
-- Deliberately NOT a full Vim range-grammar parser: strip_range() below
-- covers the address forms actually seen in practice (%, N, N,M, '<,'>,
-- 'a,'b, /pat/,/pat2/) well enough to reach the command word in each, rather
-- than reimplementing Ex's entire address grammar for forms nobody uses.
--
-- Deliberately does NOT canonicalize Vim's command abbreviations (e.g. 's'
-- vs 'su' vs 'sub' vs 'substitute' all meaning :substitute). Keying by the
-- literal typed word avoids silently guessing wrong on genuinely ambiguous
-- short forms (Vim's own abbreviation-disambiguation rules require knowing
-- every command name to find the shortest unique prefix — reimplementing
-- that table is a lot of surface area for a case the acceptance criteria
-- don't require). This means ':s' and ':sub' are tracked as two distinct
-- buckets ('ex:s' / 'ex:sub') rather than merging into one; revisit if usage
-- data ever shows that matters for suggestion quality.

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

-- ── Repeated-substitute detection (#115) ────────────────────────────────────
--
-- M.track_substitute(state, text, line) is a second pure function alongside
-- tokenize(). Where tokenize() only extracts the semantic command NAME
-- ('ex:s') and discards everything else by design, this function parses the
-- actual `:s/{pattern}/{replacement}/{flags}` BODY so identical manual
-- substitutions across different lines can be detected and answered with a
-- suggestion to use `&` (repeat on this line) or `g&` (repeat file-wide)
-- instead. It is stateful across calls (unlike tokenize()) — state is
-- created via M.new_substitute_state() and is expected to live for an
-- entire editing session, the same lifetime as logger.lua's `seq`.
--
-- Deliberate scope limits (documented here rather than silently guessed):
--
-- 1. Only a BARE (no explicit range) `:s` is tracked. strip_range() above is
--    reused to detect a range prefix; if anything was stripped, this
--    function returns nil. Rationale: the workflow this feature targets is
--    "move the cursor to another line, retype the same :s/// there" — the
--    target line is then unambiguously the cursor line at <CR> time (the
--    caller passes vim.fn.line('.')). An explicit range (:5s, :%s, :2,10s)
--    is a different, already one-shot workflow (a range already covers
--    every line it needs to in one command), and extracting "the line this
--    ran on" from an arbitrary range expression adds parsing complexity for
--    a case that does not represent the repeated-manual-edit pattern this
--    issue is about.
--
-- 2. Command-word recognition accepts any prefix of "substitute" (s, su,
--    sub, ..., substitute) — unlike tokenize()'s header comment (which
--    deliberately avoids canonicalizing Vim abbreviations in general because
--    disambiguating short prefixes correctly requires knowing every Vim
--    command name), :substitute's abbreviation is a safe special case here:
--    every prefix of "substitute" checked against the literal string
--    "substitute" cannot collide with other commands that merely also start
--    with 's' (:sort, :set, :split, ...), because those diverge from
--    "substitute"'s spelling well before the ambiguity Vim itself has to
--    resolve. This function only needs to recognize ITS OWN command, not
--    disambiguate the general abbreviation table.
--
-- 3. The delimiter is whatever single character immediately follows the
--    command word (Vim allows any character except alphanumerics, '\', '"'
--    and '|' — see :help :s — this mirrors that restriction). Escaped
--    delimiters (`\/` inside the pattern) are honored when scanning for the
--    boundary, same escaping rule strip_range() already applies to search
--    addresses.
--
-- 4. The trailing delimiter after the replacement is optional (":s/foo/bar"
--    is valid Vim syntax, matching ":s/foo/bar/"). Whatever follows a
--    present trailing delimiter (flags, a count) is intentionally ignored
--    for the equality comparison — the acceptance criteria is "identical
--    pattern AND replacement", not "identical flags too" (a user toggling
--    the `g` flag between runs of an otherwise-identical substitution is
--    still the same edit being manually repeated).
--
-- 5. A missing closing delimiter for the PATTERN (":s/foo" with only one
--    delimiter total) and an empty explicit pattern (":s//bar/", which
--    reuses whatever the last search pattern happened to be) are both
--    treated as unparseable / not trackable — comparing "the same pattern"
--    requires literal pattern text to compare, and neither case provides it
--    without silently guessing at implicit state this pure module does not
--    have access to.
--
-- Threshold heuristic for `&` vs `g&`:
--
-- The SAME (pattern, replacement) pair reaching a 2nd distinct line fires
-- `&` (the acceptance criteria's minimum: "two different lines"). Reaching
-- a 3rd distinct line upgrades to `g&` instead of firing `&` again — three
-- separate manual repeats of the identical edit is treated as strong enough
-- evidence that the change belongs on every matching line, not just the
-- next one. Distinct LINE COUNT (not line-number distance, e.g. "50 lines
-- apart") was chosen as the "spans enough of the file" signal because this
-- module is pure and has no access to the buffer's total line count or
-- window context to judge relative distance — a count-based threshold is
-- fully self-contained and easy to reason about/test, at the cost of not
-- distinguishing "3 adjacent lines" from "3 lines scattered across a large
-- file" (both fire `g&` alike). Each (pattern, replacement) key only ever
-- fires once at count==2 and once at count==3; further distinct lines are
-- silent, mirroring patterns.lua's precedent of exact-count (not
-- threshold-or-above) firing (see e.g. x_repeat/j_repeat in patterns.lua).
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
