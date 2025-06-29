return {
    -- lspconfig: base configuration for LSPs
    "neovim/nvim-lspconfig",

    -- start the lsp when reading or creating a file.
    event = { "BufReadPre", "BufNewFile" },

    dependencies = {
        'saghen/blink.cmp',
    },

    opts = {
        autoformat = true,
    },

    config = function()
        local lspconfig = require('lspconfig')

        -- Blink capabilities, to put in each setup to activate it.
        local capabilities = require('blink.cmp').get_lsp_capabilities()

        local rustc_sysroot = io.popen('rustc --print sysroot'):read()
        if rustc_sysroot ~= nil then
            lspconfig.rust_analyzer.setup {
                settings = {
                    ["rust-analyzer.settings.source"] =
                        rustc_sysroot .. 'lib/rustlib/rustc-src/rust/compiler/rustc/Cargo.toml'
                },
                capabilities = capabilities,
            }
        end

        lspconfig.ocamllsp.setup {
            capabilities = capabilities
        }

        lspconfig.lua_ls.setup {
            capabilities = capabilities,
            -- This configuration was stolen from
            -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls
            -- to work for vim configuration.
            on_init = function(client)
                if client.workspace_folders then
                    local path = client.workspace_folders[1].name
                    if path ~= vim.fn.stdpath('config') and (vim.loop.fs_stat(path .. '/.luarc.json') or vim.loop.fs_stat(path .. '/.luarc.jsonc')) then
                        return
                    end
                end

                client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
                    runtime = {
                        -- Tell the language server which version of Lua you're using
                        -- (most likely LuaJIT in the case of Neovim)
                        version = 'LuaJIT'
                    },
                    -- Make the server aware of Neovim runtime files
                    workspace = {
                        checkThirdParty = false,
                        library = {
                            vim.env.VIMRUNTIME
                            -- Depending on the usage, you might want to add additional paths here.
                            -- "${3rd}/luv/library"
                            -- "${3rd}/busted/library",
                        }
                        -- or pull in all of 'runtimepath'. NOTE: this is a lot slower and will cause issues when working on your own configuration (see https://github.com/neovim/nvim-lspconfig/issues/3189)
                        -- library = vim.api.nvim_get_runtime_file("", true)
                    }
                })
            end,
            settings = {
                Lua = {}
            }
        }

        lspconfig.clangd.setup {
            capabilities = capabilities,
        }

        lspconfig.bashls.setup {
            capabilities = capabilities,
        }

        lspconfig.harper_ls.setup {
            cmd = { '/home/stephane/perso/oss/harper/target/debug/harper-ls', '--stdio' },
            -- TODO: make a PR, remove once merged.
            filetypes = { 'c', 'cpp', 'ocaml', 'ocaml_interface', 'rust', 'gitcommit' },
        }

        -- Format on save using LSP capabilities.
        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("lsp", { clear = true }),
            callback = function(args)
                -- TODO: check if the client supports formatting.
                vim.api.nvim_create_autocmd("BufWritePre", {
                    buffer = args.buf,
                    callback = function()
                        vim.lsp.buf.format { async = false, id = args.data.client_id }
                    end,
                })
            end
        })
    end,

    keys = {
        { 'K',    '<cmd>lua vim.lsp.buf.hover()<cr>' },
        { 'gd',   '<cmd>lua vim.lsp.buf.definition()<cr>' },
        { 'gD',   '<cmd>lua vim.lsp.buf.declaration()<cr>' },
        { 'gi',   '<cmd>lua vim.lsp.buf.implementation()<cr>' },
        { 'go',   '<cmd>lua vim.lsp.buf.type_definition()<cr>' },
        { 'gr',   '<cmd>lua vim.lsp.buf.references()<cr>' },
        { 'gs',   '<cmd>lua vim.lsp.buf.signature_help()<cr>' },
        { '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>' },
        { '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>' },
        { '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>' },
    },
}
