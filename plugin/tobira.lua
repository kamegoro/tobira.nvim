if vim.g.loaded_tobira then
  return
end
vim.g.loaded_tobira = true

vim.api.nvim_create_user_command('Tobira', function()
  require('tobira.core.suggest').manual()
end, { desc = 'Show next command suggestion' })

vim.api.nvim_create_user_command('TobiraStats', function()
  require('tobira.core.logger').stats()
end, { desc = 'Show command usage stats' })

vim.api.nvim_create_user_command('TobiraReset', function()
  local logger = require('tobira.core.logger')
  logger.reset()
  logger.save()
end, { desc = 'Reset usage log' })
