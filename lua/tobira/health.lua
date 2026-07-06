-- :checkhealth tobira (#42). Neovim auto-discovers this file by convention —
-- no registration needed anywhere else.
local M = {}

-- Neovim >= 0.10 renamed require('health').report_* to vim.health.*. Adapts
-- either shape to a common {start, ok, warn, error} table. Exposed (not local)
-- so it's directly unit-testable with a plain constructed table — vim.health
-- itself can't be reliably forced to nil in tests, since `vim` resolves
-- unknown fields through a metatable that keeps re-populating it.
function M.resolve_api(health_module)
  return {
    start = health_module.start or health_module.report_start,
    ok = health_module.ok or health_module.report_ok,
    warn = health_module.warn or health_module.report_warn,
    error = health_module.error or health_module.report_error,
  }
end

function M.check()
  -- Resolved per-call (not cached at module load) so tests can mock vim.health.
  local health = M.resolve_api(vim.health or require('health'))
  local start, ok, warn, err = health.start, health.ok, health.warn, health.error

  start('tobira.nvim')

  -- tobira claims Neovim 0.9+ (logger.lua falls back to `typed or key` when
  -- vim.on_key()'s `typed` argument isn't available), but tracking accuracy
  -- is meaningfully better on 0.10+, where `typed` distinguishes physically
  -- pressed keys from ones Neovim expanded internally (e.g. D -> d$).
  if vim.fn.has('nvim-0.9') == 1 then
    if vim.fn.has('nvim-0.10') == 1 then
      ok('Neovim ' .. tostring(vim.version()) .. ' — full keystroke accuracy (vim.on_key `typed` available)')
    else
      warn('Neovim ' .. tostring(vim.version()) .. ' — reduced accuracy: vim.on_key `typed` needs 0.10+')
    end
  else
    err('Neovim >= 0.9 is required (current: ' .. tostring(vim.version()) .. ')')
  end

  local logger = require('tobira.core.logger')
  local data_dir = logger.data_dir()
  if vim.fn.isdirectory(data_dir) == 1 then
    if vim.fn.filewritable(data_dir) == 2 then
      ok('Data directory is writable: ' .. data_dir)
    else
      err('Data directory exists but is not writable: ' .. data_dir)
    end
  else
    local parent = vim.fn.fnamemodify(data_dir, ':h')
    if vim.fn.filewritable(parent) == 2 then
      ok('Data directory does not exist yet, will be created on first use: ' .. data_dir)
    else
      err('Cannot create data directory — parent is not writable: ' .. parent)
    end
  end

  local data_file = logger.data_file()
  if vim.fn.filereadable(data_file) == 0 then
    ok('usage.json does not exist yet (fresh install)')
  else
    -- filereadable() already confirmed this path opens for reading, so io.open
    -- is trusted here rather than defended against a redundant nil case.
    local f = io.open(data_file, 'r')
    local content = f:read('*a')
    f:close()
    if pcall(vim.json.decode, content) then
      ok('usage.json is valid JSON')
    else
      err('usage.json exists but is not valid JSON — tobira will treat it as empty until fixed: ' .. data_file)
    end
  end

  local config = require('tobira.core.config')
  local lang = config.values.lang
  if pcall(require, 'tobira.locales.' .. lang) then
    ok('lang = "' .. lang .. '" is a supported locale')
  else
    warn('lang = "' .. lang .. '" has no matching locale file — falling back to English')
  end
end

return M
