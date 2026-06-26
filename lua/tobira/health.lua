local M = {}

function M.check()
  vim.health.start('tobira.nvim')

  if vim.fn.has('nvim-0.8') == 1 then
    vim.health.ok('Neovim 0.8+ detected')
  else
    vim.health.error('Neovim 0.8+ is required')
  end

  local data_dir = vim.fn.stdpath('data') .. '/tobira'
  if vim.fn.isdirectory(data_dir) == 1 then
    vim.health.ok('data directory: ' .. data_dir)
  else
    vim.health.info('data directory will be created on first use: ' .. data_dir)
  end

  local usage_file = data_dir .. '/usage.json'
  if vim.fn.filereadable(usage_file) == 1 then
    vim.health.ok('usage log found: ' .. usage_file)
  else
    vim.health.info('no usage log yet — start using Neovim to build your profile')
  end
end

return M
