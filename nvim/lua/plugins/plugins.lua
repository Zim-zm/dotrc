return {
    -- Fuzzy finder.
    {
        "ibhagwan/fzf-lua",
        -- optional for icon support
        dependencies = { "nvim-tree/nvim-web-devicons" },
        -- or if using mini.icons/mini.nvim
        -- dependencies = { "echasnovski/mini.icons" },
        opts = {},
        lazy = false,
        keys = {
            { '<leader>fx', function() require('fzf-lua').files() end },
            { '<C-p>',      function() require('fzf-lua').git_files() end },
            { '<leader>b',  function() require('fzf-lua').buffers() end },
            { '<leader>fg', function() require('fzf-lua').live_grep() end, desc = "Live grep" },
        }
    },

    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        -- Install jsregexp (optional!).
        build = "make install_jsregexp",
        keys = {
            { '<C-l>', function() require("luasnip").expand() end, mode = "i" },
            { '<C-j>', function() require("luasnip").jump(-1) end, mode = { "i", "s" } },
            { '<C-k>', function() require("luasnip").jump(1) end,  mode = { "i", "s" } },
            {
                '<C-u>',
                function()
                    local ls = require("luasnip");
                    if ls.choice_active() then
                        ls.change_choice(1)
                    end
                end,
                mode = { "i", "s" },
            },
        },
    },

    {
        'saghen/blink.cmp',
        dependencies = {
            'L3MON4D3/LuaSnip',
            version = 'v2.*',
            'rafamadriz/friendly-snippets'
        },

        version = '*',
        opts = {
            keymap = { preset = 'default' },
            snippets = { preset = 'luasnip' },
            completion = {
                list = { selection = { preselect = true, auto_insert = false } },
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
            },
            signature = { enabled = true },
        },
        opts_extend = { "sources.default" }
    },

    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {},
        config = function()
            vim.cmd('colorscheme tokyonight-night')
        end
    },

    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            local configs = require("nvim-treesitter.configs")

            configs.setup({
                ensure_installed = {
                    "bash",
                    "c",
                    "cpp",
                    "html",
                    "lua",
                    "rust",
                    "vim",
                    "vimdoc",
                },
                sync_install = false,
                highlight = { enable = true },
                indent = { enable = true },
            })
        end

    },

    {
        -- Small game to learn vim motions.
        "ThePrimeagen/vim-be-good"
    },

    -- Harpoon : set buffers as favorites and quickly navigate around them.
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {
            menu = {
                width = vim.api.nvim_win_get_width(0) - 4,
            },
            settings = {
                save_on_toggle = true,
            },
        },
        keys =
        {
            {
                "<leader>H",
                function()
                    require("harpoon"):list():add()
                end,
                desc = "Harpoon File",
            },
            {
                "<leader>h",
                function()
                    local harpoon = require("harpoon")
                    harpoon.ui:toggle_quick_menu(harpoon:list())
                end,
                desc = "Harpoon Quick Menu",
            },

            {
                "<leader>&",
                function()
                    require("harpoon"):list():select(1)
                end,
                desc = "Harpoon to File 1",
            },
            {
                "<leader>é",
                function()
                    require("harpoon"):list():select(2)
                end,
                desc = "Harpoon to File 2",
            },
            {
                "<leader>\"",
                function()
                    require("harpoon"):list():select(3)
                end,
                desc = "Harpoon to File 3",
            },
            {
                "<leader>'",
                function()
                    require("harpoon"):list():select(4)
                end,
                desc = "Harpoon to File 4",
            },
        }
    },
    {
        "folke/trouble.nvim",
        opts = {},
        cmd = "Trouble",
        keys = {
            {
                "<leader>xX",
                "<cmd>Trouble diagnostics toggle<cr>",
                desc = "Diagnostics (Trouble)",
            },
            {
                "<leader>xx",
                "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
                desc = "Buffer Diagnostics (Trouble)",
            },
            {
                "<leader>cs",
                "<cmd>Trouble symbols toggle focus=false<cr>",
                desc = "Symbols (Trouble)",
            },
            {
                "<leader>cl",
                "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
                desc = "LSP Definitions / references / ... (Trouble)",
            },
            {
                "<leader>xL",
                "<cmd>Trouble loclist toggle<cr>",
                desc = "Location List (Trouble)",
            },
            {
                "<leader>xQ",
                "<cmd>Trouble qflist toggle<cr>",
                desc = "Quickfix List (Trouble)",
            },
        },
    }
}
