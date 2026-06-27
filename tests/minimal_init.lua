-- Enable luacov coverage tracking when COVERAGE=1 is set.
if os.getenv('COVERAGE') == '1' then
  -- Neovim ignores the LUA_PATH env-var, so we patch package.path directly.
  local home = os.getenv('HOME') or ''
  local lr = home .. '/.luarocks/share/lua/5.1'
  package.path = lr .. '/?.lua;' .. lr .. '/?/init.lua;' .. package.path

  local ok, runner = pcall(require, 'luacov.runner')
  if ok then
    runner.init()
    print('[luacov] runner initialized OK')

    -- Hook os.exit so stats are written when plenary calls os.exit().
    local orig_exit = os.exit
    os.exit = function(code, ...)
      pcall(runner.shutdown)
      orig_exit(code, ...)
    end

    -- Also flush on :qall! / VimLeave in case os.exit is not used.
    vim.api.nvim_create_autocmd('VimLeave', {
      callback = function()
        pcall(runner.shutdown)
      end,
    })
  else
    print('[luacov] FAILED to load runner: ' .. tostring(runner))
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
