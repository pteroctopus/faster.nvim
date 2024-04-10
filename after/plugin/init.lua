if vim.g.loaded_faster_nvim == 1 then
  return
end
vim.g.loaded_faster_nvim = 1

require('faster').setup()
