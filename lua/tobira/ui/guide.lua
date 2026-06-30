local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_guide')

local WIDTH = 46
local ICON = '' -- nerd font fa-info-circle (matches nvim-notify INFO icon)

local CATEGORY_ORDER = { 'motion', 'edit', 'search', 'window' }

local setup_hls = require('tobira.ui.hls').setup

-- Extract only the description part from a title like "cmd — description".
local function short_desc(title)
  return title:match(' — (.+)$') or title
end

local function build()
  local loc = require('tobira.i18n').load()
  local strings = loc.guide
  local suggestions = loc.suggestions or {}
  local cat_labels = loc.progress and loc.progress.categories or {}
  local commands = require('tobira.commands')

  local usage = require('tobira.core.logger').get_all()

  -- Collect pinned commands (sorted for determinism)
  local pinned_cmds = {}
  local pinned_set = {}
  for cmd, data in pairs(usage) do
    if data.pinned and commands.registry[cmd] then
      table.insert(pinned_cmds, cmd)
      pinned_set[cmd] = true
    end
  end
  table.sort(pinned_cmds)

  local by_cat = require('tobira.core.graph').guide_commands(usage)

  -- Remove pinned commands from auto section to avoid duplication
  for cat, cmds in pairs(by_cat) do
    local filtered = {}
    for _, cmd in ipairs(cmds) do
      if not pinned_set[cmd] then
        table.insert(filtered, cmd)
      end
    end
    by_cat[cat] = filtered
  end

  local lines = {}
  local hls = {}

  local function push(line, group, cs, ce)
    local lnum = #lines
    table.insert(lines, line)
    if group then
      table.insert(hls, { lnum = lnum, cs = cs or 0, ce = ce or -1, group = group })
    end
  end

  push('')

  -- Pinned section
  if #pinned_cmds > 0 then
    push('')
    local pin_label = strings.pinned or 'Pinned'
    push('  ' .. pin_label, 'TobiraGuidePinned', 2, 2 + #pin_label)
    for _, cmd in ipairs(pinned_cmds) do
      local sug = suggestions[cmd]
      local desc = short_desc((sug and sug.title) or cmd)
      push(string.format('   %-12s  %s', cmd, desc), 'TobiraGuideKey', 3, 3 + #cmd)
    end
  end

  -- Auto section
  local any = false
  for _, cat in ipairs(CATEGORY_ORDER) do
    local cmds = by_cat[cat]
    if cmds and #cmds > 0 then
      any = true
      push('')
      local label = cat_labels[cat] or cat
      push('  ' .. label, 'TobiraGuideSection', 2, 2 + #label)
      for _, cmd in ipairs(cmds) do
        local sug = suggestions[cmd]
        local desc = short_desc((sug and sug.title) or cmd)
        push(string.format('   %-12s  %s', cmd, desc), 'TobiraGuideKey', 3, 3 + #cmd)
      end
    end
  end

  if not any and #pinned_cmds == 0 then
    push('')
    push('  ' .. (strings.all_mastered or ''), 'TobiraGuideMastered')
  end

  push('')
  push('  ' .. strings.hint, 'TobiraGuideHint')

  return lines, hls, strings
end

local function apply_content(lines, hls)
  vim.bo[_buf].modifiable = true
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(_buf, _ns, 0, -1)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
  end
  vim.bo[_buf].modifiable = false
end

function M.is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

function M.refresh()
  if not M.is_open() then
    return
  end
  local lines, hls = build()
  apply_content(lines, hls)
  vim.api.nvim_win_set_height(_win, #lines)
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(_win, true)
  end
  pcall(vim.api.nvim_del_augroup_by_name, 'tobira_guide_ctx')
  _win = nil
  _buf = nil
end

function M.open()
  if M.is_open() then
    return
  end

  setup_hls()

  local lines, hls, strings = build()

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'
  vim.bo[_buf].filetype = 'tobira_guide'

  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
  end

  local uis = vim.api.nvim_list_uis()
  local screen_w = (uis[1] and uis[1].width) or 120
  local screen_h = (uis[1] and uis[1].height) or 40
  local height = #lines

  _win = vim.api.nvim_open_win(_buf, false, {
    relative = 'editor',
    row = math.max(1, math.floor((screen_h - height) / 2)),
    col = screen_w - WIDTH - 2,
    width = WIDTH,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. ICON .. ' ' .. strings.title .. ' ',
    title_pos = 'center',
    focusable = false,
    zindex = 40,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = false

  -- Auto-refresh when moving between windows (context or mastery may change)
  vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('tobira_guide_ctx', { clear = true }),
    callback = function()
      if vim.api.nvim_get_current_win() == _win then
        return
      end
      vim.schedule(M.refresh)
    end,
  })
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
