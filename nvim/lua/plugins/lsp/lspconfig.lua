return {
  "neovim/nvim-lspconfig",
  opts = function()
    local lspconfig = require("lspconfig")
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")

    mason.setup()

    -- Configure Intelephense
    lspconfig.intelephense.setup({
      on_attach = function(client, bufnr)
        -- Disable formatting capability (use Pint instead)
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end,
      settings = {
        intelephense = {
          -- Disable format to avoid conflicts with Pint
          format = {
            enable = false,
          },
          -- Adjust diagnostics
          diagnostics = {
            enable = true,
            undefinedTypes = false,
            undefinedFunctions = false,
            undefinedConstants = false,
            undefinedClassConstants = false,
            undefinedMethods = false,
            undefinedProperties = false,
          },
          -- Include common PHP stubs
          stubs = {
            "apache",
            "bcmath",
            "bz2",
            "calendar",
            "Core",
            "ctype",
            "curl",
            "date",
            "dom",
            "fileinfo",
            "filter",
            "ftp",
            "gd",
            "gettext",
            "hash",
            "iconv",
            "intl",
            "json",
            "libxml",
            "mbstring",
            "mysqli",
            "openssl",
            "pcre",
            "PDO",
            "pdo_mysql",
            "Phar",
            "posix",
            "Reflection",
            "session",
            "SimpleXML",
            "soap",
            "sockets",
            "sodium",
            "SPL",
            "standard",
            "superglobals",
            "tokenizer",
            "xml",
            "xmlreader",
            "xmlwriter",
            "zip",
            "zlib",
            "wordpress",
            "phpunit",
            "laravel",
          },
          files = {
            maxSize = 5000000,
          },
        },
      },
    })

    -- Configure Laravel LS
    lspconfig.laravel_ls.setup({})

    -- Configure Emmet
    lspconfig.emmet_ls.setup({
      on_attach = function(client, bufnr)
        local buf_set_option = vim.api.nvim_buf_set_option
        buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
      end,
      filetypes = { "blade", "html", "css" },
      flags = {
        debounce_text_changes = 150,
      },
    })

    -- Ensure LSP servers are installed
    mason_lspconfig.setup({
      ensure_installed = {
        "intelephense",
        "laravel_ls",
        "emmet_ls",
      },
    })
  end,
}
