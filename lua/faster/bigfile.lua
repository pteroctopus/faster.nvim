local utils = require('faster.utils')

local function get_buf_size(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, stats = pcall(function()
    return vim.loop.fs_stat(vim.api.nvim_buf_get_name(bufnr))
  end)
  if not (ok and stats) then
    return
  end
  return math.floor(0.5 + (stats.size / (1024 * 1024)) * 10) / 10
end

local function emit_notify(bufnr, filesize)
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  local msg = string.format("faster.nvim active for %s (%s MiB)", fname, filesize)
  local function emit()
    vim.notify(msg, vim.log.levels.INFO, { title = "faster.nvim" })
  end
  if vim.v.vim_did_enter == 1 then
    emit()
  else
    -- Race-defensive: prefer User VeryLazy (lazy.nvim fires it after VeryLazy
    -- plugins like nvim-notify replace vim.notify), fall back to UIEnter+timer.
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
      FasterConfig.behaviours.bigfile.features_disabled,
      function(f) f.disable() end,
      function(f) return f.defer == defer end
    )
  end)
end

local function enable_features(defer)
  utils.run_on_features(
    FasterConfig.behaviours.bigfile.features_disabled,
    function(f) f.enable() end,
    function(f) return f.defer == defer end
  )
end

-- Three-pass disable for one buffer. defer=true side-effects (setting
-- filetype="") synchronously fire FileType autocmds; user code on FileType
-- (e.g. vim.treesitter.start) can re-enable defer=false features. We re-run
-- defer=false on the next tick to override that.
local function disable_for_buffer(bufnr)
  pcall(vim.api.nvim_buf_set_var, bufnr, 'faster_bigfile_triggered', true)
  run_disable_pass(bufnr, false)
  run_disable_pass(bufnr, true)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      run_disable_pass(bufnr, false)
    end
  end)
end

local M = {}

local function on_buffer(bufnr, for_size)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local filesize = get_buf_size(bufnr) or 0
    if filesize < for_size then return end
    if FasterConfig.behaviours.bigfile.notify then
      emit_notify(bufnr, filesize)
    end
    disable_for_buffer(bufnr)
  end)
end

-- Find the threshold that applies to a given buffer (default + extra_patterns).
local function threshold_for_buffer(bufnr)
  local cfg = FasterConfig.behaviours.bigfile
  local fname = vim.api.nvim_buf_get_name(bufnr)
  for _, override in ipairs(cfg.extra_patterns or {}) do
    if override.pattern and vim.fn.match(fname, vim.fn.glob2regpat(override.pattern)) >= 0 then
      return override.filesize or cfg.filesize
    end
  end
  return cfg.filesize
end

function M.init(opts)
  opts = opts or {}
  local augroup = vim.api.nvim_create_augroup('faster_bigfile', {})
  local cfg = FasterConfig.behaviours.bigfile

  -- BufReadPost: buffer is fully loaded; defer with vim.schedule so we run
  -- AFTER the BufReadPost -> FileType chain. Otherwise user FileType autocmds
  -- (e.g. vim.treesitter.start) re-enable features after our disable.
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = cfg.pattern,
    group = augroup,
    callback = function(args)
      on_buffer(args.buf, cfg.filesize)
    end,
    desc = string.format(
      "[faster.nvim] Performance rule for handling files over %sMiB",
      cfg.filesize
    ),
  })

  for _, override in ipairs(cfg.extra_patterns or {}) do
    if override.pattern ~= nil then
      local fs = override.filesize or cfg.filesize
      vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = override.pattern,
        group = augroup,
        callback = function(args)
          on_buffer(args.buf, fs)
        end,
        desc = string.format(
          "[faster.nvim] Performance rule for handling `%s` files over %sMiB",
          override.pattern, fs
        ),
      })
    end
  end

  -- Process the currently open buffer too: useful when init() is called via
  -- :Faster enable bigfile while sitting on an already-open big file. Skip
  -- when init() is part of a group enable (:Faster enable all|behaviours) —
  -- the user explicitly asked for everything to be on, so don't re-disable.
  if not opts.skip_current then
    local cur = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(cur) ~= "" then
      on_buffer(cur, threshold_for_buffer(cur))
    end
  end
end

function M.stop()
  -- pcall: stop() may be called when the augroup doesn't exist (behaviour was
  -- never armed, or already stopped). nvim_del_augroup_by_name errors on a
  -- missing group, so guard to keep stop() idempotent.
  pcall(vim.api.nvim_del_augroup_by_name, 'faster_bigfile')
  enable_features(true)
  enable_features(false)
  -- Clear stale per-buffer "triggered" markers so :Faster status reports
  -- runtime state honestly. Using nvim_list_bufs covers any buffer we may
  -- have flagged earlier; pcall guards against unloaded buffers.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_del_var, bufnr, 'faster_bigfile_triggered')
  end
end

return M
