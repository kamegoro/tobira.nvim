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

-- nvim-notify for toast-style suggestions (optional — shows best-case UX)
vim.opt.rtp:prepend(vim.fn.expand('~/.local/share/nvim/lazy/nvim-notify'))
require('notify').setup({
  background_colour = '#000000',
  stages = 'fade_in_slide_out',
  timeout = 6000,
  render = 'wrapped-compact',
})
vim.notify = require('notify')

-- Seed usage data so the demo shows realistic state:
--   - f=18 triggers the ';' suggestion immediately
--   - hjkl (173 total) / f (18) / i (45) / x (22) exceed guide thresholds → ✓ shown
--   - w/b (23 total) below threshold → ○ shown, contrast visible in guide
--   - enough counts for level.get() to return 'intermediate'
--   - guide_seen=true so the cheatsheet doesn't auto-open on startup
local data_dir = vim.fn.stdpath('data') .. '/tobira'
vim.fn.mkdir(data_dir, 'p')
local seed = io.open(data_dir .. '/usage.json', 'w')
if seed then
  seed:write(vim.json.encode({
    f = { count = 18, shown = 0, adopted = false },
    h = { count = 45, shown = 0, adopted = false },
    j = { count = 62, shown = 0, adopted = false },
    k = { count = 28, shown = 0, adopted = false },
    l = { count = 38, shown = 0, adopted = false },
    w = { count = 15, shown = 0, adopted = false },
    b = { count = 8, shown = 0, adopted = false },
    i = { count = 45, shown = 0, adopted = false },
    x = { count = 22, shown = 0, adopted = false },
    p = { count = 8, shown = 0, adopted = false },
    u = { count = 9, shown = 0, adopted = false },
    n = { count = 15, shown = 0, adopted = false },
    _meta = { guide_seen = true },
  }))
  seed:close()
end

require('tobira').setup({
  idle_delay = 800,
  max_shown = 3,
})
