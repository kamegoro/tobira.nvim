if vim.g.loaded_tobira then
  return
end
vim.g.loaded_tobira = true

vim.api.nvim_create_user_command('Tobira', function()
  require('tobira.core.suggest').manual()
end, { desc = 'Show next command suggestion' })

vim.api.nvim_create_user_command('TobiraStats', function()
  require('tobira.ui.stats').show()
end, { desc = 'Show command usage stats' })

vim.api.nvim_create_user_command('TobiraGuide', function()
  require('tobira.ui.guide').toggle()
end, { desc = 'Toggle vim guide panel' })

vim.api.nvim_create_user_command('TobiraProgress', function()
  require('tobira.ui.progress').open()
end, { desc = 'Show vim skill progress tree' })

vim.api.nvim_create_user_command('TobiraReset', function(opts)
  require('tobira').reset(opts.bang)
end, { bang = true, desc = 'Reset usage log (! skips the confirmation)' })
