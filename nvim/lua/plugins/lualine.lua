return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Add custom components to show active linters and LSP servers
    table.insert(opts.sections.lualine_x, 1, {
      function()
        local linters = require("lint").linters_by_ft[vim.bo.filetype] or {}
        if #linters > 0 then
          return " " .. table.concat(linters, ", ")
        end
        return ""
      end,
      color = { fg = "#f9e2af" },
    })
    
    table.insert(opts.sections.lualine_x, 1, {
      function()
        local clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if #clients > 0 then
          local names = {}
          for _, client in ipairs(clients) do
            table.insert(names, client.name)
          end
          return " " .. table.concat(names, ", ")
        end
        return ""
      end,
      color = { fg = "#89b4fa" },
    })
    
    return opts
  end,
}
