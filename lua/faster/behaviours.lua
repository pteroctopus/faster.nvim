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
  extra_patterns = {},
  init = require('faster.bigfile').init,
  stop = require('faster.bigfile').stop,
}

M.fastmacro = {
  on = true,
  features_disabled = { "lualine", },
  init = require('faster.macro').init,
  stop = require('faster.macro').stop,
}

return M
