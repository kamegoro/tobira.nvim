-- Enable luacov coverage tracking when COVERAGE=1 is set.
-- luacov must be findable via LUA_PATH (set by CI before invoking nvim).
if os.getenv('COVERAGE') == '1' then
  local ok, runner = pcall(require, 'luacov.runner')
  if ok then
    runner.init()
    -- Flush stats on clean Neovim exit so the report file is complete.
    vim.api.nvim_create_autocmd('VimLeave', {
      callback = function()
        runner.shutdown()
      end,
    })
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
