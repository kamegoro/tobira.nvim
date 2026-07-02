-- Minimal Neovim init for the tobira.nvim demo recording.
-- Usage: nvim -u docs/demo-init.lua docs/demo.lua

vim.opt.termguicolors = true
vim.opt.swapfile = false
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'
vim.opt.laststatus = 2
vim.opt.ruler = false
vim.opt.showcmd = false
vim.opt.showmode = false
vim.opt.scrolloff = 4

-- tobira from repo root
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'))

-- ── plugins (all pre-installed via lazy.nvim) ─────────────────────────────────

local lazy_root = vim.fn.expand('~/.local/share/nvim/lazy')

-- catppuccin
vim.opt.rtp:prepend(lazy_root .. '/catppuccin')
require('catppuccin').setup({
  flavour = 'mocha',
  transparent_background = false,
  integrations = {
    treesitter = true,
    notify = true,
    gitsigns = true,
    indent_blankline = { enabled = true },
  },
})
vim.cmd.colorscheme('catppuccin')

-- nvim-web-devicons (required by lualine)
vim.opt.rtp:prepend(lazy_root .. '/nvim-web-devicons')
require('nvim-web-devicons').setup({ default = true })

-- lualine — catppuccin-mocha statusline
vim.opt.rtp:prepend(lazy_root .. '/lualine.nvim')
require('lualine').setup({
  options = { theme = 'catppuccin-mocha', globalstatus = true },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff' },
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = { 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
})

-- indent-blankline
vim.opt.rtp:prepend(lazy_root .. '/indent-blankline.nvim')
require('ibl').setup({ scope = { enabled = true } })

-- gitsigns — shows +/~/- in the sign column
vim.opt.rtp:prepend(lazy_root .. '/plenary.nvim')
vim.opt.rtp:prepend(lazy_root .. '/gitsigns.nvim')
pcall(require('gitsigns').setup, {
  signs = {
    add    = { text = '│' },
    change = { text = '│' },
    delete = { text = '_' },
  },
})

-- nvim-treesitter (Lua parser should already be compiled)
vim.opt.rtp:prepend(lazy_root .. '/nvim-treesitter')
pcall(require('nvim-treesitter.configs').setup, {
  highlight = { enable = true },
  ensure_installed = {},
})

-- nvim-notify — tobira uses vim.notify for the suggestion toast
vim.opt.rtp:prepend(lazy_root .. '/nvim-notify')
require('notify').setup({
  background_colour = '#1e1e2e',
  stages = 'fade_in_slide_out',
  timeout = 6000,
  render = 'wrapped-compact',
})
vim.notify = require('notify')

-- ── seed usage data ───────────────────────────────────────────────────────────
--
-- Designed to show a realistic "intermediate beginner" profile:
--   ★★★ mastered : h j k l i ciw
--   ★★  practiced: w b u dw cw a
--   ★   familiar  : o x n p v G
--   ☆   tried     : f * } { ^ $ % <C-o>
--   ✗   suppressed: dd (user decided they don't want it suggested)
--   *   pinned    : <C-r>  (always in :TobiraGuide)
--   never         : most advanced/fold/macro commands → big stats "never" bucket
--
-- Efficiency gaps that will surface in :TobiraStats:
--   j (6200)  →  }  (28)   ratio ≈ 221
--   n (350)   → cgn (0)    ratio ≈ 350
--   w (1100)  →  E  (0)    ratio ≈ 1100
--   *  (55)   → gn  (0)    ratio ≈  55
--   f  (42)   →  ;  (0)    ratio ≈  42

local data_dir = vim.fn.stdpath('data') .. '/tobira'
vim.fn.mkdir(data_dir, 'p')
local seed = io.open(data_dir .. '/usage.json', 'w')
if seed then
  seed:write(vim.json.encode({
    -- ★★★ mastered (5000+)
    h      = { count = 5000, sessions = { 25,28,30,32,29 }, shown = 0, suppressed = false, pinned = false },
    j      = { count = 6200, sessions = { 30,35,32,28,31 }, shown = 0, suppressed = false, pinned = false },
    k      = { count = 2800, sessions = { 18,20,22,19,21 }, shown = 0, suppressed = false, pinned = false },
    l      = { count = 3100, sessions = { 20,22,19,21,20 }, shown = 0, suppressed = false, pinned = false },
    i      = { count = 2500, sessions = { 18,20,18,17,19 }, shown = 0, suppressed = false, pinned = false },
    ciw    = { count = 5200, sessions = { 25,28,30,27,29 }, shown = 0, suppressed = false, pinned = false },

    -- ★★ practiced (1000-4999)
    w      = { count = 1100, sessions = { 15,18,20,17,16 }, shown = 0, suppressed = false, pinned = false },
    b      = { count = 1050, sessions = { 14,17,19,16,15 }, shown = 0, suppressed = false, pinned = false },
    u      = { count = 1100, sessions = { 15,18,20,17,16 }, shown = 0, suppressed = false, pinned = false },
    dw     = { count = 1200, sessions = { 15,18,20,17,16 }, shown = 0, suppressed = false, pinned = false },
    cw     = { count = 1500, sessions = { 18,20,22,19,21 }, shown = 0, suppressed = false, pinned = false },
    a      = { count = 1800, sessions = { 14,16,18,15,17 }, shown = 0, suppressed = false, pinned = false },

    -- ★ familiar (100-999)
    o      = { count = 600,  sessions = { 8,9,10,8,9   }, shown = 0, suppressed = false, pinned = false },
    x      = { count = 280,  sessions = { 4,5,6,4,5    }, shown = 0, suppressed = false, pinned = false },
    n      = { count = 350,  sessions = { 5,6,7,5,6    }, shown = 0, suppressed = false, pinned = false },
    p      = { count = 200,  sessions = { 3,4,5,3,4    }, shown = 0, suppressed = false, pinned = false },
    v      = { count = 450,  sessions = { 6,7,8,6,7    }, shown = 0, suppressed = false, pinned = false },
    G      = { count = 150,  sessions = { 3,4,4,3,3    }, shown = 0, suppressed = false, pinned = false },

    -- ☆ tried (1-99)
    f      = { count = 42,   sessions = { 2,3,4,2,3    }, shown = 1, suppressed = false, pinned = false },
    ['*']  = { count = 55,   sessions = { 2,3,3,2,3    }, shown = 0, suppressed = false, pinned = false },
    ['}']  = { count = 28,   sessions = { 1,2,3,2,1    }, shown = 0, suppressed = false, pinned = false },
    ['{']  = { count = 15,   sessions = { 1,1,2,1,1    }, shown = 0, suppressed = false, pinned = false },
    ['^']  = { count = 35,   sessions = { 1,2,2,1,2    }, shown = 0, suppressed = false, pinned = false },
    ['$']  = { count = 40,   sessions = { 1,2,2,1,2    }, shown = 0, suppressed = false, pinned = false },
    ['%']  = { count = 22,   sessions = { 1,1,2,1,1    }, shown = 0, suppressed = false, pinned = false },
    ['<C-o>'] = { count = 58,sessions = { 2,3,3,2,3    }, shown = 0, suppressed = false, pinned = false },

    -- ✗ suppressed
    dd     = { count = 88,   sessions = { 4,5,3,4,5    }, shown = 0, suppressed = true,  pinned = false },

    -- * pinned
    ['<C-r>'] = { count = 12,sessions = { 1,1,2,1,1    }, shown = 0, suppressed = false, pinned = true  },

    -- meta
    _meta  = { guide_seen = true },
  }))
  seed:close()
end

require('tobira').setup({
  idle_delay = 800,
  max_shown = 3,
})
