-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
-- LSP Server to use for PHP.
-- Set to "intelephense" to use intelephense instead of phpactor.
vim.g.lazyvim_php_lsp = "intelephense"
-- vim.g.lazyvim_php_lsp = "phpactor"
--
-- ============================================================================
-- Filetype Detection
-- ============================================================================
vim.filetype.add({
  extension = {
    env = "dotenv", -- Treat .env extension as dotenv filetype
  },
  filename = {
    [".env"] = "dotenv", -- Treat .env file as dotenv filetype
    ["env"] = "dotenv", -- Treat env file as dotenv filetype
  },
  pattern = {
    ["[jt]sconfig.*.json"] = "jsonc", -- Treat tsconfig/jsconfig files as JSONC (allows comments)
    ["%.env%.[%w_.-]+"] = "dotenv", -- Treat .env.* files as dotenv filetype
  },
})
