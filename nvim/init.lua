vim.g.mapleader = " "
vim.g.maplocalleader = " "

local neovim_python = vim.env.NVIM_PYTHON
if not neovim_python or vim.fn.executable(neovim_python) ~= 1 then
  local legacy_python = vim.fn.expand("~/.venvs/neovim/bin/python")
  neovim_python = vim.fn.executable(legacy_python) == 1 and legacy_python or vim.fn.exepath("python3")
end

local neovim_python_dir = vim.fn.fnamemodify(neovim_python, ":h")
local neovim_jupyter = vim.env.NVIM_JUPYTER
if not neovim_jupyter or vim.fn.executable(neovim_jupyter) ~= 1 then
  neovim_jupyter = neovim_python_dir .. "/jupyter"
end

vim.g.python3_host_prog = neovim_python

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.scrolloff = 8
opt.updatetime = 250
opt.splitright = true
opt.splitbelow = true
opt.foldenable = true
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldnestmax = 99
opt.foldminlines = 1
opt.foldcolumn = "1"
opt.completeopt = { "menu", "menuone", "noselect" }

local keymap = vim.keymap.set

local function preview_latex_pdf()
  require("latex_pdf_preview").open()
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = { flavour = "mocha" },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "bash",
        "css",
        "html",
        "javascript",
        "json",
        "latex",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "rust",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      },
      highlight = {
        enable = true,
        disable = { "latex" },
      },
      indent = { enable = true },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      keymap("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      keymap("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      keymap("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
      keymap("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
    end,
  },
  {
    "lervag/vimtex",
    lazy = false,
    keys = {
      { "<leader>lV", preview_latex_pdf, desc = "Preview PDF in Neovim" },
    },
    init = function()
      vim.g.vimtex_view_method = "general"
      vim.g.vimtex_view_automatic = 0
      vim.g.vimtex_view_general_viewer = "open"
      vim.g.vimtex_view_general_options = "-a Skim @pdf"
      vim.g.vimtex_compiler_method = "tectonic"
      vim.g.vimtex_quickfix_mode = 0
    end,
  },
  {
    "iurimateus/luasnip-latex-snippets.nvim",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "lervag/vimtex",
    },
    ft = { "tex", "plaintex" },
    config = function()
      require("luasnip-latex-snippets").setup({
        use_treesitter = true,
      })
      require("luasnip").config.setup({
        enable_autosnippets = true,
      })
    end,
  },
  {
    "jbyuki/nabla.nvim",
    ft = { "tex", "plaintex" },
    keys = {
      {
        "<leader>lp",
        function() require("nabla").popup() end,
        desc = "Preview LaTeX equation",
      },
    },
  },
  {
    "3rd/image.nvim",
    build = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      max_height_window_percentage = 50,
      tmux_show_only_in_active_window = true,
    },
  },
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    lazy = false,
    build = ":UpdateRemotePlugins",
    dependencies = { "3rd/image.nvim" },
    init = function()
      vim.g.molten_auto_open_output = false
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_text_output = true
      vim.g.molten_wrap_output = true
    end,
    keys = {
      { "<leader>ji", "<cmd>MoltenInit neovim<cr>", desc = "Initialize notebook kernel" },
      { "<leader>jo", "<cmd>noautocmd MoltenEnterOutput<cr>", desc = "Open notebook output" },
      { "<leader>jh", "<cmd>MoltenHideOutput<cr>", desc = "Hide notebook output" },
      { "<leader>jx", "<cmd>MoltenInterrupt<cr>", desc = "Interrupt notebook kernel" },
      { "<leader>jR", "<cmd>MoltenRestart<cr>", desc = "Restart notebook kernel" },
      { "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", desc = "Run notebook line" },
      { "<leader>jv", ":<C-u>MoltenEvaluateVisual<cr>gv", mode = "v", desc = "Run notebook selection" },
      {
        "<leader>je",
        function()
          local notebook = vim.api.nvim_buf_get_name(0)
          if notebook == "" or vim.fn.fnamemodify(notebook, ":e") ~= "ipynb" then
            vim.notify("HTML export is only available for .ipynb files", vim.log.levels.ERROR)
            return
          end

          vim.cmd.write()
          local html = vim.fn.fnamemodify(notebook, ":r") .. ".html"
          vim.notify("Executing notebook before HTML export...")
          vim.system({
            neovim_jupyter,
            "nbconvert",
            "--to",
            "notebook",
            "--execute",
            "--inplace",
            "--ExecutePreprocessor.kernel_name=neovim",
            "--ExecutePreprocessor.timeout=600",
            notebook,
          }, { text = true }, function(execute_result)
            vim.schedule(function()
              if execute_result.code ~= 0 then
                local message = vim.trim(execute_result.stderr or execute_result.stdout or "Unknown execution error")
                vim.notify("Notebook execution failed: " .. message, vim.log.levels.ERROR)
                return
              end

              vim.notify("Rendering " .. vim.fn.fnamemodify(html, ":t") .. "...")
              vim.system({
                neovim_python_dir .. "/jupyter",
                "nbconvert",
                "--to",
                "html",
                notebook,
              }, { text = true }, function(render_result)
                vim.schedule(function()
                  if render_result.code == 0 then
                    vim.notify("Stored outputs and exported notebook to " .. html)
                  else
                    local message = vim.trim(render_result.stderr or render_result.stdout or "Unknown render error")
                    vim.notify("Notebook export failed: " .. message, vim.log.levels.ERROR)
                  end
                end)
              end)
            end)
          end)
        end,
        desc = "Export notebook to HTML",
      },
    },
  },
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      style = "hydrogen",
      output_extension = "py",
      force_ft = "python",
    },
  },
  {
    "GCBallesteros/NotebookNavigator.nvim",
    dependencies = { "benlubas/molten-nvim" },
    event = "VeryLazy",
    opts = {
      repl_provider = "molten",
      syntax_highlight = true,
    },
    keys = {
      {
        "]j",
        function() require("notebook-navigator").move_cell("d") end,
        desc = "Next notebook cell",
      },
      {
        "[j",
        function() require("notebook-navigator").move_cell("u") end,
        desc = "Previous notebook cell",
      },
      {
        "<leader>jr",
        function() require("notebook-navigator").run_cell() end,
        desc = "Run notebook cell",
      },
      {
        "<leader>jn",
        function() require("notebook-navigator").run_and_move() end,
        desc = "Run notebook cell and advance",
      },
      {
        "<leader>ja",
        function()
          local navigator = require("notebook-navigator")
          local window = vim.api.nvim_get_current_win()
          local original_cursor = vim.api.nvim_win_get_cursor(window)
          local executed = 0

          local ok, err = pcall(function()
            vim.api.nvim_win_set_cursor(window, { 1, 0 })
            local marker = require("notebook-navigator.utils").get_cell_marker(
              0,
              navigator.config.cell_markers
            )
            local first_cell = vim.fn.search("^" .. marker, "W")
            if first_cell == 0 then
              error("No notebook cell markers found")
            end

            while true do
              local marker_line = vim.api.nvim_get_current_line()
              local is_markdown = marker_line:match("^%s*# %%%% %[%s*markdown%s*%]") ~= nil
              local cell = navigator.miniai_spec("i")
              local lines = vim.api.nvim_buf_get_lines(0, cell.from.line - 1, cell.to.line, false)
              local has_content = false

              for _, line in ipairs(lines) do
                if vim.trim(line) ~= "" then
                  has_content = true
                  break
                end
              end

              if has_content and not is_markdown then
                navigator.run_cell()
                executed = executed + 1
              end

              if navigator.move_cell("d") == "last" then
                break
              end
            end
          end)

          if vim.api.nvim_win_is_valid(window) then
            vim.api.nvim_win_set_cursor(window, original_cursor)
          end

          if not ok then
            error(err)
          end

          vim.notify(("Queued %d notebook cell(s)"):format(executed))
        end,
        desc = "Run all notebook cells",
      },
    },
  },
  {
    "stevearc/oil.nvim",
    opts = { view_options = { show_hidden = true } },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      attach_to_untracked = true,
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
        untracked = { text = "┆" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local function map(lhs, rhs, desc)
          keymap("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map("]h", function() gs.nav_hunk("next") end, "Next git hunk")
        map("[h", function() gs.nav_hunk("prev") end, "Previous git hunk")
        map("<leader>gb", gs.blame_line, "Git blame line")
        map("<leader>gp", gs.preview_hunk, "Preview git hunk")
      end,
    },
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = { theme = "catppuccin-mocha" },
      sections = {
        lualine_c = {
          {
            "filename",
            path = 1,
            shorting_target = 40,
          },
        },
      },
    },
  },
  {
    "echasnovski/mini.surround",
    version = false,
    opts = {
      mappings = {
        add = "sa",
        delete = "sd",
        replace = "sr",
        find = "sf",
        find_left = "sF",
        highlight = "sh",
        update_n_lines = "sn",
      },
    },
  },
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Stop session tracking" },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "basedpyright",
        "ruff",
        "rust-analyzer",
        "texlab",
        "typescript-language-server",
        "prettier",
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "basedpyright", "ruff", "rust_analyzer", "texlab", "ts_ls" },
      automatic_installation = true,
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "prettier",
        "rust-analyzer",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local servers = {
        basedpyright = {},
        ruff = {},
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
              },
              check = {
                command = "clippy",
              },
            },
          },
        },
        sourcekit = {
          cmd = { "xcrun", "sourcekit-lsp" },
        },
        texlab = {
          settings = {
            texlab = {
              build = {
                executable = "tectonic",
                args = {
                  "-X",
                  "compile",
                  "-Z",
                  "shell-escape",
                  "%f",
                  "--synctex",
                  "--keep-logs",
                  "--keep-intermediates",
                },
                onSave = true,
                forwardSearchAfter = false,
              },
              forwardSearch = {
                executable = "/Applications/Skim.app/Contents/SharedSupport/displayline",
                args = { "%l", "%p", "%f" },
              },
            },
          },
        },
        ts_ls = {},
      }

      for server, config in pairs(servers) do
        config.capabilities = capabilities
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end

      keymap("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      keymap("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
      keymap("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
      keymap({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_fallback = true,
      },
    },
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            runner = "pytest",
          }),
        },
      })
    end,
  },
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.ipynb",
  callback = function(event)
    if vim.b[event.buf].molten_auto_initialized then
      return
    end

    vim.b[event.buf].molten_auto_initialized = true
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return
      end

      vim.api.nvim_buf_call(event.buf, function()
        if require("molten.status").initialized() ~= "Molten" then
          vim.cmd("MoltenInit neovim")
        end
      end)
    end)
  end,
  desc = "Automatically start the Neovim Jupyter kernel for notebooks",
})
