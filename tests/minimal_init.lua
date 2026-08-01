-- ── Isolate tests from the user's real data ─────────────────────────────────
--
-- Redirects vim.fn.stdpath('data') to a per-process temp dir so the suite
-- never touches the developer's real usage.json. Must install after plenary
-- is located (under the real data dir) but before any spec requires
-- tobira.core.logger (which captures data_dir at require time).
-- see docs/adr/0092-test-stdpath-data-redirect-ordering.md for why
local _tobira_real_stdpath = vim.fn.stdpath

-- Enable luacov coverage tracking when COVERAGE=1 is set.
-- PlenaryBustedDirectory spawns one child Neovim process per spec file, so the
-- CI command MUST pass `minimal_init = 'tests/minimal_init.lua'`; otherwise the
-- children never load this file and no coverage is collected.
if os.getenv('COVERAGE') == '1' then
  -- Neovim ignores the LUA_PATH env-var, so we patch package.path directly.
  local home = os.getenv('HOME') or ''
  local lr = home .. '/.luarocks/share/lua/5.1'
  package.path = lr .. '/?.lua;' .. lr .. '/?/init.lua;' .. package.path

  local ok, runner = pcall(require, 'luacov.runner')
  if ok then
    runner.init()

    -- Flush luacov stats before plenary's hard-quit skips os.exit's hook.
    -- see docs/adr/0093-luacov-flush-before-plenary-hard-quit.md for why
    local orig_cmd = vim.cmd
    vim.cmd = function(...)
      local arg = select(1, ...)
      local cmd_str = type(arg) == 'string' and arg or (type(arg) == 'table' and (arg.cmd or '') or '')
      if cmd_str:match('%d?cq') or cmd_str:match('qa') then
        pcall(runner.shutdown)
        vim.cmd = orig_cmd
      end
      return orig_cmd(...)
    end

    -- Belt-and-suspenders: flush on os.exit() and VimLeave too.
    local orig_exit = os.exit
    os.exit = function(code, ...)
      pcall(runner.shutdown)
      orig_exit(code, ...)
    end
    vim.api.nvim_create_autocmd('VimLeave', {
      callback = function()
        pcall(runner.shutdown)
      end,
    })
  else
    io.stderr:write('[tobira-ci] luacov not loaded: ' .. tostring(runner) .. '\n')
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

-- Plenary is now located; redirect stdpath('data') for the rest of this run.
local _tobira_test_data = vim.fn.tempname()
vim.fn.mkdir(_tobira_test_data, 'p')
vim.fn.stdpath = function(what)
  if what == 'data' then
    return _tobira_test_data
  end
  return _tobira_real_stdpath(what)
end
