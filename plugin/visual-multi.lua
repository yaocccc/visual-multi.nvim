if vim.g.loaded_visual_multi then
  return
end

if vim.version.lt(vim.version(), { 0, 12, 0 }) then
  vim.notify("visual-multi.nvim requires Neovim 0.12+", vim.log.levels.ERROR)
  return
end

vim.g.loaded_visual_multi = 1
require("visual-multi").setup()
