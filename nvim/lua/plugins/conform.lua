return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      php = { "pint" },
      html = { "prettier" },
      css = { "prettier" },
      blade = { "tlint" },
      cs = { "csharpier" },
      ["*"] = { "codespell" },
    },
  },
}
