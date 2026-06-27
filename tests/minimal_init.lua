-- Enable luacov coverage tracking when COVERAGE=1 is set.
if os.getenv('COVERAGE') == '1' then
  -- Neovim ignores the LUA_PATH env-var, so we patch package.path directly.
  local home = os.getenv('HOME') or ''
  local lr = home .. '/.luarocks/share/lua/5.1'
  local lr_path = lr .. '/?.lua;' .. lr .. '/?/init.lua'
  if not package.path:find(lr_path, 1, true) then
    package.path = lr_path .. ';' .. package.path
  end

  -- require('luacov') (the main entry) hooks os.exit() so stats are flushed
  -- even when plenary exits via os.exit() rather than triggering VimLeave.
  local ok, err = pcall(require, 'luacov')
  if not ok then
    io.stderr:write('[tobira-ci] luacov not loaded: ' .. tostring(err) .. '\n')
  end
end

local plenary_path = vim.fn.stdpath('data') .. '/site/pack/test/start/plenary.nvim'

if vim.fn.isdirectory(plenary_path) == 0 then
  vim.fn.system({
    'git',
    'clone',
    '--depth=1',
    'https://github.com/nvim-lua/plenary.nvim',
    plenary_path,
  })
end

vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend(plenary_path)

-- With --noplugin, plugin/ files are not auto-sourced.
-- Manually source plenary's plugin to register PlenaryBustedDirectory.
vim.cmd('runtime plugin/plenary.vim')
