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
      title   = '; — repeat the last f',
      body    = 'After f{char}, press ; to jump to the next occurrence\n, goes in the reverse direction',
      example = 'fa ;; → next a, then the next',
    },
    [','] = {
      title   = ', — repeat f in reverse',
      body    = 'The opposite of ; — jumps back to the previous f match\nUseful when you overshoot with ;',
      example = 'fa ;;; , → jump back one',
    },
    ['cw'] = {
      title   = 'cw — delete word and insert',
      body    = 'Replaces the dw + i sequence in one motion\nDrops you into insert mode immediately after deleting',
      example = 'cw → deletes from cursor to end of word → insert mode',
    },
    ['ciw'] = {
      title   = 'ciw — change inner word',
      body    = 'Works even when cursor is in the middle of a word\ncw only deletes from cursor forward; ciw replaces the whole word',
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title   = '<C-r> — redo',
      body    = 'Undid too much? <C-r> redoes the last undone change\nPair with u / <C-r> to navigate change history',
      example = 'u u u <C-r> → undo 3 times, redo once',
    },
    ['ddp'] = {
      title   = 'ddp — swap current line with the next',
      body    = 'dd deletes the line, p pastes it below — ddp swaps lines in one go\nNo need to navigate between the two lines',
      example = 'ddp → current line moves down one',
    },
    ['{n}j'] = {
      title   = '{n}j — jump multiple lines at once',
      body    = 'Prefix any motion with a count to repeat it\n5j moves down 5 lines; also works with k, w, b, etc.',
      example = '5j → moves down 5 lines',
    },
    ['^'] = {
      title   = '^ — jump to first non-blank character',
      body    = '0 goes to column 0; ^ goes to the first non-whitespace character\nUsually ^ is what you actually want',
      example = '    hello → ^ → cursor lands on h',
    },
    ['cgn'] = {
      title   = 'cgn — change next search match',
      body    = 'After /, use cgn to change the next match\nThen press . to repeat on every subsequent match',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title   = '. — repeat the last change',
      body    = 'Repeats your last edit without re-entering insert mode\nCombine with n or ; to change multiple occurrences in one pass',
      example = 'cw foo <Esc> n . → changes the next match too',
    },
    ['A'] = {
      title   = 'A — append at end of line',
      body    = '$a in one keystroke — moves to end of line and enters insert\nPair with I (insert at start) for quick line start / end editing',
      example = 'A; → add a semicolon at end of line',
    },
    ['O'] = {
      title   = 'O — open a new line above',
      body    = 'Like o but opens the new line above the cursor\nNo need to move up first then press o',
      example = 'O → new blank line above cursor → insert mode',
    },
    ['D'] = {
      title   = 'D — delete to end of line',
      body    = 'Deletes from cursor to end of line (same as d$)\nLets you retype the rest without navigating there first',
      example = 'D → type the new ending',
    },
    ['C'] = {
      title   = 'C — change to end of line',
      body    = 'D + i in one motion — deletes to EOL and enters insert\nLike cw but for the rest of the line instead of one word',
      example = 'C → replace everything from cursor to end',
    },
    ['gn'] = {
      title   = 'gn — select next search match',
      body    = 'After * or /, gn selects the next match in visual mode\nUsed with c (cgn) then . to replace every occurrence',
      example = '* → cgn → new text → Esc → . . .',
    },
    ['e'] = {
      title   = 'e — move to end of word',
      body    = 'w jumps to the start of the next word; e jumps to its end\nUseful when you need to append to the end of a word',
      example = 'ea → append text after the current word',
    },
    ['I'] = {
      title   = 'I — insert at start of line',
      body    = 'Moves to the first non-blank character and enters insert mode\nPair with A (end of line) for quick line-edge edits',
      example = 'I// → comment out the current line',
    },
    ['H'] = {
      title   = 'H — jump to top of screen',
      body    = 'Moves cursor to the top of the visible window without scrolling\nM goes to middle, L goes to bottom',
      example = 'H → cursor lands on the first visible line',
    },
    ['M'] = {
      title   = 'M — jump to middle of screen',
      body    = 'Places cursor in the exact middle of the visible window\nUseful for quickly reorienting after a large jump',
      example = 'M → cursor moves to the middle line',
    },
    ['L'] = {
      title   = 'L — jump to bottom of screen',
      body    = 'Moves cursor to the last visible line without scrolling\nPair with H and M for screen-relative navigation',
      example = 'L → cursor lands on the last visible line',
    },
    ['{n}x'] = {
      title   = '{n}x — delete multiple characters at once',
      body    = 'Prefix x with a count to delete that many characters in one go\nAlso works with other motions: 3dw, 2dd, etc.',
      example = '5x → deletes 5 characters at cursor',
    },
    ['<C-d>'] = {
      title   = '<C-d> — scroll half a page down',
      body    = 'Moves the view and cursor down by half the window height\nMuch faster than pressing j many times',
      example = '<C-d><C-d> → scroll down a full page',
    },
    ['<C-u>'] = {
      title   = '<C-u> — scroll half a page up',
      body    = 'The upward complement of <C-d>\nPair them to navigate large files efficiently',
      example = '<C-d> then <C-u> → scroll down and back up',
    },
  },
}
