local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_progress')

local WIDTH = 56
local COLS = 3
local COL_W = 13 -- display columns per grid cell
local ICON = '' -- nerd font (matches nvim-notify INFO)

local function load_strings()
  local lang = require('tobira.core.config').values.lang
  local ok, loc = pcall(require, 'tobira.locales.' .. lang)
  if not ok then
    loc = require('tobira.locales.en')
  end
  return loc.progress
end

local function setup_hls()
  if vim.fn.hlexists('TobiraGuideBorder') == 1 then
    return
  end
  local has_notify = pcall(require, 'notify') and vim.fn.hlexists('NotifyINFOBorder') == 1
  if has_notify then
    vim.api.nvim_set_hl(0, 'TobiraGuideBorder', { link = 'NotifyINFOBorder' })
    vim.api.nvim_set_hl(0, 'TobiraGuideNormal', { link = 'NotifyINFOBody' })
    vim.api.nvim_set_hl(0, 'TobiraGuideSection', { link = 'NotifyINFOTitle' })
  else
    vim.api.nvim_set_hl(0, 'TobiraGuideBorder', { link = 'FloatBorder' })
    vim.api.nvim_set_hl(0, 'TobiraGuideNormal', { link = 'NormalFloat' })
    vim.api.nvim_set_hl(0, 'TobiraGuideSection', { link = 'Title' })
  end
  vim.api.nvim_set_hl(0, 'TobiraGuideMastered', { link = 'DiagnosticOk' })
  vim.api.nvim_set_hl(0, 'TobiraGuideUpgrade', { link = 'DiagnosticHint' })
  vim.api.nvim_set_hl(0, 'TobiraGuideHint', { link = 'Comment' })
end

local SYM_LEARNED = '✓' -- U+2713, 3 bytes, 1 display col
local SYM_PENDING = '○' -- U+25CB, 3 bytes, 1 display col

local function build()
  local skills = require('tobira.core.skills')
  local logger = require('tobira.core.logger')
  local graph = require('tobira.core.graph')
  local level = require('tobira.core.level')
  local str = load_strings()

  local usage = logger.get_all()

  local lines = {}
  local hls = {}

  local function push(line, group, cs, ce)
    local lnum = #lines
    table.insert(lines, line)
    if group then
      table.insert(hls, { lnum = lnum, group = group, cs = cs or 0, ce = ce or -1 })
    end
  end

  push('')

  -- Level banner
  local lv = level.get()
  local lv_label = (str.levels and str.levels[lv]) or lv
  push('  Level: ' .. lv_label, 'TobiraGuideSection', 2, -1)

  -- Skill tree grid
  for _, cat in ipairs(skills.tree) do
    push('')
    local cat_label = (str.categories and str.categories[cat.id]) or cat.id
    push('  ' .. cat_label, 'TobiraGuideSection', 2, 2 + #cat_label)

    -- Chunk items into rows of COLS
    local items = cat.items
    local row_start = 1
    while row_start <= #items do
      local row_items = {}
      for i = row_start, math.min(row_start + COLS - 1, #items) do
        table.insert(row_items, items[i])
      end

      -- Build the grid row
      local line = '  '
      local byte_pos = 2 -- after the indent
      local row_hls = {}

      for _, item in ipairs(row_items) do
        local learned = skills.is_learned(item, usage)
        local sym = learned and SYM_LEARNED or SYM_PENDING
        local group = learned and 'TobiraGuideMastered' or 'TobiraGuideHint'
        -- sym is 3 bytes but 1 display col
        -- item.keys is ASCII
        local label = sym .. ' ' .. item.keys
        local disp_w = 1 + 1 + #item.keys -- sym(1 disp) + space + key_bytes
        local pad = string.rep(' ', math.max(1, COL_W - disp_w))

        table.insert(row_hls, { cs = byte_pos, ce = byte_pos + #label, group = group })
        line = line .. label .. pad
        byte_pos = byte_pos + #label + #pad
      end

      local lnum = #lines
      table.insert(lines, line)
      for _, hl in ipairs(row_hls) do
        table.insert(hls, { lnum = lnum, group = hl.group, cs = hl.cs, ce = hl.ce })
      end

      row_start = row_start + COLS
    end
  end

  -- Next recommendation
  local next_cmd = graph.find_best(usage)
  if next_cmd then
    local sug = graph.suggestions[next_cmd]
    push('')
    push('  ' .. (str.next or 'Next: ') .. sug.title, 'TobiraGuideUpgrade')
  end

  push('')
  push('  ' .. (str.hint or '[q / Esc]  close'), 'TobiraGuideHint')

  return lines, hls
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

  local lines, hls = build()

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
    title = ' ' .. ICON .. ' tobira — your vim journey ',
    title_pos = 'center',
    focusable = true,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false
end

return M
