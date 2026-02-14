-- LSP configuration using native Neovim 0.11+ APIs.

local capabilities = require('blink.cmp').get_lsp_capabilities()

-- Global config: apply blink.cmp capabilities to all servers.
vim.lsp.config('*', {
    capabilities = capabilities,
})

-- rust-analyzer: conditional rustc sysroot config.
local rust_config = {}
local rustc_sysroot = io.popen('rustc --print sysroot'):read()
if rustc_sysroot ~= nil then
    rust_config.settings = {
        ["rust-analyzer.settings.source"] =
            rustc_sysroot .. 'lib/rustlib/rustc-src/rust/compiler/rustc/Cargo.toml'
    }
end
vim.lsp.config('rust_analyzer', rust_config)

vim.lsp.config('ocamllsp', {})

vim.lsp.config('lua_ls', {
    on_init = function(client)
        if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if path ~= vim.fn.stdpath('config') and (vim.loop.fs_stat(path .. '/.luarc.json') or vim.loop.fs_stat(path .. '/.luarc.jsonc')) then
                return
            end
        end

        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            runtime = {
                version = 'LuaJIT'
            },
            workspace = {
                checkThirdParty = false,
                library = {
                    vim.env.VIMRUNTIME
                }
            }
        })
    end,
    settings = {
        Lua = {}
    }
})

vim.lsp.config('clangd', {})

vim.lsp.config('bashls', {})

-- Enable all configured servers.
vim.lsp.enable({ 'rust_analyzer', 'ocamllsp', 'lua_ls', 'clangd', 'bashls' })

-- Format on save using LSP capabilities.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lsp", { clear = true }),
    callback = function(args)
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = args.buf,
            callback = function()
                vim.lsp.buf.format { async = false, id = args.data.client_id }
            end,
        })

        -- LSP keymaps
        local opts = { buffer = args.buf }
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', 'go', vim.lsp.buf.type_definition, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, opts)
        vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<F3>', function() vim.lsp.buf.format({ async = true }) end, opts)
        vim.keymap.set('n', '<F4>', vim.lsp.buf.code_action, opts)
    end
})
