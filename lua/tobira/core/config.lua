local M = {}

local _defaults = {
  idle_delay = 1500,
  idle_suggestions = true,
  suggestion_cooldown = 300,
  max_shown = 2,
  lang = 'en',
  -- Gates core/integrations.lua's plugin-detection promotions (e.g. boosting
  -- a suggestion when surround.nvim/flash.nvim is installed). Does NOT gate
  -- respecting the user's own keymap overrides -- that baseline correctness
  -- behavior stays on unconditionally, see integrations.lua's header comment
  -- for why a flag there would be a footgun.
  integrations = true,
}

M.values = vim.deepcopy(_defaults)

function M.setup(opts)
  local cfg = vim.tbl_deep_extend('force', _defaults, opts or {})
  -- vim.validate(spec) (the table form) is deprecated; the replacement is
  -- vim.validate(name, value, validator) called once per field. It raises
  -- on the first failure (like the table form's "first failure" semantics),
  -- so wrapping every call in one pcall preserves the exact ok/err contract
  -- this function relied on. Order matches the table form's alphanumeric
  -- evaluation order so the *first* reported failure is unchanged too.
  local ok, err = pcall(function()
    vim.validate('idle_delay', cfg.idle_delay, 'number')
    vim.validate('idle_suggestions', cfg.idle_suggestions, 'boolean')
    vim.validate('integrations', cfg.integrations, 'boolean')
    vim.validate('lang', cfg.lang, 'string')
    vim.validate('max_shown', cfg.max_shown, 'number')
    vim.validate('suggestion_cooldown', cfg.suggestion_cooldown, 'number')
  end)
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
