-- Minimal Neovim init for the tobira.nvim demo recording.
-- Usage: nvim -u docs/demo-init.lua docs/demo.lua

vim.opt.termguicolors = true
vim.opt.swapfile = false
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'
vim.opt.laststatus = 0
vim.opt.ruler = false
vim.opt.showcmd = false
vim.opt.showmode = false

-- tobira from repo root
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'))

-- catppuccin colorscheme
vim.opt.rtp:prepend(vim.fn.expand('~/.local/share/nvim/lazy/catppuccin'))
require('catppuccin').setup({ flavour = 'mocha' })
vim.cmd.colorscheme('catppuccin')

-- treesitter for proper syntax highlighting
vim.opt.rtp:prepend(vim.fn.expand('~/.local/share/nvim/lazy/nvim-treesitter'))
require('nvim-treesitter.configs').setup({
  highlight = { enable = true },
  ensure_installed = {},
})

-- nvim-notify for toast-style suggestions
vim.opt.rtp:prepend(vim.fn.expand('~/.local/share/nvim/lazy/nvim-notify'))
require('notify').setup({
  background_colour = '#1e1e2e',
  stages = 'fade_in_slide_out',
  timeout = 6000,
  render = 'wrapped-compact',
})
vim.notify = require('notify')

-- Seed usage data showcasing the new mastery-star and pin system:
--   ★★★ ciw (5200) / cw (1500) / dw (1200)  — max mastery
--   ★★  u (1100)                              — high
--   ★   h/j/k/l/w/b/i (100-200)              — learned, excluded from guide
--   ☆   f (42) / x (28) / n (35)             — seen but not mastered
--   ✗   dd (88)                               — suppressed by user
--   ⊙   <C-r> pinned=true                     — appears in Pinned section
--   guide_seen=true so the cheatsheet doesn't auto-open on startup
local data_dir = vim.fn.stdpath('data') .. '/tobira'
vim.fn.mkdir(data_dir, 'p')
local seed = io.open(data_dir .. '/usage.json', 'w')
if seed then
  seed:write(vim.json.encode({
    h      = { count = 180, sessions = { 8,  9, 11 }, shown = 0, suppressed = false, pinned = false },
    j      = { count = 240, sessions = { 12,14, 10 }, shown = 0, suppressed = false, pinned = false },
    k      = { count = 130, sessions = { 6,  7,  8 }, shown = 0, suppressed = false, pinned = false },
    l      = { count = 160, sessions = { 9, 10,  8 }, shown = 0, suppressed = false, pinned = false },
    w      = { count = 110, sessions = { 5,  6,  7 }, shown = 0, suppressed = false, pinned = false },
    b      = { count = 105, sessions = { 4,  5,  6 }, shown = 0, suppressed = false, pinned = false },
    i      = { count = 200, sessions = { 10,11,  9 }, shown = 0, suppressed = false, pinned = false },
    u      = { count = 1100,sessions = { 15,18, 20 }, shown = 0, suppressed = false, pinned = false },
    dw     = { count = 1200,sessions = { 15,18, 20 }, shown = 0, suppressed = false, pinned = false },
    cw     = { count = 1500,sessions = { 18,20, 22 }, shown = 0, suppressed = false, pinned = false },
    ciw    = { count = 5200,sessions = { 25,28, 30 }, shown = 0, suppressed = false, pinned = false },
    f      = { count = 42,  sessions = { 2,  3,  4 }, shown = 1, suppressed = false, pinned = false },
    x      = { count = 28,  sessions = { 1,  2,  3 }, shown = 0, suppressed = false, pinned = false },
    n      = { count = 35,  sessions = { 2,  2,  3 }, shown = 0, suppressed = false, pinned = false },
    dd     = { count = 88,  sessions = { 4,  5,  3 }, shown = 0, suppressed = true,  pinned = false },
    ['<C-r>'] = { count = 12, sessions = { 1, 1, 2 }, shown = 0, suppressed = false, pinned = true },
    _meta  = { guide_seen = true },
  }))
  seed:close()
end

require('tobira').setup({
  idle_delay = 800,
  max_shown = 3,
})
