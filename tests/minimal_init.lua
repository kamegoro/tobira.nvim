-- ── Isolate tests from the user's real data ─────────────────────────────────
--
-- tobira.core.logger reads/writes ~/.local/share/nvim/tobira/usage.json and
-- logger.reset() (called in before_each of many specs) unlinks that file.
-- Running the suite must NOT wipe the developer's real usage history.
--
-- We redirect vim.fn.stdpath('data') to a per-process temp directory. The
-- override is installed AFTER plenary is located (plenary lives under the real
-- data dir) but BEFORE any spec requires tobira.core.logger, which captures
-- data_dir at require time.
local _tobira_real_stdpath = vim.fn.stdpath

-- Enable luacov coverage tracking when COVERAGE=1 is set.
--
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

    -- plenary's busted runner exits headless Neovim with `vim.cmd "0cq"`
    -- (or "1cq" on failure) instead of os.exit(). That hard-quit skips
    -- luacov's own os.exit hook, so stats are never written. We intercept
    -- vim.cmd to flush stats just before the quit. See plenary.nvim#353.
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

-- Now that plenary has been located under the REAL data dir, redirect
-- stdpath('data') to a per-process temp dir so tobira.core.logger reads and
-- writes an isolated usage.json for the duration of this test run.
local _tobira_test_data = vim.fn.tempname()
vim.fn.mkdir(_tobira_test_data, 'p')
vim.fn.stdpath = function(what)
  if what == 'data' then
    return _tobira_test_data
  end
  return _tobira_real_stdpath(what)
end
