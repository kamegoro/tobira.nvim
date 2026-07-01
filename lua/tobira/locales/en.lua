return {
  guide = {
    title = 'tobira guide',
    hint = ':TobiraGuide  toggle guide',
    all_mastered = 'All commands at this level mastered!',
    pinned = 'Pinned',
    contexts = {
      default = {
        {
          title = 'Motion',
          items = {
            {
              keys = 'h j k l',
              desc = 'move cursor',
              track = { 'h', 'j', 'k', 'l' },
              threshold = 100,
              upgrade = { keys = '<C-d> / <C-u>', desc = 'scroll half page' },
            },
            {
              keys = 'w / b',
              desc = 'next / prev word',
              track = { 'w', 'b' },
              threshold = 40,
              upgrade = { keys = 'e / ge', desc = 'word end (fwd / back)' },
            },
            { keys = '0 / $', desc = 'line start / end' },
            { keys = 'gg / G', desc = 'file top / bottom' },
            {
              keys = 'f{char}',
              desc = 'jump to character',
              track = { 'f' },
              threshold = 15,
              upgrade = { keys = ';', desc = 'repeat last f/t/F/T' },
            },
            { keys = '<C-o> / <C-i>', desc = 'jump back / forward' },
          },
        },
        {
          title = 'Edit',
          items = {
            {
              keys = 'i',
              desc = 'insert mode',
              track = { 'i' },
              threshold = 40,
              upgrade = { keys = 'a / o / O', desc = 'append / new line' },
            },
            { keys = 'Esc', desc = 'back to normal mode' },
            {
              keys = 'x',
              desc = 'delete character',
              track = { 'x' },
              threshold = 20,
              upgrade = { keys = 'r{char}', desc = 'replace (no insert mode)' },
            },
            { keys = 'dd', desc = 'delete line' },
            { keys = 'yy / p', desc = 'copy / paste line' },
            { keys = 'u / <C-r>', desc = 'undo / redo' },
          },
        },
        {
          title = 'File',
          items = {
            { keys = ':w', desc = 'save' },
            { keys = ':q', desc = 'quit' },
            { keys = ':wq', desc = 'save and quit' },
            { keys = '<C-^>', desc = 'toggle last file' },
          },
        },
        {
          title = 'Search',
          items = {
            { keys = '/{text}', desc = 'search' },
            { keys = 'n / N', desc = 'next / prev match' },
          },
        },
      },

      neo_tree = {
        {
          title = 'Navigate',
          items = {
            { keys = 'j / k', desc = 'move cursor' },
            { keys = 'l / Enter', desc = 'open / expand' },
            { keys = 'h', desc = 'collapse node' },
            { keys = '<BS>', desc = 'go to parent directory' },
          },
        },
        {
          title = 'Operations',
          items = {
            { keys = 'a', desc = 'new file or directory' },
            { keys = 'd', desc = 'delete' },
            { keys = 'r', desc = 'rename' },
            { keys = 'y / x / p', desc = 'copy / cut / paste' },
          },
        },
        {
          title = 'View',
          items = {
            { keys = 'H', desc = 'toggle hidden files' },
            { keys = '/', desc = 'fuzzy search' },
            { keys = 'q', desc = 'close tree' },
          },
        },
      },
    },
  },
  progress = {
    title = 'tobira — your vim journey',
    level_label = 'Level: ',
    levels = {
      novice = 'novice',
      beginner = 'beginner',
      intermediate = 'intermediate',
      advanced = 'advanced',
    },
    next = 'Next: ',
    hint = '[q / Esc]  close',
    categories = {
      motion = 'Motion',
      edit = 'Edit',
      search = 'Search',
      window = 'Window',
      fold = 'Fold',
      mark = 'Mark',
      macro = 'Macro',
    },
  },
  notifications = {
    reset = 'tobira: usage log reset',
    no_suggestions = 'tobira: no new suggestions right now 🎉',
    invalid_config = 'tobira: invalid config — ',
  },
  stats = {
    title = 'tobira — usage stats',
    total_keystrokes = 'Total keystrokes',
    discovered = 'Discovered',
    mastery = 'Mastery',
    mastery_dist = '  Never %d  ·  ☆ %d  ·  ★ %d  ·  ★★+ %d',
    top_commands = 'Top commands',
    try_next = '⚡ Try these next',
  },
  float = {
    example_prefix = 'e.g. ',
  },
  -- Suggestion display strings shown via float popup and :TobiraProgress.
  -- Keys match commands.registry keys exactly.
  suggestions = {
    [';'] = {
      title = '; — repeat the last f / t / F / T',
      body = 'After any f, t, F, or T search, ; jumps to the next occurrence in the same direction\n, goes in the reverse direction',
      example = 'fa ;; → next a, then the next',
    },
    [','] = {
      title = ', — repeat f / t / F / T in reverse',
      body = 'The opposite of ; — repeats the last f/t/F/T search in the reverse direction\nUseful when you overshoot with ;',
      example = 'fa ;;; , → jump back one',
    },
    ['cw'] = {
      title = 'cw — delete word and insert',
      body = 'Replaces the dw + i sequence in one motion\nDrops you into insert mode immediately after deleting',
      example = 'cw → deletes from cursor to end of word → insert mode',
    },
    ['ciw'] = {
      title = 'ciw — change inner word',
      body = 'Works even when cursor is in the middle of a word\ncw only deletes from cursor forward; ciw replaces the whole word',
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title = '<C-r> — redo',
      body = 'Undid too much? <C-r> redoes the last undone change\nPair with u / <C-r> to navigate change history',
      example = 'u u u <C-r> → undo 3 times, redo once',
    },
    ['ddp'] = {
      title = 'ddp — swap current line with the next',
      body = 'dd deletes the line, p pastes it below — ddp swaps lines in one go\nNo need to navigate between the two lines',
      example = 'ddp → current line moves down one',
    },
    ['{n}j'] = {
      title = '{n}j — jump multiple lines at once',
      body = 'Prefix any motion with a count to repeat it\n5j moves down 5 lines; also works with k, w, b, etc.',
      example = '5j → moves down 5 lines',
    },
    ['^'] = {
      title = '^ — jump to first non-blank character',
      body = '0 goes to column 0; ^ goes to the first non-whitespace character\nUsually ^ is what you actually want',
      example = '    hello → ^ → cursor lands on h',
    },
    ['cgn'] = {
      title = 'cgn — change next search match',
      body = 'After /, use cgn to change the next match\nThen press . to repeat on every subsequent match',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title = '. — repeat the last change',
      body = 'Repeats your last edit without re-entering insert mode\nCombine with n or ; to change multiple occurrences in one pass',
      example = 'cw foo <Esc> n . → changes the next match too',
    },
    ['A'] = {
      title = 'A — append at end of line',
      body = '$a in one keystroke — moves to end of line and enters insert\nPair with I (insert at start) for quick line start / end editing',
      example = 'A; → add a semicolon at end of line',
    },
    ['O'] = {
      title = 'O — open a new line above',
      body = 'Like o but opens the new line above the cursor\nNo need to move up first then press o',
      example = 'O → new blank line above cursor → insert mode',
    },
    ['D'] = {
      title = 'D — delete to end of line',
      body = 'Deletes from cursor to end of line (same as d$)\nLets you retype the rest without navigating there first',
      example = 'D → type the new ending',
    },
    ['C'] = {
      title = 'C — change to end of line',
      body = 'D + i in one motion — deletes to EOL and enters insert\nLike cw but for the rest of the line instead of one word',
      example = 'C → replace everything from cursor to end',
    },
    ['gn'] = {
      title = 'gn — select next search match',
      body = 'After * or /, gn selects the next match in visual mode\nUsed with c (cgn) then . to replace every occurrence',
      example = '* → cgn → new text → Esc → . . .',
    },
    ['e'] = {
      title = 'e — move to end of word',
      body = 'w jumps to the start of the next word; e jumps to its end\nUseful when you need to append to the end of a word',
      example = 'ea → append text after the current word',
    },
    ['I'] = {
      title = 'I — insert at start of line',
      body = 'Moves to the first non-blank character and enters insert mode\nPair with A (end of line) for quick line-edge edits',
      example = 'I// → comment out the current line',
    },
    ['H'] = {
      title = 'H — jump to top of screen',
      body = 'Moves cursor to the top of the visible window without scrolling\nM goes to middle, L goes to bottom',
      example = 'H → cursor lands on the first visible line',
    },
    ['M'] = {
      title = 'M — jump to middle of screen',
      body = 'Places cursor in the exact middle of the visible window\nUseful for quickly reorienting after a large jump',
      example = 'M → cursor moves to the middle line',
    },
    ['L'] = {
      title = 'L — jump to bottom of screen',
      body = 'Moves cursor to the last visible line without scrolling\nPair with H and M for screen-relative navigation',
      example = 'L → cursor lands on the last visible line',
    },
    ['{n}x'] = {
      title = '{n}x — delete multiple characters at once',
      body = 'Prefix x with a count to delete that many characters in one go\nAlso works with other motions: 3dw, 2dd, etc.',
      example = '5x → deletes 5 characters at cursor',
    },
    ['<C-d>'] = {
      title = '<C-d> — scroll half a page down',
      body = 'Moves the view and cursor down by half the window height\nMuch faster than pressing j many times',
      example = '<C-d><C-d> → scroll down a full page',
    },
    ['<C-u>'] = {
      title = '<C-u> — scroll half a page up',
      body = 'The upward complement of <C-d>\nPair them to navigate large files efficiently',
      example = '<C-d> then <C-u> → scroll down and back up',
    },
    ['{n}k'] = {
      title = '{n}k — jump multiple lines up at once',
      body = 'Prefix k with a count to move up several lines in one go\nWorks with any motion: 5k, 3w, 2b, etc.',
      example = '5k → moves up 5 lines',
    },
    ['*'] = {
      title = '* — search the word under the cursor',
      body = 'Puts the word under the cursor into the search register and jumps to the next match\nFaster than typing /word<Enter> — no need to type anything',
      example = 'cursor on "foo" → * → jumps to the next "foo"',
    },
    ['<C-o>'] = {
      title = '<C-o> — jump back to where you were',
      body = 'After a large jump (* / G gg /) <C-o> takes you back to the previous position\n<C-i> goes forward again through the jump list',
      example = '* <C-o> → jump to match, then return to start',
    },
    ['P'] = {
      title = 'P — paste before the cursor',
      body = 'p pastes after the cursor; P pastes before it\nFor linewise yanks: p pastes below the line, P pastes above it',
      example = 'yy P → copy the current line and paste it above',
    },

    -- ── f → t stop-before-char chain ─────────────────────────────────────
    ['t'] = {
      title = 't — move to just before a character',
      body = 'Like f but stops one character before the target\nIdeal for operators: ct; changes text up to (not including) the next ;',
      example = 'ct; → change everything up to the next semicolon',
    },
    ['T'] = {
      title = 'T — move to just after a character (backward)',
      body = 'Searches backward like F but stops just after the character\nRepeat with ; and , like any f/t search',
      example = 'T, → move back to just after the previous comma',
    },

    -- ── jumplist bidirectional ─────────────────────────────────────────────
    ['<C-i>'] = {
      title = '<C-i> — jump forward in the jump list',
      body = 'After <C-o> takes you back, <C-i> brings you forward again\nNavigate your editing history in both directions',
      example = '<C-o> <C-o> <C-i> → go back twice, then forward once',
    },

    -- ── full-page scroll chain ─────────────────────────────────────────────
    ['<C-f>'] = {
      title = '<C-f> — scroll a full page down',
      body = '<C-d> scrolls half a page; <C-f> scrolls a full page\nFaster for jumping over large sections of a file',
      example = '<C-f> → scroll down one full window height',
    },
    ['<C-b>'] = {
      title = '<C-b> — scroll a full page up',
      body = 'The upward complement of <C-f>\nPair with <C-f> to scan a large file quickly in both directions',
      example = '<C-f> <C-b> → scroll down a full page then back up',
    },

    -- ── paragraph motions ─────────────────────────────────────────────────
    ['}'] = {
      title = '} — jump to end of paragraph',
      body = 'Moves down to the next blank line — skips entire blocks at once\nFaster than j when moving between functions or text sections',
      example = '} → cursor jumps to the blank line after the current block',
    },
    ['{'] = {
      title = '{ — jump to start of paragraph',
      body = 'The upward complement of } — moves up to the blank line above\nQuickly navigate between code blocks or paragraphs',
      example = '{ → cursor jumps to the blank line before the current block',
    },

    -- ── screen centering chain ─────────────────────────────────────────────
    ['zz'] = {
      title = 'zz — center the screen on the cursor',
      body = 'Scrolls the view so the cursor line sits in the middle of the window\nCursor does not move — only the visible area shifts',
      example = 'zz → current line scrolls to the center of the window',
    },
    ['zt'] = {
      title = 'zt — scroll cursor line to top of screen',
      body = 'Like zz but places the cursor line at the top of the window\nzt / zz / zb give you top / center / bottom control',
      example = 'zt → current line scrolls to the top of the window',
    },
    ['zb'] = {
      title = 'zb — scroll cursor line to bottom of screen',
      body = 'Scrolls so the cursor line appears at the bottom of the window\nPair with zt and zz to position exactly what you see',
      example = 'zb → current line scrolls to the bottom of the window',
    },

    -- ── WORD motions ──────────────────────────────────────────────────────
    ['W'] = {
      title = 'W — move forward by WORD',
      body = 'Like w but only stops at whitespace, ignoring punctuation\nUseful when w stops too often inside things like "foo.bar(baz)"',
      example = 'W on "foo.bar.baz" → jumps over the whole token at once',
    },
    ['B'] = {
      title = 'B — move backward by WORD',
      body = 'Like b but treats punctuation-connected text as one WORD\nThe backward complement of W',
      example = 'B on "foo.bar.baz" → jumps back over the whole token',
    },

    -- ── word-end backward ─────────────────────────────────────────────────
    ['ge'] = {
      title = 'ge — move to end of previous word',
      body = 'e moves forward to word end; ge moves backward to the end of the previous word\nUseful when you need to append to the word behind the cursor',
      example = 'gea → move to end of previous word then append text',
    },

    -- ── bracket matching ──────────────────────────────────────────────────
    ['%'] = {
      title = '% — jump to matching bracket',
      body = 'Jumps between matching (, [, {, and their closing counterparts\nAlso works with /* */ and #if/#endif in many filetypes',
      example = '% on ( → cursor jumps to the matching )',
    },

    -- ── single-char edit shortcuts ────────────────────────────────────────
    ['r'] = {
      title = 'r — replace a single character',
      body = 'Replaces the character under the cursor without entering insert mode\nFaster than x + i + char for single-character typo fixes',
      example = 'ra → replace the character under the cursor with a',
    },
    ['s'] = {
      title = 's — substitute character and insert',
      body = 'Deletes the character under the cursor and immediately enters insert mode\nOne keystroke instead of x + i',
      example = 's → deletes current character → insert mode begins',
    },
    ['cc'] = {
      title = 'cc — change the entire current line',
      body = 'Clears the line content and enters insert mode in one motion\nFaster than going to line start, pressing D, then entering insert',
      example = 'cc → line is cleared → insert mode',
    },

    -- ── join lines ───────────────────────────────────────────────────────
    ['J'] = {
      title = 'J — join the next line onto the current one',
      body = 'Appends the line below to the current line with a single space\nNo need to go to end of line, delete the newline, and add a space',
      example = 'J → "foo\\n  bar" becomes "foo bar" (indentation stripped)',
    },

    -- ── case toggle ───────────────────────────────────────────────────────
    ['~'] = {
      title = '~ — toggle case of the character under cursor',
      body = 'Flips lowercase to uppercase and vice versa, then advances one character\nPrefix with a count: 3~ toggles the next 3 characters at once',
      example = '~ on "hello" → "Hello" → cursor advances',
    },

    -- ── number increment / decrement ──────────────────────────────────────
    ['<C-a>'] = {
      title = '<C-a> — increment the number under the cursor',
      body = 'Finds the next number on the line and adds one to it\nPrefix with a count to add more: 5<C-a> adds 5',
      example = '<C-a> on "padding: 8px" → "padding: 9px"',
    },
    ['<C-x>'] = {
      title = '<C-x> — decrement the number under the cursor',
      body = 'The downward complement of <C-a> — subtracts one from the next number\nUseful for adjusting numeric values without manual retyping',
      example = '<C-x> on "z-index: 10" → "z-index: 9"',
    },

    -- ── visual mode chain ─────────────────────────────────────────────────
    ['V'] = {
      title = 'V — start line-wise visual selection',
      body = 'Selects entire lines rather than individual characters\nIdeal for moving, copying, or deleting whole lines with visual feedback',
      example = 'Vjjd → visually select 3 lines then delete them',
    },
    ['<C-v>'] = {
      title = '<C-v> — start block (column) visual selection',
      body = 'Selects a rectangular block across multiple lines\nPowerful for editing aligned columns — prepend text, change values in bulk',
      example = '<C-v>3jI// <Esc> → prepend // to 4 lines at once',
    },

    -- ── yank text object ──────────────────────────────────────────────────
    ['yiw'] = {
      title = 'yiw — yank the inner word',
      body = 'Copies the whole word under the cursor regardless of cursor position within it\nPair with ciw (change) and diw (delete) for consistent word-level editing',
      example = 'yiw then move to target word then ciw p → replace word',
    },

    -- ── macros ────────────────────────────────────────────────────────────
    ['q'] = {
      title = 'q — record a macro',
      body = 'q{a} starts recording into register a; press q again to stop\n@{a} replays it; @@ repeats the last macro — automate repetitive edits',
      example = 'qaIhello<Esc>q then @a → insert "hello" at line start on replay',
    },

    -- ── backward search pair ──────────────────────────────────────────────
    ['N'] = {
      title = 'N — jump to previous search match',
      body = 'n jumps forward to the next match; N jumps backward to the previous one\nChange direction at any time without retyping the search pattern',
      example = '/foo → nnn N → forward 3 matches then back one',
    },
    ['#'] = {
      title = '# — search backward for word under cursor',
      body = '* searches forward for the word under cursor; # searches backward\nInstantly locate all occurrences without typing the search term',
      example = 'cursor on "foo" → # → jumps to the previous occurrence of "foo"',
    },

    -- ── G → gg ───────────────────────────────────────────────────────────
    ['gg'] = {
      title = 'gg — jump to the first line of the file',
      body = 'G jumps to the end of the file; gg jumps to the beginning\nPrefix with a number: 5gg jumps directly to line 5',
      example = 'gg → cursor lands on line 1',
    },

    -- ── wrapped-line movement ─────────────────────────────────────────────
    ['gj'] = {
      title = 'gj — move down one visual (display) line',
      body = 'When lines are wrapped, j skips the entire wrapped line; gj moves one display row\nEssential for editing long prose or markdown with wrapping enabled',
      example = 'gj on a wrapped paragraph → cursor moves to the next screen row',
    },
    ['gk'] = {
      title = 'gk — move up one visual (display) line',
      body = 'The upward complement of gj — moves one display row when lines are wrapped\nPair gj / gk for natural movement through wrapped text',
      example = 'gk on a wrapped paragraph → cursor moves to the previous screen row',
    },

    -- ── line-by-line scrolling ────────────────────────────────────────────
    ['<C-e>'] = {
      title = '<C-e> — scroll window up one line without moving cursor',
      body = 'Shifts the visible area up by one line; the cursor stays on the same line\nPair with <C-y> to fine-tune your view without losing your editing position',
      example = '<C-e><C-e> → text scrolls up 2 lines; cursor stays put',
    },
    ['<C-y>'] = {
      title = '<C-y> — scroll window down one line without moving cursor',
      body = 'The downward complement of <C-e> — reveals one more line at the top\nAdjust the visible area without moving your editing position',
      example = '<C-y> → one line scrolls into view at the top of the window',
    },

    -- ── change list navigation ────────────────────────────────────────────
    ['g;'] = {
      title = 'g; — jump to older position in the change list',
      body = 'Every edit you make is added to the change list; g; walks backward through it\nDifferent from the jump list — only positions where text was actually changed',
      example = 'g; g; → jump back to the last two places you edited',
    },
    ['g,'] = {
      title = 'g, — jump to newer position in the change list',
      body = 'After g; takes you back in the change list, g, brings you forward again\nNavigate your editing history in both directions without leaving the file',
      example = 'g; g, → step back to last edit, then step forward again',
    },

    -- ── return to last insert / alternate file / last jump ────────────────
    ['gi'] = {
      title = 'gi — go to last insert position and enter insert mode',
      body = 'Returns the cursor to where you last left insert mode and immediately re-enters it\nSaves navigating back manually after reading another part of the file',
      example = 'gi → cursor jumps to where you last stopped typing → insert mode',
    },
    ['<C-^>'] = {
      title = '<C-^> — switch to the alternate (previously edited) file',
      body = 'Toggles between the current file and the last one you had open\nThe quickest way to flip between two files you are actively working on',
      example = '<C-^> → open last file → <C-^> → back to the first',
    },
    ["''"] = {
      title = "'' — jump back to the line of the previous jump",
      body = "A quick return to the line you were on before the last large navigation\n'' uses line-level precision; `` (backticks) also restores the exact column",
      example = "G '' → jump to end of file, then return to original line",
    },

    -- ── definition / file under cursor ────────────────────────────────────
    ['gd'] = {
      title = 'gd — go to local definition',
      body = 'Searches the current function scope for the first declaration of the word under cursor\nFaster than grepping — no need to leave the file or type a search pattern',
      example = 'cursor on "myVar" → gd → jumps to where myVar is first declared',
    },
    ['gf'] = {
      title = 'gf — edit the file whose name is under the cursor',
      body = 'Opens the filename under the cursor as a new buffer in the current window\nWorks with relative paths, absolute paths, and filenames inside strings',
      example = 'cursor on "utils/helpers.lua" → gf → opens that file',
    },

    -- ── reselect last visual ──────────────────────────────────────────────
    ['gv'] = {
      title = 'gv — reselect the previous visual selection',
      body = 'Reactivates the exact same visual selection from the last time visual mode was used\nSaves time when you need to apply a second operation to the same region',
      example = 'vip y gv d → yank a paragraph, then reselect and delete it',
    },

    -- ── WORD-end backward ─────────────────────────────────────────────────
    ['gE'] = {
      title = 'gE — move to end of the previous WORD',
      body = 'ge moves to end of the previous word; gE does the same but skips all punctuation\nThe WORD-level complement of ge — jumps over "foo.bar.baz" as a single token',
      example = 'gE on foo.bar → jumps to the end of the previous WORD token',
    },

    -- ── fold commands ─────────────────────────────────────────────────────
    ['za'] = {
      title = 'za — toggle fold at cursor',
      body = 'Opens a closed fold or closes an open one under the cursor\nThe most convenient fold command — one key to peek or hide a section',
      example = 'za → unfolds the collapsed block; za again → re-folds it',
    },
    ['zo'] = {
      title = 'zo — open the fold at cursor',
      body = 'Reveals the lines hidden inside a fold without affecting open folds nearby\nUnlike za, zo only opens — it never accidentally closes an already-open fold',
      example = 'zo → hidden lines inside the fold become visible',
    },
    ['zc'] = {
      title = 'zc — close the fold at cursor',
      body = 'Collapses an open fold into a single summary line\nThe inverse of zo — only closes, never opens accidentally',
      example = 'zc → the expanded block collapses to one summary line',
    },
    ['zM'] = {
      title = 'zM — close all folds in the buffer',
      body = 'Collapses every fold in the file at once — gives a full outline view\nUseful for navigating a large file by structure before drilling into a section',
      example = 'zM → all functions collapse → only top-level structure is visible',
    },
    ['zR'] = {
      title = 'zR — open all folds in the buffer',
      body = 'Expands every fold in the file — the reverse of zM\nRestores the fully unfolded view after exploring with fold navigation',
      example = 'zM zR → collapse all folds, then expand everything back',
    },

    -- ── delete before / replace mode / yank to EOL ────────────────────────
    ['X'] = {
      title = 'X — delete the character before the cursor',
      body = 'Deletes one character to the left of the cursor without entering insert mode\nLike pressing Backspace while staying in Normal mode',
      example = 'X → the character immediately left of the cursor is removed',
    },
    ['R'] = {
      title = 'R — enter replace mode',
      body = 'Overwrites existing text character by character as you type — no inserting or shifting\nIdeal for replacing a fixed-width section while keeping surrounding text intact',
      example = 'Rhello → overwrites the next 5 characters with "hello"',
    },
    ['Y'] = {
      title = 'Y — yank from cursor to end of line',
      body = 'Copies the text from the cursor position to the end of the line (same as y$)\nComplements D (delete to EOL) and C (change to EOL) for consistent EOL operations',
      example = 'Y p → copy the rest of the line then paste it below',
    },

    -- ── indent operators ──────────────────────────────────────────────────
    ['>>'] = {
      title = '>> — indent the current line',
      body = 'Shifts the current line right by one shiftwidth level\nPrefix with a count: 3>> indents the next 3 lines at once',
      example = '>> → current line indented by one level',
    },
    ['<<'] = {
      title = '<< — unindent the current line',
      body = 'Shifts the current line left by one shiftwidth level\nThe reverse of >> — use to fix over-indented code',
      example = '<< → current line dedented by one level',
    },
    ['=='] = {
      title = '== — auto-indent the current line',
      body = 'Runs the built-in indenter on the current line according to filetype rules\nFaster than manually correcting with >> or << when indentation is complex',
      example = '== → line snaps to the correct indentation level automatically',
    },

    -- ── case operators ────────────────────────────────────────────────────
    ['gu'] = {
      title = 'gu{motion} — lowercase a region',
      body = 'Applies lowercase to the text covered by the motion\nguiw → lowercase the current word; gu$ → lowercase to end of line',
      example = 'guiw → "Hello" becomes "hello"',
    },
    ['gU'] = {
      title = 'gU{motion} — uppercase a region',
      body = 'The uppercase complement of gu — converts the motion text to ALL CAPS\ngUiw → uppercase the inner word',
      example = 'gUiw → "hello" becomes "HELLO"',
    },
    ['g~'] = {
      title = 'g~{motion} — swap case of a region',
      body = 'Inverts the case of every character in the motion — upper becomes lower and vice versa\nLike applying ~ to an entire motion at once instead of one character at a time',
      example = 'g~iw → "Hello World" becomes "hELLO wORLD"',
    },

    -- ── format text ───────────────────────────────────────────────────────
    ['gq'] = {
      title = 'gq{motion} — reflow / format text to fit line width',
      body = 'Reformats the text covered by the motion to wrap at textwidth\ngqip formats the current paragraph; gqq formats the current line',
      example = 'gqip → current paragraph is reflowed to fit the configured line width',
    },

    -- ── join without space ────────────────────────────────────────────────
    ['gJ'] = {
      title = 'gJ — join lines without inserting a space',
      body = 'Like J but does not add a space between the merged lines\nUseful for joining lines where extra whitespace would break the syntax',
      example = 'gJ → "foo\\n  bar" becomes "foobar" (no space inserted)',
    },

    -- ── repeat last macro ─────────────────────────────────────────────────
    ['@@'] = {
      title = '@@ — repeat the last played macro',
      body = 'Replays whatever macro was most recently run with @{reg}\nSaves typing the register name again when iterating with the same macro',
      example = '@a → run macro a; @@ → run macro a again without specifying "a"',
    },

    -- ── text object chain ─────────────────────────────────────────────────
    ['ci"'] = {
      title = 'ci" — change inner double-quoted string',
      body = 'Deletes the content between the nearest double quotes and enters insert mode\nThe text object i" works with any operator: c, d, y, v',
      example = 'on "hello world" → ci" → content cleared → type replacement',
    },
    ["ci'"] = {
      title = "ci' — change inner single-quoted string",
      body = 'Like ci" but targets single quotes instead of double quotes\nWorks anywhere the cursor is inside a pair of single quotes',
      example = "on 'hello' → ci' → content cleared → type replacement",
    },
    ['cib'] = {
      title = 'cib — change inner parentheses block',
      body = 'Deletes the content inside the nearest () and enters insert mode\nib is the "inner block" text object — same as i( — works inside function calls',
      example = 'on foo(bar, baz) → cib → clears "bar, baz" → type new args',
    },
    ['ciB'] = {
      title = 'ciB — change inner braces block',
      body = 'Targets the content inside the nearest {} block\nB is the "big block" text object; useful for emptying or rewriting a function body',
      example = 'inside a function body → ciB → clears the entire body → insert mode',
    },
    ['cit'] = {
      title = 'cit — change inner HTML / XML tag content',
      body = 'Deletes the text between the nearest matching open and close tags and enters insert mode\nit is the "inner tag" text object — works for any paired tag',
      example = 'on <p>hello</p> → cit → clears "hello" → type new content',
    },
    ['cip'] = {
      title = 'cip — change inner paragraph',
      body = 'Replaces the entire current paragraph (contiguous block of non-blank lines)\nip selects up to but not including the surrounding blank lines',
      example = 'cip → entire current paragraph cleared → insert mode',
    },

    -- ── partial word search ───────────────────────────────────────────────
    ['g*'] = {
      title = 'g* — search forward for partial word under cursor',
      body = '* requires a whole-word match; g* also matches the word as a substring\nUseful when you want "foo" to find "foobar", "football", and "foo" alike',
      example = 'g* on "foo" → matches "foo", "foobar", "fooResult"',
    },
    ['g#'] = {
      title = 'g# — search backward for partial word under cursor',
      body = 'The backward companion of g* — searches for the substring going up through the file\nFinds all occurrences including partial matches like g* but in reverse',
      example = 'g# on "foo" → jumps back to the previous "foo" or "foobar"',
    },

    -- ── window management ─────────────────────────────────────────────────
    ['<C-w>s'] = {
      title = '<C-w>s — split window horizontally',
      body = 'Opens a horizontal split so you can view two parts of a file simultaneously\n<C-w>v creates a vertical split side by side',
      example = '<C-w>s → two horizontal panes; navigate independently in each',
    },
    ['<C-w>v'] = {
      title = '<C-w>v — split window vertically',
      body = 'Opens a vertical split — two panes side by side in the same tab\nPair with <C-w>h and <C-w>l to move between them',
      example = '<C-w>v → two vertical panes; <C-w>l → move to right pane',
    },
    ['<C-w>w'] = {
      title = '<C-w>w — cycle to the next window',
      body = 'Moves focus to the next split in the layout without specifying a direction\nThe quickest way to jump between two panes',
      example = '<C-w>w → focus switches to the next open split',
    },
    ['<C-w>h'] = {
      title = '<C-w>h — move focus to the window on the left',
      body = 'Directional window navigation — moves focus left, like h moves the cursor left\nUse h / j / k / l variants for precise split navigation',
      example = '<C-w>h → cursor moves to the split immediately to the left',
    },
    ['<C-w>j'] = {
      title = '<C-w>j — move focus to the window below',
      body = 'Moves focus downward to the split below the current one\nWorks in both horizontal and mixed split layouts',
      example = '<C-w>j → cursor moves to the split below',
    },
    ['<C-w>k'] = {
      title = '<C-w>k — move focus to the window above',
      body = 'Moves focus upward to the split above the current one\nThe upward complement of <C-w>j',
      example = '<C-w>k → cursor moves to the split above',
    },
    ['<C-w>l'] = {
      title = '<C-w>l — move focus to the window on the right',
      body = 'Moves focus right to the split on the right\nPair with <C-w>h to flip between left and right panes',
      example = '<C-w>l → cursor moves to the split on the right',
    },
    ['<C-w>q'] = {
      title = '<C-w>q — close the current window',
      body = 'Closes the focused split; the buffer itself remains open\nUse :bd to also delete the buffer; :qa to close all splits at once',
      example = '<C-w>q → focused pane closes; remaining pane expands to fill the space',
    },
    ['<C-w>='] = {
      title = '<C-w>= — equalize all window sizes',
      body = 'Resizes all open splits to equal width and height\nA quick reset after splits become unbalanced from manual resizing',
      example = '<C-w>= → all panes snap to equal dimensions',
    },
    ['$'] = {
      title = '$ — jump to end of line',
      body = 'Moves the cursor to the last character of the current line\nPair with ^ (first non-blank) to navigate line edges quickly',
      example = '^ → go to start; $ → jump to end',
    },
    ['g_'] = {
      title = 'g_ — last non-blank character of line',
      body = '$ includes trailing spaces; g_ stops at the last non-blank character\nMore precise than $ when lines have trailing whitespace',
      example = '$ → may land on a space; g_ → stops at last real character',
    },
    ['F'] = {
      title = 'F — find character backward',
      body = 'Like f{char} but searches left instead of right on the current line\n; and , still repeat the search, so you can navigate in both directions',
      example = 'f, → forward to comma; F, → backward to comma',
    },
    ['('] = {
      title = '( — jump to start of sentence',
      body = 'Like { for paragraphs, ( jumps to the beginning of the current sentence\nUseful for navigating prose, comments, and documentation',
      example = '{ → paragraph start; ( → sentence start',
    },
    [')'] = {
      title = ') — jump to start of next sentence',
      body = 'Moves the cursor forward to the beginning of the next sentence\nPair with ( to hop through sentences in both directions',
      example = '( then ) → step forward and backward through sentences',
    },
    ['[['] = {
      title = '[[ — previous function / section',
      body = 'Jumps to the first line of the previous function or section boundary\nFaster than gg + search when navigating a file with many functions',
      example = 'gg → top of file; [[ → previous function start',
    },
    [']]'] = {
      title = ']] — next function / section',
      body = 'Jumps to the first line of the next function or section boundary\nPair with [[ to hop between functions without leaving normal mode',
      example = 'G → end of file; ]] → next function start',
    },
    ['[{'] = {
      title = '[{ — jump to the enclosing {',
      body = 'Jumps backward to the nearest unmatched opening brace\nEssential for quickly reaching the start of a block, function, or struct',
      example = '% → matching bracket; [{ → enclosing block start',
    },
    [']}'] = {
      title = ']} — jump to the enclosing }',
      body = 'Jumps forward to the nearest unmatched closing brace\nPair with [{ to navigate in and out of nested blocks',
      example = '[{ → block start; ]} → block end',
    },
    ['[('] = {
      title = '[( — jump to the enclosing (',
      body = 'Jumps backward to the nearest unmatched opening parenthesis\nUseful inside long function calls, conditions, or multi-line expressions',
      example = '[{ → block; [( → enclosing parenthesis',
    },
    ['])'] = {
      title = ']) — jump to the enclosing )',
      body = 'Jumps forward to the nearest unmatched closing parenthesis\nPair with [( to navigate in and out of nested parentheses',
      example = '[( → open paren; ]) → closing paren',
    },
    ['g0'] = {
      title = 'g0 — first character of screen line',
      body = 'When lines are wrapped, 0 goes to the real line start; g0 goes to the wrapped line start\nUseful when editing long lines with wrap enabled',
      example = 'gj → next visual line; g0 → start of that visual line',
    },
    ['gx'] = {
      title = 'gx — open file or URL under cursor',
      body = 'Opens the file path or URL under the cursor using the system default application\nWorks with http/https URLs, local file paths, and more',
      example = 'gf → edit file in Vim; gx → open in browser or Finder',
    },
    ['<C-]>'] = {
      title = '<C-]> — jump to tag definition',
      body = 'Follows the tag (ctags definition) under the cursor to its declaration\nRequires a tags file; <C-t> or <C-o> jumps back',
      example = 'gd → local definition; <C-]> → ctags definition',
    },
    ['K'] = {
      title = 'K — look up keyword under cursor',
      body = 'Runs the program in keywordprg (default: man) on the word under the cursor\nIn many LSP setups K shows hover documentation instead',
      example = 'gd → go to definition; K → show documentation',
    },
    ['gp'] = {
      title = 'gp — paste and leave cursor after pasted text',
      body = 'Like p but leaves the cursor positioned just after the pasted text\nHandy when you want to continue typing immediately after pasting',
      example = 'p → cursor stays before paste; gp → cursor moves after paste',
    },
    ['gP'] = {
      title = 'gP — paste before and leave cursor after pasted text',
      body = 'Like P (paste before cursor) but moves the cursor to just after the pasted text\nThe uppercase complement of gp',
      example = 'P → paste before, cursor before; gP → paste before, cursor after',
    },
    ['@:'] = {
      title = '@: — repeat last command-line command',
      body = 'Repeats the most recently executed : command without retyping it\nAfter @: you can use @@ to repeat it again',
      example = ':s/foo/bar/ then @: → repeat the substitution',
    },
    ['zj'] = {
      title = 'zj — move to start of next fold',
      body = 'Moves the cursor downward to the beginning of the next closed or open fold\nFaster than scrolling past folds when navigating a heavily folded file',
      example = 'za → toggle fold; zj → jump to next fold',
    },
    ['zk'] = {
      title = 'zk — move to end of previous fold',
      body = 'Moves the cursor upward to the end of the previous fold\nPair with zj to hop between folds in either direction',
      example = 'zj → next fold; zk → previous fold',
    },
    ['zd'] = {
      title = 'zd — delete fold at cursor',
      body = 'Removes the fold definition under the cursor without affecting the text\nUseful for cleaning up manual folds created with zf',
      example = 'zc → close fold; zd → delete that fold definition',
    },
    ['E'] = {
      title = 'E — forward to end of WORD',
      body = 'Like e but jumps to the end of the next WORD (any non-whitespace sequence)\nIgnores punctuation boundaries that e would stop at',
      example = 'e → end of word; E → end of WORD (skips punctuation)',
    },
    ['U'] = {
      title = 'U — undo all changes on current line',
      body = 'Restores the current line to how it was when you moved onto it\nDifferent from u: U undoes all edits on one line in one shot',
      example = 'u → undo last change; U → restore entire line',
    },
    ['ZZ'] = {
      title = 'ZZ — write and quit',
      body = 'Saves the file and closes the window in one keystroke\nEquivalent to :wq but faster to type',
      example = ':wq  or  ZZ — same result, ZZ saves two keystrokes',
    },
    ['ZQ'] = {
      title = 'ZQ — quit without writing',
      body = 'Closes the window and discards changes without a confirmation prompt\nEquivalent to :q! but faster to type',
      example = 'ZZ → save and quit; ZQ → quit and discard changes',
    },
    ['q:'] = {
      title = 'q: — open command-line window',
      body = 'Opens a buffer containing your Ex command history\nYou can edit and re-run any previous command with Enter',
      example = 'q → record macro; q: → browse & edit command history',
    },
    ['|'] = {
      title = '| — move to column N',
      body = 'Jumps the cursor to column N in the current line\nUseful for aligning text or navigating to a known column position',
      example = '0 → column 1; 40| → column 40',
    },
    ['_'] = {
      title = '_ — first non-blank of line (relative)',
      body = 'Moves to the first non-blank character of the current line\nWith a count N, moves N-1 lines down then goes to first non-blank',
      example = '^ → first non-blank; 3_ → first non-blank 2 lines down',
    },

    -- ── fold: additional commands ─────────────────────────────────────────
    ['zf'] = {
      title = 'zf — create a fold manually',
      body = 'Creates a fold over a motion or visual selection (requires foldmethod=manual)\nUse zd to delete it; zf{motion} folds whatever the motion covers',
      example = 'zfip → fold current paragraph; zd → delete that fold',
    },

    -- ── macro: play specific register ────────────────────────────────────
    ['@q'] = {
      title = '@q — play macro from register q',
      body = 'Replays the sequence of keystrokes recorded in register q\nReplace q with any letter a-z to play from a different register',
      example = 'qq → start recording; q → stop; @q → replay',
    },

    -- ── marks ─────────────────────────────────────────────────────────────
    ["'."] = {
      title = "'. — jump to last change position",
      body = 'Moves the cursor to the exact position of the most recent edit\nFaster than using Ctrl-O repeatedly when you need to return to your last change',
      example = "G then '. → jump to end, return to where you last edited",
    },
    ["'^"] = {
      title = "'^ — jump to last insert position",
      body = "Returns the cursor to the position where you last left insert mode\nDifferent from '. — tracks where you exited insert, not the last text change",
      example = "A then <Esc> then '^ → jump back to end-of-line insert point",
    },
    ['ma'] = {
      title = 'ma — set mark a at cursor',
      body = "Sets a named mark 'a' at the current position\nUse any lowercase letter a-z; retrieve it with 'a (line) or `a (exact column)",
      example = "ma → mark here; G → go somewhere; 'a → jump back to marked line",
    },
    ["'a"] = {
      title = "'a — jump to mark a",
      body = "Moves the cursor to the line where mark 'a' was set\nUse backtick `a for column-precise jumps; combine with ma for navigation anchors",
      example = "ma → mark; dd → edit elsewhere; 'a → return to marked line",
    },

    -- ── l → w / h → b word motion (detected by l_repeat / h_repeat) ──────────
    ['w'] = {
      title = 'w — move to the start of the next word',
      body = 'Jumps forward one word at a time rather than one character at a time\nFaster than pressing l repeatedly — use w to move by word, l to fine-tune position',
      example = 'w w w → advance three words forward',
    },
    ['b'] = {
      title = 'b — move to the start of the previous word',
      body = 'Jumps backward one word at a time — the complement of w\nFaster than pressing h repeatedly when moving left several words',
      example = 'b b b → move back three words',
    },

    -- ── count prefix variants ─────────────────────────────────────────────────
    ['{n}dd'] = {
      title = '{n}dd — delete multiple lines at once',
      body = 'Prefix dd with a count to delete that many lines in one command\n3dd deletes 3 lines starting from the cursor — no need to repeat dd',
      example = '3dd → deletes 3 lines at once',
    },
    ['{n}p'] = {
      title = '{n}p — paste multiple times at once',
      body = 'Prefix p with a count to paste the same content N times in a row\n3p pastes the yanked text 3 times — faster than pressing p repeatedly',
      example = '3p → paste the same content 3 times',
    },
    ['{n}P'] = {
      title = '{n}P — paste above the cursor multiple times',
      body = 'P pastes before the cursor; prefix with a count to repeat it\n3P pastes the yanked text 3 times above the current line',
      example = '3P → paste 3 times above the cursor',
    },
    ['{n}~'] = {
      title = '{n}~ — toggle case of multiple characters',
      body = '~ toggles one character and advances; prefix with a count to toggle several at once\n3~ toggles the next 3 characters — saves repeating ~ multiple times',
      example = '3~ on "hello" → "HEllo"',
    },

    -- ── diw (detected by visual_textobj v i w d) ─────────────────────────────
    ['diw'] = {
      title = 'diw — delete inner word',
      body = 'Deletes the entire word under the cursor regardless of where the cursor sits within it\nciw changes the word; diw deletes it — no need to visually select first',
      example = 'he|llo → diw → word deleted, cursor stays in place',
    },

    -- ── yyp (detected by yy_then_p) ───────────────────────────────────────────
    ['yyp'] = {
      title = 'yyp — duplicate the current line',
      body = 'Yanks the whole line and pastes it below — the idiomatic way to duplicate a line\nDoing yy then p is the same keystrokes, but thinking of it as yyp makes it a single intent',
      example = 'yyp on "local x = 1" → duplicates that line below',
    },

    -- ── {n}. (detected by dot_repeat × 3) ────────────────────────────────────
    ['{n}.'] = {
      title = '{n}. — repeat the last change N times',
      body = 'Prefix . with a count to repeat the last change that many times at once\n3. repeats three times in one command instead of pressing . three separate times',
      example = '3. → repeat last change 3 times',
    },

    -- ── {n}J (detected by J_repeat × 3) ──────────────────────────────────────
    ['{n}J'] = {
      title = '{n}J — join multiple lines at once',
      body = 'Prefix J with a count to join that many lines in one command\n3J joins the current line and the two lines below it — no need to press J repeatedly',
      example = '3J → join current line with the next 2 lines',
    },

    -- ── {n}>> / {n}<< (detected by indent_run / dedent_run × 3) ─────────────
    ['{n}>>'] = {
      title = '{n}>> — indent multiple lines at once',
      body = 'Prefix >> with a count to indent that many lines in one command\n3>> indents 3 lines starting from the cursor — faster than pressing >> repeatedly',
      example = '3>> → indent 3 lines at once',
    },
    ['{n}<<'] = {
      title = '{n}<< — dedent multiple lines at once',
      body = 'Prefix << with a count to dedent that many lines in one command\n3<< removes one level of indentation from 3 lines starting from the cursor',
      example = '3<< → dedent 3 lines at once',
    },
  },
}
