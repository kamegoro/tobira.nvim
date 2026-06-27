local M = {}

local _win = nil
local _buf = nil

local WIDTH = 40

local sections = {
  {
    title = '移動',
    items = {
      { keys = 'h j k l', desc = 'カーソル移動' },
      { keys = 'w / b', desc = '単語単位で移動' },
      { keys = '0 / $', desc = '行頭 / 行末' },
      { keys = 'gg / G', desc = 'ファイル先頭 / 末尾' },
      { keys = 'f{char}', desc = '文字へジャンプ' },
    },
  },
  {
    title = '編集',
    items = {
      { keys = 'i', desc = 'インサートモード' },
      { keys = 'Esc', desc = 'ノーマルモードへ戻る' },
      { keys = 'x', desc = '1文字削除' },
      { keys = 'dd', desc = '行を削除' },
      { keys = 'yy / p', desc = 'コピー / 貼り付け' },
      { keys = 'u / <C-r>', desc = 'undo / redo' },
    },
  },
  {
    title = 'ファイル',
    items = {
      { keys = ':w', desc = '保存' },
      { keys = ':q', desc = '終了' },
      { keys = ':wq', desc = '保存して終了' },
    },
  },
  {
    title = '検索',
    items = {
      { keys = '/{text}', desc = '検索' },
      { keys = 'n / N', desc = '次 / 前の結果' },
    },
  },
}

local function setup_hls()
  if vim.fn.hlexists('TobiraGuideSection') == 0 then
    vim.api.nvim_set_hl(0, 'TobiraGuideSection', { link = 'Title' })
    vim.api.nvim_set_hl(0, 'TobiraGuideKey', { link = 'Special' })
    vim.api.nvim_set_hl(0, 'TobiraGuideHint', { link = 'Comment' })
  end
end

local function build()
  local lines = {}
  local hls = {} -- { lnum (0-based), cs, ce, group }

  local function push(line, group, cs, ce)
    local lnum = #lines
    table.insert(lines, line)
    if group then
      table.insert(hls, { lnum = lnum, cs = cs or 0, ce = ce or -1, group = group })
    end
  end

  push('')

  for _, section in ipairs(sections) do
    push('')
    push('  ' .. section.title, 'TobiraGuideSection', 2, 2 + #section.title)

    for _, item in ipairs(section.items) do
      push(string.format('  %-10s  %s', item.keys, item.desc), 'TobiraGuideKey', 2, 2 + #item.keys)
    end
  end

  push('')
  push('  :TobiraGuide  ガイドを閉じる', 'TobiraGuideHint')

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
    return
  end

  setup_hls()

  local lines, hls = build()

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'
  vim.bo[_buf].filetype = 'tobira_guide'

  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, -1, hl.group, hl.lnum, hl.cs, hl.ce)
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
    title = ' tobira guide ',
    title_pos = 'center',
    focusable = false,
    zindex = 40,
  })

  vim.wo[_win].wrap = false
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
