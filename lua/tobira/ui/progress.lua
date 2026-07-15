local M = {}

local _win = nil
local _buf = nil
local _prev_win = nil
local _ns = vim.api.nvim_create_namespace('tobira_progress')
local _preview_ns = vim.api.nvim_create_namespace('tobira_progress_preview')
local _line_meta = {} -- lnum (0-indexed) → list of skill items on that line
local _preview_lnum = nil -- lnum (0-indexed) where the 2-line preview strip starts

local COLS = 4
local COL_W = 14
local PANEL_W = 2 + COLS * COL_W -- 58: matches one full grid row's display width
local SPARK_W = 5
local ICON = ''

local THRESHOLDS = { 1, 100, 1000, 5000 }
local THRESHOLD_SYM = { '☆', '★', '★★', '★★★' }

local setup_hls = require('tobira.ui.hls').setup

-- Returns usage data for a skills item, given an explicit usage table (pure —
-- no logger.get()/get_all() call here, so callers control the data source).
-- Composite items (track array) use the minimum count across tracked keys.
-- Single-key items look up the logger entry directly.
local function item_data(item, usage)
  if item.adopted then
    return usage[item.adopted] or { count = 0, sessions = {}, shown = 0, suppressed = false, pinned = false }
  end
  local min_count = math.huge
  for _, k in ipairs(item.track) do
    local d = usage[k]
    min_count = math.min(min_count, d and d.count or 0)
  end
  return {
    count = min_count == math.huge and 0 or min_count,
    sessions = {},
    shown = 0,
    suppressed = false,
    pinned = false,
  }
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

-- Given a count, returns (n, sym) where n is how many more uses are needed to
-- reach the next mastery threshold and sym is that threshold's glyph. Returns
-- nil when count is already at or past the highest threshold.
local function next_milestone(count)
  for i, t in ipairs(THRESHOLDS) do
    if count < t then
      return t - count, THRESHOLD_SYM[i]
    end
  end
  return nil, nil
end

local function status_tag(data, str)
  local graph = require('tobira.core.graph')
  if (data.count or 0) == 0 then
    return str.preview.never_tried
  end
  if graph.is_forgotten(data) then
    return str.preview.forgotten
  end
  if graph.is_mastered(data) then
    return str.preview.mastered
  end
  return str.preview.learning
end

-- Pure: returns the two preview-strip lines (+ empty hls, no highlighting
-- needed there beyond plain text) for whatever item is under the cursor, or
-- two blank lines when item is nil — callers must render both cases at the
-- same line count so the window height never jumps as the cursor moves.
function M.preview_lines(item, usage)
  if not item then
    return '', ''
  end

  local loc = require('tobira.i18n').load()
  local str = loc.progress
  local graph = require('tobira.core.graph')
  local data = item_data(item, usage)

  local desc = item.keys
  if item.adopted then
    local sug = loc.suggestions and loc.suggestions[item.adopted]
    if sug then
      desc = sug.title:match(' — (.+)$') or sug.title
    end
  end
  local line1 = string.format('  %-6s%s', item.keys, desc)

  local spark_str = require('tobira.ui.spark').render(data.sessions or {}, SPARK_W)
  local count = data.count or 0
  local count_str = count > 0 and (tostring(count) .. '×') or ''
  local tag = status_tag(data, str)

  local distance = ''
  if not graph.is_mastered(data) then
    local n, sym = next_milestone(count)
    if n then
      distance = '    ' .. str.preview.to_next:format(n, sym)
    end
  end

  local line2 = string.format('        %s   %s   %s%s', spark_str, count_str, tag, distance)

  return line1, line2
end

local function separator()
  return '  ' .. string.rep('─', PANEL_W - 2)
end

-- Pure: takes usage explicitly (mirrors ui/stats.lua's M.render(usage) and
-- ui/guide.lua's M.build(usage)). Returns the preview strip as two blank
-- placeholder lines — the caller (open()/refresh()) fills them in via
-- update_preview() based on the live cursor position, since the cursor
-- doesn't exist yet at build() time.
function M.build(usage)
  local skills = require('tobira.core.skills')
  local graph = require('tobira.core.graph')
  local level = require('tobira.core.level')
  local loc = require('tobira.i18n').load()
  local str = loc.progress

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

  -- ── H1: level (left) + mastered ratio (right) ──────────────────────────────
  local total_mastered, total_items = 0, 0
  for _, cat in ipairs(skills.tree) do
    for _, item in ipairs(cat.items) do
      total_items = total_items + 1
      if graph.mastery_level(item_data(item, usage)) >= 2 then
        total_mastered = total_mastered + 1
      end
    end
  end

  push('')
  local lv = level.get(usage)
  local lv_label = str.levels[lv] or lv
  local h1_left = '  ' .. str.level_label .. lv_label
  local h1_right = str.mastered_total:format(total_mastered, total_items)
  local h1_pad = math.max(1, PANEL_W - vim.fn.strdisplaywidth(h1_left) - vim.fn.strdisplaywidth(h1_right))
  push(h1_left .. string.rep(' ', h1_pad) .. h1_right, 'TobiraH1')
  push(separator(), 'TobiraGuideHint')

  -- ── category grids ──────────────────────────────────────────────────────────
  for _, cat in ipairs(skills.tree) do
    push('')
    local cat_label = str.categories[cat.id] or cat.id
    local done = 0
    for _, item in ipairs(cat.items) do
      if graph.mastery_level(item_data(item, usage)) >= 2 then
        done = done + 1
      end
    end
    local count_str = str.section_count:format(done, #cat.items)
    local header = '  ' .. cat_label .. '    ' .. count_str
    push(header, 'TobiraGuideSection', 2, 2 + #cat_label)
    table.insert(hls, { lnum = #lines - 1, group = 'TobiraGuideHint', cs = 2 + #cat_label + 4, ce = -1 })

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
        local data = item_data(item, usage)
        local sym, sym_bytes, sym_disp, group = mastery_sym(data)
        local pin_mark = data.pinned and '●' or ''
        local pin_disp = data.pinned and 1 or 0
        local disp_w = sym_disp + 1 + #item.keys + pin_disp
        local pad = string.rep(' ', math.max(1, COL_W - disp_w))

        if group and data.count > 0 then
          table.insert(row_hls, { cs = byte_pos, ce = byte_pos + sym_bytes, group = group })
        elseif data.count == 0 then
          -- Level 0: no glyph, whole cell dimmed instead (no ○ marker, no NEW badge — #67).
          table.insert(
            row_hls,
            { cs = byte_pos + sym_bytes + 1, ce = byte_pos + sym_bytes + 1 + #item.keys, group = 'TobiraDim' }
          )
        end
        if data.pinned then
          local pin_cs = byte_pos + sym_bytes + 1 + #item.keys
          table.insert(row_hls, { cs = pin_cs, ce = pin_cs + #pin_mark, group = 'TobiraGuidePinned' })
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

  -- ── preview strip (content filled in by update_preview() after open/refresh) ─
  -- The nav_hint keybinding line is NOT here: it is pinned to the window footer
  -- in M.open() so it stays visible while the skill tree scrolls, instead of
  -- being buried at the bottom of the scrollable buffer.
  push('')
  push(separator(), 'TobiraGuideHint')
  push('')
  local preview_lnum = #lines
  push('')
  push('')
  push('')

  return lines, hls, str, line_meta, preview_lnum
end

local function apply_content(lines, hls)
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
  if cell_idx < 1 then
    return nil
  end
  return row_items[cell_idx]
end

-- Re-renders only the 2-line preview strip in place (not the whole buffer),
-- so moving the cursor doesn't reset scroll position or flicker the grid.
--
-- No is_open()/_preview_lnum guard here: every caller (M.open(), refresh(),
-- the CursorMoved autocmd) only runs while the window is open, and Neovim
-- clears buffer-scoped autocmds synchronously when the buffer is wiped, so
-- CursorMoved cannot fire for this buffer after M.close() runs. A guard for
-- that combination would be unreachable dead code.
local function update_preview()
  local usage = require('tobira.core.logger').get_all()
  local item = item_at_cursor()
  local line1, line2 = M.preview_lines(item, usage)

  vim.bo[_buf].modifiable = true
  vim.api.nvim_buf_set_lines(_buf, _preview_lnum, _preview_lnum + 2, false, { line1, line2 })
  vim.bo[_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(_buf, _preview_ns, _preview_lnum, _preview_lnum + 2)
end

local function refresh()
  local lines, hls, _, line_meta, preview_lnum = M.build(require('tobira.core.logger').get_all())
  _line_meta = line_meta
  _preview_lnum = preview_lnum
  apply_content(lines, hls)
  update_preview()
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
  if _prev_win ~= nil and vim.api.nvim_win_is_valid(_prev_win) then
    pcall(vim.api.nvim_set_current_win, _prev_win)
  end
  pcall(vim.api.nvim_del_augroup_by_name, 'tobira_progress_preview')
  _win = nil
  _buf = nil
  _prev_win = nil
  _preview_lnum = nil
end

function M.open()
  if M.is_open() then
    M.close()
    return
  end

  _prev_win = vim.api.nvim_get_current_win()
  setup_hls()

  local lines, hls, str, line_meta, preview_lnum = M.build(require('tobira.core.logger').get_all())
  _line_meta = line_meta
  _preview_lnum = preview_lnum

  local uis = vim.api.nvim_list_uis()
  local screen_w = (uis[1] and uis[1].width) or 120
  local screen_h = (uis[1] and uis[1].height) or 40

  local title_text = ' ' .. ICON .. ' ' .. str.title .. ' '
  local footer_text = ' ' .. str.nav_hint .. ' '
  local max_w = 0
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_w then
      max_w = w
    end
  end
  -- title and footer aren't in `lines`, so fold their widths in afterwards (the
  -- footer especially can be wider than any grid row). Done after the loop so
  -- the loop always drives max_w from 0 rather than starting above every row.
  max_w = math.max(max_w, vim.fn.strdisplaywidth(title_text) + 2, vim.fn.strdisplaywidth(footer_text) + 2)
  local win_w = math.min(max_w + 2, screen_w - 6)
  -- Leave vertical breathing room so the panel reads as a floating modal, not a
  -- full-screen takeover. Centered, screen_h - 12 keeps a couple of editor rows
  -- between the panel's footer and the editor's own statusline, so the two
  -- bottom bars don't blur together.
  local win_h = math.min(#lines, screen_h - 12)

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
  vim.keymap.set('n', 'g', function()
    M.close()
    require('tobira.ui.guide').open()
  end, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', 's', function()
    M.close()
    require('tobira.ui.stats').open()
  end, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', '?', function()
    vim.notify(str.keybind_help, vim.log.levels.INFO)
  end, { buffer = _buf, nowait = true, silent = true })

  _win = vim.api.nvim_open_win(_buf, true, {
    relative = 'editor',
    row = math.max(1, math.floor((screen_h - win_h) / 2)),
    col = math.max(1, math.floor((screen_w - win_w) / 2)),
    width = win_w,
    height = win_h,
    style = 'minimal',
    border = 'rounded',
    title = title_text,
    title_pos = 'center',
    footer = { { footer_text, 'TobiraGuideHint' } },
    footer_pos = 'center',
    focusable = true,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false
  vim.wo[_win].scrolloff = 0

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = _buf,
    group = vim.api.nvim_create_augroup('tobira_progress_preview', { clear = true }),
    callback = update_preview,
  })
  update_preview()

  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = _buf,
    once = true,
    callback = function()
      vim.defer_fn(M.close, 0)
    end,
  })
end

return M
