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

  cfg.setup(opts)
  logger.setup()

  -- Wire cross-layer callbacks here (the only place any module knows about
  -- the others' roles).
  --   logger fires patterns → suggest handles them.
  --   suggest wants to display → ui.float renders.
  logger.on_pattern = suggest.queue
  suggest.on_show = function(suggestion)
    require('tobira.ui.float').show(suggestion)
  end
  suggest.setup_idle()

  if not logger.is_guide_seen() then
    logger.mark_guide_seen()
    vim.defer_fn(function()
      require('tobira.ui.guide').open()
    end, 300)
  end
end

return M
