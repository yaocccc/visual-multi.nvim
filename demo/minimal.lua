local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.cmdheight = 0
vim.opt.signcolumn = "no"
vim.opt.fillchars = { eob = " " }

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.cmd("normal! gg0")
  end,
})
