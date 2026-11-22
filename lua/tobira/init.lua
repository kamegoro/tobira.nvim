local M = {}

local _initialized = false

function M.setup(opts)
  if _initialized then
    return
  end
  _initialized = true

  local cfg = require('tobira.core.config')
  local logger = require('tobira.core.logger')
  local suggest = require('tobira.core.suggest')
  local integrations = require('tobira.core.integrations')

  cfg.setup(opts)
  -- Wired before logger.setup(): its initial load can already find an
  -- unparsable usage.json and move it aside.
  logger.on_corrupt = function(path)
    vim.notify(require('tobira.i18n').load().notifications.usage_corrupt:format(path), vim.log.levels.WARN)
  end
  logger.setup()
  -- Populates the keymap-override / plugin-detection cache immediately,
  -- then keeps it fresh on VimEnter (late-loaded plugins) and SourcePost
  -- (lazy-loaded plugin scripts sourced after startup). Self-contained here,
  -- same as logger.setup() registering its own autocmds -- init.lua stays a
  -- pure wiring layer, it does not register autocmds itself.
  integrations.setup()

  -- Wire cross-layer callbacks here (the only place any module knows about
  -- the others' roles).
  --   logger fires patterns → suggest handles them.
  --   suggest wants to display → ui.float renders.
  logger.on_pattern = suggest.queue
  suggest.on_show = function(suggestion, focused, pattern)
    require('tobira.ui.float').show(suggestion, focused, pattern)
  end
  suggest.on_adopt = function(cmd)
    require('tobira.ui.float').celebrate(cmd)
  end
  suggest.setup_idle()

  if not logger.is_guide_seen() then
    logger.mark_guide_seen()
    vim.defer_fn(function()
      require('tobira.ui.guide').open()
    end, 300)
  end
end

-- :TobiraReset entry point; `force` is the bang, which skips the prompt.
function M.reset(force)
  local logger = require('tobira.core.logger')
  local str = require('tobira.i18n').load().notifications
  if not force and vim.fn.confirm(str.reset_confirm, str.reset_choices, 2) ~= 1 then
    vim.notify(str.reset_cancelled, vim.log.levels.INFO)
    return
  end
  logger.reset()
  logger.clear_disk()
  vim.notify(str.reset, vim.log.levels.INFO)
end

return M
