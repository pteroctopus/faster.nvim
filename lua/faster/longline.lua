local utils = require('faster.utils')

-- Returns (size_mib_rounded_to_one_decimal, raw_size_bytes) or nil.
local function get_buf_size(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, stats = pcall(function()
    return vim.uv.fs_stat(vim.api.nvim_buf_get_name(bufnr))
  end)
  if not (ok and stats) then
    return
  end
  local size_mib = math.floor(0.5 + (stats.size / (1024 * 1024)) * 10) / 10
  return size_mib, stats.size
end

-- Returns true when the buffer matches the long-line criteria, false otherwise.
local function is_longline(bufnr, min_filesize, avg_threshold)
  local size_mib, size_bytes = get_buf_size(bufnr)
  if not size_bytes then return false, 0, 0 end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count == 0 then return false, size_mib or 0, 0 end
  local avg = size_bytes / line_count
  return (size_mib >= min_filesize) and (avg > avg_threshold), size_mib, avg
end

local function emit_notify(bufnr, size_mib, avg)
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  local msg = string.format(
    "faster.nvim active for %s (%d bytes/line, %s MiB)",
    fname, math.floor(avg), size_mib
  )
  local function emit()
    vim.notify(msg, vim.log.levels.INFO, { title = "faster.nvim" })
  end
  if vim.v.vim_did_enter == 1 then
    emit()
  else
    -- During startup our notify can race plugins that replace vim.notify
    -- (nvim-notify, noice, snacks) since they typically load on User VeryLazy
    -- (lazy.nvim) or similar. Chain on User VeryLazy first — by the time it
    -- fires, those plugins have run their config. Fall back to UIEnter+timer
    -- in case the plugin manager doesn't fire VeryLazy.
    local fired = false
    local function fire()
      if fired then return end
      fired = true
      emit()
    end
    pcall(vim.api.nvim_create_autocmd, "User", {
      pattern = "VeryLazy",
      once = true,
      callback = fire,
    })
    vim.api.nvim_create_autocmd("UIEnter", {
      once = true,
      callback = function() vim.defer_fn(fire, 500) end,
    })
  end
end

-- Run disable for features at one defer level inside the bufnr's context.
local function run_disable_pass(bufnr, defer)
  vim.api.nvim_buf_call(bufnr, function()
    utils.run_on_features(
      FasterConfig.behaviours.longline.features_disabled,
      function(f) f.disable() end,
      function(f) return f.defer == defer end
    )
  end)
end

local function enable_features(defer)
  utils.run_on_features(
    FasterConfig.behaviours.longline.features_disabled,
    function(f) f.enable() end,
    function(f) return f.defer == defer end
  )
end

-- The full disable sequence for one buffer. Three passes:
--   1. defer=false (treesitter, lsp, illuminate, ...)
--   2. defer=true  (syntax='off', filetype='', vimopts) — note that setting
--      filetype synchronously fires FileType autocmds, which user code may
--      use to re-enable defer=false features (e.g. vim.treesitter.start).
--   3. defer=false again, deferred to the next tick — overrides any re-enable
--      caused by pass 2's FileType chain.
local function disable_for_buffer(bufnr, fs, avg)
  -- Mark per-buffer so :Faster status can report "longline triggered for this buffer".
  pcall(vim.api.nvim_buf_set_var, bufnr, 'faster_longline_triggered', true)
  run_disable_pass(bufnr, false)
  run_disable_pass(bufnr, true)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      run_disable_pass(bufnr, false)
    end
  end)
end

local M = {}

local function process_buffer(bufnr, fs, avg_threshold)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local match, size_mib, avg = is_longline(bufnr, fs, avg_threshold)
    if not match then return end
    local cfg = FasterConfig.behaviours.longline
    if cfg.notify then emit_notify(bufnr, size_mib, avg) end
    disable_for_buffer(bufnr, fs, avg_threshold)
  end)
end

function M.init(opts)
  opts = opts or {}
  local augroup = vim.api.nvim_create_augroup('faster_longline', {})

  local cfg = FasterConfig.behaviours.longline

  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = cfg.pattern,
    group = augroup,
    callback = function(args)
      process_buffer(args.buf, cfg.filesize, cfg.avg_bytes_per_line)
    end,
    desc = string.format(
      "[faster.nvim] long-line rule: avg bytes/line > %d, size >= %s MiB",
      cfg.avg_bytes_per_line, cfg.filesize
    ),
  })

  for _, override in ipairs(cfg.extra_patterns or {}) do
    if override.pattern ~= nil then
      local fs  = override.filesize           or cfg.filesize
      local avg = override.avg_bytes_per_line or cfg.avg_bytes_per_line
      vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = override.pattern,
        group = augroup,
        callback = function(args)
          process_buffer(args.buf, fs, avg)
        end,
        desc = string.format(
          "[faster.nvim] long-line rule for `%s`: avg bytes/line > %d, size >= %s MiB",
          override.pattern, avg, fs
        ),
      })
    end
  end

  -- Process the currently open buffer too (e.g. when init() is called via
  -- :Faster enable longline on an already-open long-line file). Skip when
  -- called from a group enable so we don't undo the just-enabled features.
  if not opts.skip_current then
    local cur = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(cur) ~= "" then
      process_buffer(cur, cfg.filesize, cfg.avg_bytes_per_line)
    end
  end
end

function M.stop()
  -- pcall to keep stop() idempotent: nvim_del_augroup_by_name errors if the
  -- group doesn't exist (behaviour never armed or already stopped).
  pcall(vim.api.nvim_del_augroup_by_name, 'faster_longline')
  -- Restore defer=true features (filetype, syntax, vimopts) BEFORE defer=false
  -- ones: lsp.enable() bails with a warning when &filetype is still empty, so
  -- filetype must be back first. Matches bigfile.stop() and the group-enable
  -- order in commands.lua.
  enable_features(true)
  enable_features(false)
  -- Clear stale per-buffer "triggered" markers.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_del_var, bufnr, 'faster_longline_triggered')
  end
end

return M
