-- longline: disable features for files that aren't large in total bytes but
-- have very long lines (minified JS/JSON/CSS, log files). The heuristic is
-- avg = filesize / line_count > avg_bytes_per_line, gated by a minimum size —
-- cheap (fs_stat + nvim_buf_line_count, no buffer scan). All the machinery
-- lives in faster.size_behaviour; this file is just the spec.
local size_behaviour = require('faster.size_behaviour')

local spec = {
  name = 'longline',
  augroup = 'faster_longline',
  triggered_var = 'faster_longline_triggered',

  params_from_cfg = function(cfg)
    return { filesize = cfg.filesize, avg = cfg.avg_bytes_per_line }
  end,
  params_from_override = function(cfg, override)
    return {
      filesize = override.filesize or cfg.filesize,
      avg = override.avg_bytes_per_line or cfg.avg_bytes_per_line,
    }
  end,

  evaluate = function(params, size_mib, size_bytes, bufnr)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count == 0 then return false end
    local avg = size_bytes / line_count
    if not (size_mib >= params.filesize and avg > params.avg) then return false end
    local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    return true, string.format(
      "faster.nvim active for %s (%d bytes/line, %s MiB)",
      fname, math.floor(avg), size_mib
    )
  end,

  desc = function(params, pattern)
    if pattern then
      return string.format(
        "[faster.nvim] long-line rule for `%s`: avg bytes/line > %d, size >= %s MiB",
        pattern, params.avg, params.filesize
      )
    end
    return string.format(
      "[faster.nvim] long-line rule: avg bytes/line > %d, size >= %s MiB",
      params.avg, params.filesize
    )
  end,
}

local M = {}

function M.init(opts) size_behaviour.init(spec, opts) end
function M.stop() size_behaviour.stop(spec) end

return M
