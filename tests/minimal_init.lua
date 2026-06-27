-- Enable luacov coverage tracking when COVERAGE=1 is set.
if os.getenv('COVERAGE') == '1' then
  -- LuaJIT (used by Neovim) skips debug.sethook for JIT-compiled code, so
  -- luacov's line hook never fires. Disabling JIT forces interpreter mode.
  local jit_ok = false
  if jit then
    local ok = pcall(jit.off)
    jit_ok = ok
  end

  -- Verify debug.sethook actually works in this Lua environment.
  local hook_test = 0
  debug.sethook(function() hook_test = hook_test + 1 end, 'l')
  local _x = 1 + 1 -- should trigger the hook
  debug.sethook() -- remove test hook
  print('[luacov-debug] jit.off ok=' .. tostring(jit_ok) .. '  hook_test=' .. hook_test)

  -- Neovim ignores the LUA_PATH env-var, so we patch package.path directly.
  local home = os.getenv('HOME') or ''
  local lr = home .. '/.luarocks/share/lua/5.1'
  package.path = lr .. '/?.lua;' .. lr .. '/?/init.lua;' .. package.path

  local ok, runner = pcall(require, 'luacov.runner')
  if ok then
    runner.init()

    -- Capture the hook right after init so we can propagate it.
    local luacov_hook, luacov_mask, luacov_count = debug.gethook()
    print('[luacov] runner init OK; hook active: ' .. tostring(luacov_hook ~= nil))

    -- Plenary runs each it() in a fresh coroutine.  debug.sethook is
    -- per-coroutine, so we must re-apply the hook to every new coroutine.
    if luacov_hook then
      local orig_create = coroutine.create
      coroutine.create = function(f)
        local co = orig_create(f)
        debug.sethook(co, luacov_hook, luacov_mask or 'l', luacov_count or 0)
        return co
      end
    end

    -- Intercept vim.cmd "0cq" which newer plenary uses instead of os.exit().
    local orig_cmd = vim.cmd
    vim.cmd = function(...)
      local arg = select(1, ...)
      local cmd_str = type(arg) == 'string' and arg or (type(arg) == 'table' and (arg.cmd or '') or '')
      if cmd_str:match('cq') or cmd_str:match('qall') then
        local h = debug.gethook()
        print('[luacov-exit] hook at exit: ' .. tostring(h ~= nil) .. '  cmd=' .. cmd_str)
        pcall(runner.shutdown)
        vim.cmd = orig_cmd
      end
      return orig_cmd(...)
    end

    -- Hook os.exit so stats are written when plenary calls os.exit().
    local orig_exit = os.exit
    os.exit = function(code, ...)
      print('[luacov-exit] os.exit called code=' .. tostring(code))
      pcall(runner.shutdown)
      orig_exit(code, ...)
    end

    -- Also flush on :qall! / VimLeave in case nothing else works.
    vim.api.nvim_create_autocmd('VimLeave', {
      callback = function()
        print('[luacov-exit] VimLeave fired')
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
