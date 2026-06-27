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

require('tobira').setup({
  idle_delay = 800,
  max_shown = 3,
})

-- Pre-seed usage so :Tobira has something to show.
-- Simulates a user who has been pressing 'f' but not ';'.
vim.defer_fn(function()
  local logger = require('tobira.core.logger')
  for _ = 1, 10 do
    logger.simulate_keys({ 'f', 'o' })
  end
end, 200)
