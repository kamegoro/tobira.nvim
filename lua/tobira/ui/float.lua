local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_float')
local _prev_win = nil
local _close_token = 0

local ICON = '🚪'

local setup_hls = require('tobira.ui.hls').setup

local CATEGORY_HL = {
  motion = 'TobiraSuggestMotion',
  edit = 'TobiraSuggestEdit',
  search = 'TobiraSuggestSearch',
  window = 'TobiraSuggestWindow',
  fold = 'TobiraSuggestFold',
  mark = 'TobiraSuggestMark',
  macro = 'TobiraSuggestMacro',
}
local DEFAULT_BORDER_HL = 'FloatBorder'

local function close()
  _close_token = _close_token + 1
  if _win ~= nil and vim.api.nvim_win_is_valid(_win) then
    vim.api.nvim_win_close(_win, true)
  end
  if _prev_win ~= nil and vim.api.nvim_win_is_valid(_prev_win) then
    pcall(vim.api.nvim_set_current_win, _prev_win)
  end
  _win = nil
  _buf = nil
  _prev_win = nil
end

-- Rounded border with every segment tagged with the same highlight group, so
-- the whole border reads as one color (mirrors nvim-notify's per-level border).
--
-- Box-drawing characters are Unicode "Ambiguous width": narrow (1 cell) under
-- the default ambiwidth='single', but double-width under ambiwidth='double'
-- (set by users to match wide CJK fonts). Unlike the 'rounded' string preset
-- (used by guide.lua/progress.lua/stats.lua), a custom per-segment border
-- table is validated cell-by-cell, so it hard-errors with "expected only
-- one-cell chars" under ambiwidth='double' (#89). Fall back to plain ASCII
-- only in that case, so everyone else keeps the nicer rounded border.
local function border_with_hl(hl)
  if vim.o.ambiwidth == 'double' then
    return {
      { '+', hl },
      { '-', hl },
      { '+', hl },
      { '|', hl },
      { '+', hl },
      { '-', hl },
      { '+', hl },
      { '|', hl },
    }
  end
  return {
    { '╭', hl },
    { '─', hl },
    { '╮', hl },
    { '│', hl },
    { '╯', hl },
    { '─', hl },
    { '╰', hl },
    { '│', hl },
  }
end

-- Splits "cmd — description" into highlighted chunks so the answer itself
-- (the suggested key) stands out from the explanatory text. Every suggestion
-- title is guaranteed to contain the separator (locale_spec.lua enforces it).
local function title_chunks(title)
  local sep_start = title:find(' — ', 1, true)
  local key_part = title:sub(1, sep_start - 1)
  local rest = title:sub(sep_start) -- includes the leading " — "
  return {
    { ' ' .. ICON .. ' ', 'TobiraGuideSection' },
    { key_part, 'TobiraSuggestKey' },
    { rest .. ' ', 'TobiraGuideSection' },
  }
end

local function plain_title(title)
  return ' ' .. ICON .. ' ' .. title .. ' '
end

-- Content-scaled auto-dismiss duration, clamped to the toast-notification
-- convention of roughly 6-9 seconds of on-screen time.
local function auto_close_duration(line_count)
  return math.min(9000, math.max(6000, 2500 + (line_count * 700)))
end

function M.show(suggestion, focused, pattern)
  local str = require('tobira.i18n').load()
  local sug_str = str.suggestions and str.suggestions[suggestion.cmd]
  if not sug_str then
    return
  end

  if _win ~= nil and vim.api.nvim_win_is_valid(_win) then
    close()
  end

  if focused then
    _prev_win = vim.api.nvim_get_current_win()
  end

  setup_hls()

  local reason = nil
  if pattern and str.float.reasons and str.float.reasons[pattern] then
    reason = str.float.reasons[pattern]
  elseif suggestion.trigger then
    reason = str.float.ambient_reason:format(suggestion.trigger)
  end

  local lines = { '' }
  local reason_lnum = nil
  if reason then
    reason_lnum = #lines
    table.insert(lines, '  ' .. reason)
    table.insert(lines, '')
  end
  for part in (sug_str.body .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, '  ' .. part)
  end
  if sug_str.example and sug_str.example ~= '' then
    table.insert(lines, '')
    table.insert(lines, '  ' .. str.float.example_prefix .. sug_str.example)
  end
  table.insert(lines, '')

  local footer = str.float.suppress_hint
  if focused then
    footer = footer .. '  ·  ' .. str.float.close_hint
  end
  local hint_lnum = #lines
  table.insert(lines, '  ' .. footer)
  table.insert(lines, '')

  -- Compute window width to fit the widest line and the title.
  local max_len = vim.fn.strdisplaywidth(plain_title(sug_str.title)) + 2
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_len then
      max_len = w
    end
  end

  local uis = vim.api.nvim_list_uis()
  local screen_w = uis[1] and uis[1].width or 120
  local win_w = math.min(max_len + 2, screen_w - 6)
  local win_h = #lines

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'

  if reason_lnum then
    vim.api.nvim_buf_add_highlight(_buf, _ns, 'TobiraSuggestReason', reason_lnum, 0, -1)
  end
  vim.api.nvim_buf_add_highlight(_buf, _ns, 'TobiraGuideHint', hint_lnum, 0, -1)

  if focused then
    vim.keymap.set('n', 'q', close, { buffer = _buf, nowait = true, silent = true })
    vim.keymap.set('n', '<Esc>', close, { buffer = _buf, nowait = true, silent = true })
  end

  local border_hl = (suggestion.category and CATEGORY_HL[suggestion.category]) or DEFAULT_BORDER_HL

  _win = vim.api.nvim_open_win(_buf, focused == true, {
    relative = 'editor',
    row = 1,
    col = math.max(1, screen_w - win_w - 2),
    width = win_w,
    height = win_h,
    style = 'minimal',
    border = border_with_hl(border_hl),
    title = title_chunks(sug_str.title),
    title_pos = 'left',
    focusable = focused == true,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false

  if not focused then
    -- enter=false means no cursor movement and no automatic terminal redraw.
    -- Force one so the window appears immediately in the TUI.
    vim.cmd('redraw')
  end

  if focused then
    -- Auto-close if the user navigates away without pressing x/q/Esc.
    vim.api.nvim_create_autocmd('WinLeave', {
      buffer = _buf,
      once = true,
      callback = function()
        vim.defer_fn(close, 0)
      end,
    })
  end

  local my_token = _close_token
  vim.defer_fn(function()
    if _close_token == my_token then
      close()
    end
  end, auto_close_duration(#lines))
end

-- Fired once, the first time a suggested command is actually adopted. Distinct
-- styling (TobiraCelebrate, short duration) keeps it from reading as a new
-- suggestion — it closes the cue → routine → reward loop that mark_adopted()
-- alone leaves silent.
function M.celebrate(cmd)
  local str = require('tobira.i18n').load()

  if _win ~= nil and vim.api.nvim_win_is_valid(_win) then
    close()
  end

  setup_hls()

  local lines = { '', '  ✓ ' .. str.float.celebrate:format(cmd), '' }

  local title = plain_title('tobira')
  local max_len = vim.fn.strdisplaywidth(title) + 2
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_len then
      max_len = w
    end
  end

  local uis = vim.api.nvim_list_uis()
  local screen_w = uis[1] and uis[1].width or 120
  local win_w = math.min(max_len + 2, screen_w - 6)
  local win_h = #lines

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'

  vim.api.nvim_buf_add_highlight(_buf, _ns, 'TobiraCelebrate', 1, 0, -1)

  _win = vim.api.nvim_open_win(_buf, false, {
    relative = 'editor',
    row = 1,
    col = math.max(1, screen_w - win_w - 2),
    width = win_w,
    height = win_h,
    style = 'minimal',
    border = border_with_hl('TobiraCelebrate'),
    title = title,
    title_pos = 'left',
    focusable = false,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false

  vim.cmd('redraw')

  local my_token = _close_token
  vim.defer_fn(function()
    if _close_token == my_token then
      close()
    end
  end, 3500)
end

function M.is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

function M.close()
  close()
end

return M
