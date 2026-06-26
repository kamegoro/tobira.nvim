if vim.g.loaded_tobira then return end
vim.g.loaded_tobira = true

vim.api.nvim_create_user_command("Tobira", function()
  require("tobira.core.suggest").show()
end, { desc = "Show next command suggestion" })

vim.api.nvim_create_user_command("TobiraProgress", function()
  require("tobira.ui.tree").show()
end, { desc = "Show skill tree" })

vim.api.nvim_create_user_command("TobiraStats", function()
  require("tobira.core.logger").stats()
end, { desc = "Show usage statistics" })

vim.api.nvim_create_user_command("TobiraReset", function()
  require("tobira.core.logger").reset()
end, { desc = "Reset usage log" })
