return {
  "mfussenegger/nvim-lint",
  opts = function(_, opts)
    opts.linters_by_ft = opts.linters_by_ft or {}
    opts.linters_by_ft.php = { "php" } -- Uses PHP's built-in syntax checker

    return opts
  end,
}
