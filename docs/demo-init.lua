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

-- Load tobira from this repo root
vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'))

-- Wipe usage data so the demo always starts from a clean state
os.remove(vim.fn.stdpath('data') .. '/tobira/usage.json')

require('tobira').setup({
  idle_delay = 800,
  max_shown = 3,
})

-- Pre-seed usage: simulate a user who has been pressing 'f' repeatedly.
-- This gives find_best() enough signal to recommend ';'.
vim.defer_fn(function()
  local logger = require('tobira.core.logger')
  for _ = 1, 12 do
    logger.simulate_keys({ 'f', 'o' })
  end
end, 300)
