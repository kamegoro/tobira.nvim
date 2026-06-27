local M = {}

local _defaults = {
  idle_delay = 1500,
  max_shown = 3,
  lang = 'en',
}

M.values = vim.deepcopy(_defaults)

function M.setup(opts)
  local cfg = vim.tbl_deep_extend('force', _defaults, opts or {})
  local ok, err = pcall(vim.validate, {
    idle_delay = { cfg.idle_delay, 'number' },
    max_shown = { cfg.max_shown, 'number' },
    lang = { cfg.lang, 'string' },
  })
  if not ok then
    vim.notify('tobira: invalid config — ' .. err, vim.log.levels.ERROR)
    return
  end
  M.values = cfg
end

function M.reset()
  M.values = vim.deepcopy(_defaults)
end

return M
