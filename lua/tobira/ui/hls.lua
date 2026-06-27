local M = {}

function M.setup()
  if vim.fn.hlexists('TobiraGuideBorder') == 1 then
    return
  end
  local has_notify_hl = pcall(require, 'notify') and vim.fn.hlexists('NotifyINFOBorder') == 1
  if has_notify_hl then
    vim.api.nvim_set_hl(0, 'TobiraGuideBorder', { link = 'NotifyINFOBorder' })
    vim.api.nvim_set_hl(0, 'TobiraGuideNormal', { link = 'NotifyINFOBody' })
    vim.api.nvim_set_hl(0, 'TobiraGuideSection', { link = 'NotifyINFOTitle' })
  else
    vim.api.nvim_set_hl(0, 'TobiraGuideBorder', { link = 'FloatBorder' })
    vim.api.nvim_set_hl(0, 'TobiraGuideNormal', { link = 'NormalFloat' })
    vim.api.nvim_set_hl(0, 'TobiraGuideSection', { link = 'Title' })
  end
  vim.api.nvim_set_hl(0, 'TobiraGuideKey', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'TobiraGuideMastered', { link = 'DiagnosticOk' })
  vim.api.nvim_set_hl(0, 'TobiraGuideUpgrade', { link = 'DiagnosticHint' })
  vim.api.nvim_set_hl(0, 'TobiraGuideHint', { link = 'Comment' })
end

return M
