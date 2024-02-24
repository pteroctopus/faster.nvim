local M = {}

M.bigfile = {
  on = true,
  features_disabled = {
    'illuminate', 'matchparen', 'lsp',
    'treesitter', 'indent_blankline',
    'vimopts', 'syntax', 'filetype',
  },
  filesize = 2,
  pattern = "*",
  init = require('faster.bigfile').init
}

M.fastmacro = {
  on = true,
  features_disabled = { "lualine", },
  init = require('faster.macro').init
}

return M
