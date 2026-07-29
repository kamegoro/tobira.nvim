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

-- Argument-aware counterpart to tokenize() (#113/#114): tokenize()
-- deliberately discards everything after the command word (see its header
-- comment — #57's scope never needed it), but two later detectors need the
-- argument text itself: #113's tabnew one-tab-per-file streak needs to tell a
-- bare ":tabnew" apart from ":tabnew foo.txt", and #114's ex_file_pingpong
-- detector needs the filename argument to tell ":e A" apart from ":e B".
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
-- the same two files via :e/:b — :e A -> :e B -> :e A (or the equivalent
-- with :b) — is a direct signal for <C-^>, which jumps straight to the
-- alternate file in one keystroke. New state kept in this same file rather
-- than a new sibling one: per lua/tobira/CLAUDE.md's module-splitting
-- policy, the deciding question is call path, not shared state, and this is
-- fed from the exact same place tokenize()/command_arg() are (logger.lua's
-- handle_cmdline_key, at <CR> time) even though it shares no actual state
-- with either.
--
-- Deliberately literal command words only ('e', 'b'), not abbreviation
-- expansion (:edit, :ed, :buffer, :bu, ...) -- tokenize() above makes the
-- same "no abbreviation table" call for the same reason (see its header):
-- this feature's acceptance criteria only exercise :e/:b directly, and
-- reimplementing Vim's abbreviation-disambiguation table is a lot of surface
-- area this feature doesn't need. Revisit if usage data ever shows real
-- users typing :edit/:buffer for this specific habit.
--
-- Coexistence with other <C-^> triggers: this is deliberately one signal
-- among potentially several that can all suggest the same '<C-^>' command
-- (e.g. a hypothetical :tabnew-habit-based trigger) -- pattern.cmd is just
-- '<C-^>' like any other reactive pattern, so on_pattern/suggest.lua need no
-- special-casing to let two independent detectors share one suggested
-- command; commands.lua has exactly one '<C-^>' registry entry regardless of
-- how many patterns can recommend it. The only per-trigger difference is the
-- "why am I seeing this" reason line: 'ex_file_pingpong' gets its own
-- locales/*.lua float.reasons entry distinct from any other trigger's,
-- while the suggestion's title/body/example (locales/*.lua
-- suggestions['<C-^>']) stay shared, since what the command DOES doesn't
-- change based on how tobira noticed you needed it.
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

-- ── tabnew one-file-per-tab habit detection (#113) ──────────────────────────
-- A second, independent state machine in this same file — new_tabnew_seq()
-- and feed_tabnew() share no state with M.tokenize() above, but stay here
-- rather than moving to a new sibling file because they operate on the exact
-- same signal, from the exact same call site: the tokenized Ex-command name
-- at <CR> time, inside logger.lua's handle_cmdline_key (see
-- lua/tobira/CLAUDE.md's "Module splitting policy" — same call path is the
-- test for staying in one file, not line count). A fourth patterns_*.lua
-- file would separate two things that both fire from the same cmdline-<CR>
-- event for no isolation benefit.
--
-- Detects "tabs as a VSCode-style file browser": opening a new file with
-- :tabnew, one tab per file, 3+ times in a row with no window splits in
-- between, and suggests switching to buffer commands (:b / <C-^>) instead —
-- see commands.lua's '<C-^>' entry, which this reuses rather than
-- duplicating (it already exists, tracked, with no reactive trigger of its
-- own — see #113's issue notes).
--
-- feed_tabnew() is called only for ":tabnew" submissions (logger.lua checks
-- M.tokenize()'s result before calling it — an unrelated Ex command is a
-- complete no-op for this streak, not a reset, since it says nothing about
-- window layout either way). Evidence passed in at each call:
--
--   arg: the trimmed file argument text (the second return value of
--     M.command_arg, converted from nil to '' by the caller — see
--     logger.lua), or '' when :tabnew was given no argument at all — a bare
--     ":tabnew" opens
--     an empty scratch tab, not "one more file browsed", so it resets the
--     streak rather than silently ignoring it: the user just demonstrated
--     they are not currently doing the file-per-tab thing.
--
--     A non-empty arg only advances the streak the FIRST time that exact
--     filename is seen among the tabs opened so far in the current streak
--     (tracked in seq.files). This feature's own name is "one-tab-per-FILE"
--     — Vim reuses the existing buffer when you :tabnew a file that is
--     already open elsewhere, so there is only ever 1 real buffer behind a
--     repeated filename, which makes the ":b" / "<C-^>" suggestion this
--     streak leads to nonsensical (bug reported by QA: opening the same
--     file 3x via :tabnew used to fire the suggestion anyway, because the
--     pre-fix version only tracked whether *some* argument was given, never
--     which one). A repeat RESETS the streak (like the bare-:tabnew case
--     above) rather than merely being ignored: re-opening a file you already
--     have open in another tab is a different, unrelated habit — evidence
--     the user is not (right now) doing one-tab-per-file browsing — not
--     neutral evidence that deserves to be skipped over. The repeat itself
--     is not retroactively counted as the first file of a new streak either,
--     for the same reason a bare :tabnew doesn't count itself: it isn't a
--     new file being browsed.
--
--   win_count: the window count of the CURRENT tabpage, read by the caller
--     via vim.api.nvim_tabpage_list_wins (logger.lua — patterns_cmdline.lua
--     itself stays vim.*-free, same threading pattern as patterns.lua's
--     is_diff/now parameters). Because vim.on_key's callback fires BEFORE
--     this <CR> keystroke's effect lands (the same timing M.tokenize()'s
--     caller already relies on — see logger.lua's comment on
--     handle_cmdline_key), "current tabpage" at this moment is still the tab
--     the PREVIOUS :tabnew in the streak opened, not the one this keystroke
--     is about to create — exactly the tab that needs checking. Meaningless
--     before the first :tabnew of a streak (seq.streak == 0, nothing yet to
--     verify); callers may pass any value in that case.
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

return M
