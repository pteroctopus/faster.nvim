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
  -- Show a one-shot vim.notify when bigfile mode activates for a buffer.
  notify = true,
  init = require('faster.bigfile').init,
  stop = require('faster.bigfile').stop,
  -- Active = bigfile criteria matched for this buffer (features were disabled).
  -- The disable_features path sets vim.b[bufnr].faster_bigfile_triggered.
  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, 'faster_bigfile_triggered')
    return ok and val == true
  end,
}

-- Triggers on files that aren't large in total bytes but have very long lines
-- (minified JS, JSON, log files). avg = filesize / line_count is a cheap
-- heuristic: it requires only fs_stat + nvim_buf_line_count, no buffer scan.
M.longline = {
  on = true,
  features_disabled = {
    'illuminate', 'matchparen', 'lsp',
    'treesitter', 'indent_blankline',
    'vimopts', 'syntax', 'filetype',
  },
  -- File must be at least this size (MiB) to be considered. Default 10 KiB
  -- skips tiny files even if their line count is artificially low.
  filesize = 0.01,
  -- Trigger when filesize_bytes / line_count > avg_bytes_per_line.
  avg_bytes_per_line = 250,
  pattern = "*",
  extra_patterns = {},
  notify = true,
  init = require('faster.longline').init,
  stop = require('faster.longline').stop,
  -- Active = longline criteria matched for this buffer (features were disabled).
  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, 'faster_longline_triggered')
    return ok and val == true
  end,
}

M.fastmacro = {
  on = true,
  features_disabled = { "lualine", "mini_clue"},
  init = require('faster.macro').init,
  stop = require('faster.macro').stop,
  -- Active = the @ keymap is bound to our wrapper. init() sets it, stop() unsets.
  is_active = function()
    local m = vim.fn.maparg("@", "n", false, true)
    return type(m) == "table" and (m.callback ~= nil or m.rhs ~= nil and m.rhs ~= "")
  end,
}

return M
