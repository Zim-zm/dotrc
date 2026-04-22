require("zim.keymap")

-- fat cursor in insert mode.
vim.opt.guicursor = ""

-- line numbers.
vim.opt.nu = true
-- relative line numbers.
vim.opt.rnu = true
-- always display the sign column (column with marker for the LSP for example).
-- Keeps the column size more stable.
vim.opt.signcolumn = 'yes'

-- sane tabs.
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- no line wrap.
vim.opt.wrap = false

-- highlight search.
vim.opt.hlsearch = true
-- incremental search.
vim.opt.incsearch = true
-- Preview substitutions.
vim.opt.inccommand = 'split'

-- always have at least 8 lines above or below the cursor.
vim.opt.scrolloff = 8

-- marker at 80 chars.
vim.opt.colorcolumn = "80"

-- Show trailing whitespaces.
vim.opt.listchars = "trail:-"
vim.opt.list = true

-- leader keys, have to be set before loading plugins.
vim.g.mapleader = " "
vim.g.localleader = " "

vim.g.completeopt = { "menu", "menuone", "noselect", "preview", "popup" }

-- Highlight on yank, because I'm a bit stupid about what I'm doing.
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking text',
    callback = function()
        vim.highlight.on_yank()
    end
})

-- Diagnostics configuration.
vim.diagnostic.config(
    {
        underline = true,
        -- Do not put the diagnostics right to the text but in a virtual line
        -- below.
        virtual_text = true,
        -- virtual_lines = { current_line = true },
    }
)
