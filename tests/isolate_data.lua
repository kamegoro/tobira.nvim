-- Redirects stdpath('data') to a per-process temp dir so no spec can read or
-- delete the developer's real usage.json, however the spec is launched.
-- Every *_spec.lua requires this on its first line; tests/minimal_init.lua
-- requires it too. See docs/adr/0092-test-stdpath-data-redirect-ordering.md.
local M = {}

local real_stdpath = vim.fn.stdpath
local real_data = real_stdpath('data')
local isolated

function M.real_data_dir()
  return real_data
end

function M.is_inside(path, dir)
  return path == dir or vim.startswith(path, dir .. '/')
end

-- Hard-fails when a logger already captured the real data dir: by then the
-- redirect below can no longer reach it.
function M.assert_isolated(logger, real)
  if M.is_inside(logger.data_dir(), real) then
    error('tobira tests: logger was loaded with the real data dir ' .. real .. "; require('tests.isolate_data') first")
  end
end

local loaded_logger = package.loaded['tobira.core.logger']
if loaded_logger then
  M.assert_isolated(loaded_logger, real_data)
end

isolated = vim.fn.tempname()
vim.fn.mkdir(isolated, 'p')
vim.fn.stdpath = function(what)
  if what == 'data' then
    return isolated
  end
  return real_stdpath(what)
end

return M
