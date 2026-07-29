local M = {}

local _defaults = {
  idle_delay = 1500,
  idle_suggestions = true,
  suggestion_cooldown = 300,
  max_shown = 2,
  lang = 'en',
  -- #63 phase 2: gates core/integrations.lua's plugin-detection promotions
  -- (e.g. boosting a suggestion when surround.nvim/flash.nvim is installed).
  -- Does NOT gate phase 1 (respecting the user's own keymap overrides) --
  -- that baseline correctness behavior stays on unconditionally, see
  -- integrations.lua's header comment for why a flag there would be a footgun.
  integrations = true,
}

M.values = vim.deepcopy(_defaults)

function M.setup(opts)
  local cfg = vim.tbl_deep_extend('force', _defaults, opts or {})
  local ok, err = pcall(vim.validate, {
    idle_delay = { cfg.idle_delay, 'number' },
    idle_suggestions = { cfg.idle_suggestions, 'boolean' },
    suggestion_cooldown = { cfg.suggestion_cooldown, 'number' },
    max_shown = { cfg.max_shown, 'number' },
    lang = { cfg.lang, 'string' },
    integrations = { cfg.integrations, 'boolean' },
  })
  if not ok then
    -- Use i18n.load() with the *incoming* (possibly invalid) lang value:
    -- worst case it falls back to English inside i18n.
    local str = require('tobira.i18n').load()
    vim.notify(str.notifications.invalid_config .. err, vim.log.levels.ERROR)
    return
  end
  M.values = cfg
end

function M.reset()
  M.values = vim.deepcopy(_defaults)
end

return M
