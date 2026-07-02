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
  vim.api.nvim_set_hl(0, 'TobiraGuideLearning', { link = 'DiagnosticWarn' })
  vim.api.nvim_set_hl(0, 'TobiraGuideUpgrade', { link = 'DiagnosticHint' })
  vim.api.nvim_set_hl(0, 'TobiraGuideHint', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'TobiraGuideSuppressed', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'TobiraGuidePinned', { link = 'DiagnosticInfo' })

  -- Suggestion float: category-colored border so a returning user can recognize
  -- motion / edit / search / … at a glance without reading the title.
  vim.api.nvim_set_hl(0, 'TobiraSuggestMotion', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestEdit', { link = 'Function' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestSearch', { link = 'String' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestWindow', { link = 'Type' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestFold', { link = 'Constant' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestMark', { link = 'Identifier' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestMacro', { link = 'PreProc' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestKey', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestReason', { link = 'Comment' })

  -- Adoption celebration: distinct success styling so it never reads as a new suggestion.
  vim.api.nvim_set_hl(0, 'TobiraCelebrate', { link = 'DiagnosticOk' })
end

return M
