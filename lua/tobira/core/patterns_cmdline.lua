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

return M
