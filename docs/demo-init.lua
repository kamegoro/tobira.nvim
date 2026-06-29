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

-- Seed usage data so the demo shows a realistic intermediate-level state:
--   f=18  → ';' suggestion fires immediately (trigger count > 0, ';' unused)
--   hjkl (173 total) / f (18) / i (45) / x (22) exceed guide thresholds → ✓
--   w/b (23 total) below threshold → ○ (contrast visible in :TobiraGuide)
--   guide_seen=true so the cheatsheet doesn't auto-open on startup
local data_dir = vim.fn.stdpath('data') .. '/tobira'
vim.fn.mkdir(data_dir, 'p')
local seed = io.open(data_dir .. '/usage.json', 'w')
if seed then
  seed:write(vim.json.encode({
    f = { count = 18, sessions = {}, shown = 0, suppressed = false },
    h = { count = 45, sessions = { 10, 12, 8 }, shown = 0, suppressed = false },
    j = { count = 62, sessions = { 12, 15, 10 }, shown = 0, suppressed = false },
    k = { count = 28, sessions = { 6, 7, 5 }, shown = 0, suppressed = false },
    l = { count = 38, sessions = { 8, 9, 7 }, shown = 0, suppressed = false },
    w = { count = 15, sessions = { 2, 3, 1 }, shown = 0, suppressed = false },
    b = { count = 8, sessions = { 1, 2, 1 }, shown = 0, suppressed = false },
    i = { count = 45, sessions = { 8, 10, 7 }, shown = 0, suppressed = false },
    x = { count = 22, sessions = { 4, 5, 3 }, shown = 0, suppressed = false },
    p = { count = 8, sessions = { 1, 2, 1 }, shown = 0, suppressed = false },
    u = { count = 9, sessions = { 2, 2, 1 }, shown = 0, suppressed = false },
    n = { count = 15, sessions = { 3, 4, 3 }, shown = 0, suppressed = false },
    _meta = { guide_seen = true },
  }))
  seed:close()
end

require('tobira').setup({
  idle_delay = 800,
  max_shown = 3,
})
