vim.g.mapleader = " "
vim.g.localleader = " "

-- Go back to the file explorer.
vim.keymap.set("n", "<leader>ex", vim.cmd.Ex)

-- Use jk to get back to normal mode, in order to avoid moving fingers.
-- Thanks Dorian for the tip.
vim.keymap.set({ 'i' }, 'jk', '<Esc>', { noremap = true })

-- Copy into system clipboards.
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set({ "n", "v" }, "<leader>Y", [["*y]])

-- Paste from system clipboards.
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]])
vim.keymap.set({ "n", "v" }, "<leader>P", [["*p]])

-- Remove highlight when using ESC.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Less confusing page up and page down.
vim.keymap.set({ "n", "v", "i" }, "<C-d>", '<C-d>zz')
vim.keymap.set({ "n", "v", "i" }, "<C-u>", '<C-u>zz')
