return {
  guide = {
    title = 'tobira guide',
    hint = ':TobiraGuide  toggle guide',
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
              upgrade = { keys = ';', desc = 'repeat last f' },
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
    },
  },
  notifications = {
    reset = 'tobira: usage log reset',
    no_suggestions = 'tobira: no new suggestions right now 🎉',
  },
  stats = {
    title = 'tobira — usage stats',
    times = 'times',
  },
  float = {
    example_prefix = 'e.g. ',
  },
  -- Suggestion display strings shown via float popup and :TobiraProgress.
  -- Keys match commands.registry keys exactly.
  suggestions = {
    [';'] = {
      title = '; — repeat the last f',
      body = 'After f{char}, press ; to jump to the next occurrence\n, goes in the reverse direction',
      example = 'fa ;; → next a, then the next',
    },
    [','] = {
      title = ', — repeat f in reverse',
      body = 'The opposite of ; — jumps back to the previous f match\nUseful when you overshoot with ;',
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
      title = 'P — paste above the current line',
      body = 'p pastes below the cursor line; P pastes above it\nUseful when you need to insert copied text before the current line',
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
  },
}
