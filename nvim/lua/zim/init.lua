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

-- case-insensitive search (smartcase: becomes case-sensitive if uppercase is used).
vim.opt.ignorecase = true
vim.opt.smartcase = true
-- highlight search.
vim.opt.hlsearch = true
-- incremental search.
vim.opt.incsearch = true
-- Preview substitutions.
vim.opt.inccommand = 'split'

-- persistent undo across sessions.
vim.opt.undofile = true

-- faster CursorHold events (snappier diagnostics/git signs).
vim.opt.updatetime = 250

-- always have at least 8 lines above or below the cursor.
vim.opt.scrolloff = 8

-- marker at 80 chars.
vim.opt.colorcolumn = "80"

-- Show trailing whitespaces.
vim.opt.listchars = "trail:-"
vim.opt.list = true

-- Highlight trailing whitespace with a red background. matchadd is per-window,
-- so re-apply on each new window; re-apply the hl on ColorScheme since plugin
-- colorschemes load after this file and would otherwise wipe it.
local trailing = vim.api.nvim_create_augroup("TrailingWhitespace", { clear = true })

local function set_trailing_hl()
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "#ff5555" })
end
set_trailing_hl()

vim.api.nvim_create_autocmd("ColorScheme", {
    group = trailing,
    callback = set_trailing_hl,
})

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = trailing,
    callback = function()
        if vim.api.nvim_win_get_config(0).relative ~= "" then return end
        if vim.bo.buftype ~= "" then return end
        for _, m in ipairs(vim.fn.getmatches()) do
            if m.group == "ExtraWhitespace" then return end
        end
        vim.fn.matchadd("ExtraWhitespace", [[\s\+$]])
    end,
})

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
