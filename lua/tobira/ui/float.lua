local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_float')
local _prev_win = nil
local _close_token = 0
local _current_cmd = nil

local ICON = ''

local setup_hls = require('tobira.ui.hls').setup

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
  _current_cmd = nil
end

local function suppress_and_close()
  if _current_cmd ~= nil then
    require('tobira.core.logger').set_suppressed(_current_cmd, true)
  end
  close()
end

function M.show(suggestion, focused)
  local str = require('tobira.i18n').load()
  local sug_str = str.suggestions and str.suggestions[suggestion.cmd]
  if not sug_str then
    return
  end

  if _win ~= nil and vim.api.nvim_win_is_valid(_win) then
    close()
  end

  _current_cmd = suggestion.cmd
  if focused then
    _prev_win = vim.api.nvim_get_current_win()
  end

  setup_hls()

  local lines = { '' }
  for part in (sug_str.body .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, '  ' .. part)
  end
  if sug_str.example and sug_str.example ~= '' then
    table.insert(lines, '')
    table.insert(lines, '  ' .. str.float.example_prefix .. sug_str.example)
  end
  table.insert(lines, '')
  local hint_lnum = nil
  if focused then
    hint_lnum = #lines -- 0-indexed line number for the hint
    table.insert(lines, '  ' .. str.float.suppress_hint)
    table.insert(lines, '')
  end

  -- Compute window width to fit the widest line and the title.
  local title_text = ' ' .. ICON .. ' ' .. sug_str.title .. ' '
  local max_len = vim.fn.strdisplaywidth(title_text) + 2
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_len then
      max_len = w
    end
  end

  local uis = vim.api.nvim_list_uis()
  local screen_w = uis[1] and uis[1].width or 120
  local screen_h = uis[1] and uis[1].height or 40
  local win_w = math.min(max_len + 2, screen_w - 6)
  local win_h = #lines

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'

  if hint_lnum then
    vim.api.nvim_buf_add_highlight(_buf, _ns, 'TobiraGuideHint', hint_lnum, 0, -1)
  end

  if focused then
    vim.keymap.set('n', 'x', suppress_and_close, { buffer = _buf, nowait = true, silent = true })
    vim.keymap.set('n', 'q', close, { buffer = _buf, nowait = true, silent = true })
    vim.keymap.set('n', '<Esc>', close, { buffer = _buf, nowait = true, silent = true })
  end

  _win = vim.api.nvim_open_win(_buf, focused == true, {
    relative = 'editor',
    row = math.max(1, screen_h - win_h - 3),
    col = math.max(1, screen_w - win_w - 2),
    width = win_w,
    height = win_h,
    style = 'minimal',
    border = 'rounded',
    title = title_text,
    title_pos = 'left',
    focusable = focused == true,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false

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

  -- Auto-close after 10 seconds.
  local my_token = _close_token
  vim.defer_fn(function()
    if _close_token == my_token then
      close()
    end
  end, 10000)
end

function M.is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

function M.close()
  close()
end

return M
