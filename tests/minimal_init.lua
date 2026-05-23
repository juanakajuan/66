local root = vim.fn.getcwd()
local plenary_path = vim.env.PLENARY_PATH or (root .. "/deps/plenary.nvim")

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(plenary_path)

vim.cmd("runtime plugin/plenary.vim")
