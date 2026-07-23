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
  vim.api.nvim_set_hl(0, 'TobiraGuideHint', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'TobiraGuideSuppressed', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'TobiraGuidePinned', { link = 'DiagnosticInfo' })
  -- Guide: "used to know this, gone quiet" signal (#68). Deliberately not
  -- DiagnosticWarn — TobiraGuideLearning already owns that, see ui/CLAUDE.md.
  vim.api.nvim_set_hl(0, 'TobiraGuideForgotten', { link = 'DiagnosticHint' })

  -- Suggestion float: category-colored border so a returning user can recognize
  -- motion / edit / search / … at a glance without reading the title.
  vim.api.nvim_set_hl(0, 'TobiraSuggestMotion', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestEdit', { link = 'Function' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestSearch', { link = 'String' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestWindow', { link = 'Type' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestFold', { link = 'Constant' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestMark', { link = 'Identifier' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestMacro', { link = 'PreProc' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestTerminal', { link = 'Statement' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestKey', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestReason', { link = 'Comment' })

  -- Adoption celebration: distinct success styling so it never reads as a new suggestion.
  vim.api.nvim_set_hl(0, 'TobiraCelebrate', { link = 'DiagnosticOk' })

  -- Shared foundation for the panel redesigns (#67 Progress, #68 Guide, #74 Stats):
  -- TobiraDim for never-tried / de-emphasized text, TobiraH1 for section/status headings.
  -- See ui/CLAUDE.md for the full color-language reference before adding another state color.
  vim.api.nvim_set_hl(0, 'TobiraDim', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'TobiraH1', { link = 'Title' })
end

return M
