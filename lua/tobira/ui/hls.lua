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
  -- Guide: "used to know this, gone quiet" signal. Deliberately not
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
  -- diff: DiffChange rather than a syntax group like the other
  -- categories — unlike "motion is keyword-ish, edit is function-ish", there
  -- is no syntax group that reads as "diff-ish"; Neovim's own DiffChange
  -- highlight IS the concept this category is about, so it is a more
  -- meaningful link than picking an arbitrary syntax color by loose analogy.
  -- See ui/CLAUDE.md.
  vim.api.nvim_set_hl(0, 'TobiraSuggestDiff', { link = 'DiffChange' })
  -- Ex commands (:g, :norm, ...) are statement-like — the nearest syntax
  -- group to a colon command, matching the other categories' "what kind of
  -- thing is this" intuition (see ui/CLAUDE.md's category table).
  vim.api.nvim_set_hl(0, 'TobiraSuggestEx', { link = 'Statement' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestTerminal', { link = 'Statement' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestKey', { link = 'Special' })
  vim.api.nvim_set_hl(0, 'TobiraSuggestReason', { link = 'Comment' })

  -- Adoption celebration: distinct success styling so it never reads as a new suggestion.
  vim.api.nvim_set_hl(0, 'TobiraCelebrate', { link = 'DiagnosticOk' })

  -- Shared foundation for the Progress/Guide/Stats panel redesigns:
  -- TobiraDim for never-tried / de-emphasized text, TobiraH1 for section/status headings.
  -- See ui/CLAUDE.md for the full color-language reference before adding another state color.
  vim.api.nvim_set_hl(0, 'TobiraDim', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'TobiraH1', { link = 'Title' })
end

return M
