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

-- Returns usage data for a skills item.
-- Composite items (track array) use the minimum count across tracked keys.
-- Single-key items use the logger entry directly.
local function item_data(item)
  local logger = require('tobira.core.logger')
  if item.adopted then
    return logger.get(item.adopted)
  end
  if item.track then
    local min_count = math.huge
    for _, k in ipairs(item.track) do
      min_count = math.min(min_count, logger.get(k).count)
    end
    return {
      count = min_count == math.huge and 0 or min_count,
      sessions = {},
      shown = 0,
      suppressed = false,
      pinned = false,
    }
  end
  return { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false }
end

local SYM_FULL = '★' -- U+2605, 3 bytes, 1 display col
local SYM_OPEN = '☆' -- U+2606, 3 bytes, 1 display col
local SYM_SUPPRESSED = '✗' -- U+2717, 3 bytes, 1 display col

-- Returns (sym_str, sym_bytes, sym_disp_cols, hl_group).
-- sym area is always 3 display cols wide (padded with spaces).
local function mastery_sym(data)
  if data.suppressed then
    return SYM_SUPPRESSED .. '  ', 5, 3, 'TobiraGuideSuppressed'
  end
  local level = require('tobira.core.graph').mastery_level(data)
  if level == 4 then
    return SYM_FULL .. SYM_FULL .. SYM_FULL, 9, 3, 'TobiraGuideMastered'
  elseif level == 3 then
    return SYM_FULL .. SYM_FULL .. ' ', 7, 3, 'TobiraGuideLearning'
  elseif level == 2 then
    return SYM_FULL .. '  ', 5, 3, 'TobiraGuideLearning'
  elseif level == 1 then
    return SYM_OPEN .. '  ', 5, 3, 'TobiraGuideHint'
  else
    return '   ', 3, 3, nil
  end
end

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
        local data = item_data(item)
        local sym, sym_bytes, sym_disp, group = mastery_sym(data)
        local pin_mark = data.pinned and '*' or ''
        local disp_w = sym_disp + 1 + #item.keys + #pin_mark
        local pad = string.rep(' ', math.max(1, COL_W - disp_w))

        if group then
          table.insert(row_hls, { cs = byte_pos, ce = byte_pos + sym_bytes, group = group })
        end
        if data.pinned then
          local pin_cs = byte_pos + sym_bytes + 1 + #item.keys
          table.insert(row_hls, { cs = pin_cs, ce = pin_cs + 1, group = 'TobiraGuidePinned' })
        end
        line = line .. sym .. ' ' .. item.keys .. pin_mark .. pad
        byte_pos = byte_pos + sym_bytes + 1 + #item.keys + #pin_mark + #pad
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

local function item_at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lnum = row - 1
  local row_items = _line_meta[lnum]
  if not row_items then
    return nil
  end
  local cell_idx = math.floor((col - 2) / COL_W) + 1
  if cell_idx < 1 or cell_idx > #row_items then
    return nil
  end
  return row_items[cell_idx]
end

local function toggle_suppress()
  local logger = require('tobira.core.logger')
  local item = item_at_cursor()
  if not item or not item.adopted then
    return
  end
  local data = logger.get(item.adopted)
  logger.set_suppressed(item.adopted, not data.suppressed)
  refresh()
end

local function toggle_pin()
  local logger = require('tobira.core.logger')
  local item = item_at_cursor()
  if not item or not item.adopted then
    return
  end
  local data = logger.get(item.adopted)
  logger.set_pinned(item.adopted, not data.pinned)
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
  vim.keymap.set('n', 'p', toggle_pin, { buffer = _buf, nowait = true, silent = true })

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
