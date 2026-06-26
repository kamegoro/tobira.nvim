local M = {}

function M.show(suggestion)
  local body_lines = vim.split(suggestion.body, '\n')

  local lines = {
    '  tobira — next door  ',
    string.rep('─', 44),
    '',
    '  ' .. suggestion.title,
    '',
  }

  for _, line in ipairs(body_lines) do
    table.insert(lines, '  ' .. line)
  end

  table.insert(lines, '')
  table.insert(lines, '  e.g. ' .. suggestion.example)
  table.insert(lines, '')
  table.insert(lines, '  [q / Esc] close')

  local width = 46
  local height = #lines

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'tobira'

  local uis = vim.api.nvim_list_uis()
  local screen_w = (uis[1] and uis[1].width) or 120
  local screen_h = (uis[1] and uis[1].height) or 40

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    row = math.max(0, screen_h - height - 4),
    col = math.max(0, screen_w - width - 4),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    focusable = true,
    zindex = 50,
  })

  vim.wo[win].winhl = 'Normal:TobiraFloat,FloatBorder:TobiraFloatBorder'

  if not pcall(vim.api.nvim_get_hl, 0, { name = 'TobiraFloat' }) then
    vim.api.nvim_set_hl(0, 'TobiraFloat', { link = 'NormalFloat' })
    vim.api.nvim_set_hl(0, 'TobiraFloatBorder', { link = 'FloatBorder' })
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true, silent = true })

  -- Auto-close after 15 seconds
  vim.defer_fn(close, 15000)
end

return M
