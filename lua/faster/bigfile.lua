local utils = require('faster.utils')

local function get_buf_size(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, stats = pcall(function()
    return vim.loop.fs_stat(vim.api.nvim_buf_get_name(bufnr))
  end)
  if not (ok and stats) then
    return
  end
  return math.floor(0.5 + (stats.size / (1024 * 1024)))
end

local function disable_features(bufnr, defer)
  local filesize = get_buf_size(bufnr) or 0
  local bigfile_detected = filesize >= Config.behaviours.bigfile.filesize
  if bigfile_detected then
    utils.run_on_features(
      Config.behaviours.bigfile.features_disabled,
      function(f) f.disable() end,
      function(f) return f.defer == defer end
    )
  end
end

local M = {}

function M.init()
  local augroup = vim.api.nvim_create_augroup("faster_bigfile", {})

  vim.api.nvim_create_autocmd("BufReadPre", {
    pattern = Config.behaviours.bigfile.pattern,
    group = augroup,
    callback = function(args)
      disable_features(args.buf, false)
    end,
    desc = string.format(
      "[faster.nvim] Performance rule for handling files over %sMiB",
      Config.behaviours.bigfile.filesize
    ),
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = Config.behaviours.bigfile.pattern,
    group = augroup,
    callback = function(args)
      disable_features(args.buf, true)
    end,
    desc = string.format(
      "[faster.nvim] Performance rule for handling files over %sMiB",
      Config.behaviours.bigfile.filesize
    ),
  })
end

return M
