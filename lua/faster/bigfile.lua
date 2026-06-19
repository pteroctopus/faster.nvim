-- bigfile: disable features for files over a size threshold (default 2 MiB).
-- All the machinery lives in faster.size_behaviour; this file is just the spec.
local size_behaviour = require('faster.size_behaviour')

local spec = {
  name = 'bigfile',
  augroup = 'faster_bigfile',
  triggered_var = 'faster_bigfile_triggered',

  params_from_cfg = function(cfg)
    return { filesize = cfg.filesize }
  end,
  params_from_override = function(cfg, override)
    return { filesize = override.filesize or cfg.filesize }
  end,

  evaluate = function(params, size_mib, _size_bytes, bufnr)
    if size_mib < params.filesize then return false end
    local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    return true, string.format("faster.nvim active for %s (%s MiB)", fname, size_mib)
  end,

  desc = function(params, pattern)
    if pattern then
      return string.format(
        "[faster.nvim] Performance rule for handling `%s` files over %sMiB",
        pattern, params.filesize
      )
    end
    return string.format(
      "[faster.nvim] Performance rule for handling files over %sMiB",
      params.filesize
    )
  end,
}

local M = {}

function M.init(opts) size_behaviour.init(spec, opts) end
function M.stop() size_behaviour.stop(spec) end

return M
