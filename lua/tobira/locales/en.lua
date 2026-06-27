return {
  guide = {
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
}
