-- my stuff before loading any package.
require("zim")

-- Package manager. lazy seems to be the community consensus for now.
require("config.lazy")

-- LSP configuration (native vim.lsp.config, requires blink.cmp from lazy).
require("zim.lsp")

-- local opamshare = io.popen('opam var share'):read()
-- if opamshare  then
--     vim.opt.runtimepath:append(opamshare .. "/merlin/vim")
-- end
