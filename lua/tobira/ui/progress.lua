local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_progress')
local _line_meta = {} -- lnum (0-indexed) → list of skill items on that line

local WIDTH = 56
local COLS = 3
local COL_W = 13
local ICON = ''

local setup_hls = require('tobira.ui.hls').setup

local SYM_LEARNED = '✓' -- U+2713, 3 bytes, 1 display col
local SYM_PENDING = '○' -- U+25CB, 3 bytes, 1 display col
local SYM_SUPPRESSED = '✗' -- U+2717, 3 bytes, 1 display col

local function build()
  local skills = require('tobira.core.skills')
  local logger = require('tobira.core.logger')
  local graph = require('tobira.core.graph')
  local level = require('tobira.core.level')
  local loc = require('tobira.i18n').load()
  local str = loc.progress

  local usage = logger.get_all()

  local lines = {}
  local hls = {}
  local line_meta = {}

  local function push(line, group, cs, ce)
    local lnum = #lines
    table.insert(lines, line)
    if group then
      table.insert(hls, { lnum = lnum, group = group, cs = cs or 0, ce = ce or -1 })
    end
  end

  push('')

  local lv = level.get()
  local lv_label = str.levels[lv] or lv
  push('  ' .. str.level_label .. lv_label, 'TobiraGuideSection', 2, -1)

  for _, cat in ipairs(skills.tree) do
    push('')
    local cat_label = str.categories[cat.id] or cat.id
    push('  ' .. cat_label, 'TobiraGuideSection', 2, 2 + #cat_label)

    local items = cat.items
    local row_start = 1
    while row_start <= #items do
      local row_items = {}
      for i = row_start, math.min(row_start + COLS - 1, #items) do
        table.insert(row_items, items[i])
      end

      local line = '  '
      local byte_pos = 2
      local row_hls = {}

      for _, item in ipairs(row_items) do
        local data = logger.get(item.adopted)
        local sym, group
        if data.suppressed then
          sym = SYM_SUPPRESSED
          group = 'TobiraGuideSuppressed'
        elseif skills.is_learned(item, usage) then
          sym = SYM_LEARNED
          group = 'TobiraGuideMastered'
        else
          sym = SYM_PENDING
          group = 'TobiraGuideHint'
        end
        local label = sym .. ' ' .. item.keys
        local disp_w = 1 + 1 + #item.keys
        local pad = string.rep(' ', math.max(1, COL_W - disp_w))

        table.insert(row_hls, { cs = byte_pos, ce = byte_pos + #label, group = group })
        line = line .. label .. pad
        byte_pos = byte_pos + #label + #pad
      end

      local lnum = #lines
      line_meta[lnum] = row_items
      table.insert(lines, line)
      for _, hl in ipairs(row_hls) do
        table.insert(hls, { lnum = lnum, group = hl.group, cs = hl.cs, ce = hl.ce })
      end

      row_start = row_start + COLS
    end
  end

  local next_cmd = graph.find_best(usage)
  if next_cmd then
    local sug_str = loc.suggestions and loc.suggestions[next_cmd]
    local title = sug_str and sug_str.title or next_cmd
    push('')
    push('  ' .. str.next .. title, 'TobiraGuideUpgrade')
  end

  push('')
  push('  ' .. str.hint, 'TobiraGuideHint')

  return lines, hls, str, line_meta
end

local function refresh()
  if not _buf or not vim.api.nvim_buf_is_valid(_buf) then
    return
  end
  local lines, hls, _, line_meta = build()
  _line_meta = line_meta
  vim.bo[_buf].modifiable = true
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(_buf, _ns, 0, -1)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
  end
end

local function toggle_suppress()
  local logger = require('tobira.core.logger')
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lnum = row - 1
  local row_items = _line_meta[lnum]
  if not row_items then
    return
  end
  local cell_idx = math.floor((col - 2) / COL_W) + 1
  if cell_idx < 1 or cell_idx > #row_items then
    return
  end
  local item = row_items[cell_idx]
  local cmd = item.adopted
  local data = logger.get(cmd)
  logger.set_suppressed(cmd, not data.suppressed)
  refresh()
end

function M.is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(_win, true)
  end
  _win = nil
  _buf = nil
end

function M.open()
  if M.is_open() then
    M.close()
    return
  end

  setup_hls()

  local lines, hls, str, line_meta = build()
  _line_meta = line_meta

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'
  vim.bo[_buf].filetype = 'tobira_progress'

  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
  end

  vim.keymap.set('n', 'q', M.close, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', '<Esc>', M.close, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', 'x', toggle_suppress, { buffer = _buf, nowait = true, silent = true })

  local uis = vim.api.nvim_list_uis()
  local screen_w = (uis[1] and uis[1].width) or 120
  local screen_h = (uis[1] and uis[1].height) or 40
  local height = #lines

  _win = vim.api.nvim_open_win(_buf, true, {
    relative = 'editor',
    row = math.max(1, math.floor((screen_h - height) / 2)),
    col = math.max(1, math.floor((screen_w - WIDTH) / 2)),
    width = WIDTH,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. ICON .. ' ' .. str.title .. ' ',
    title_pos = 'center',
    focusable = true,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false
end

return M
