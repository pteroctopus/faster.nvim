-- Shared implementation for the size-based behaviours (bigfile, longline).
--
-- Both behaviours have the same shape: a BufReadPost autocmd (plus one per
-- extra_pattern) that, when the buffer matches a size/shape criterion,
-- disables a set of features for that buffer using the three-pass dance, and
-- a stop() that tears the autocmds down and restores the features.
--
-- The only per-behaviour differences are captured in a `spec` table:
--   name           : behaviour key in FasterConfig.behaviours
--   augroup        : augroup name
--   triggered_var  : buffer var set when the behaviour fires for a buffer
--   params_from_cfg(cfg)            -> params  (thresholds from the base config)
--   params_from_override(cfg, ovr)  -> params  (thresholds for an extra_pattern)
--   evaluate(params, size_mib, size_bytes, bufnr) -> matched, notify_message
--   desc(params, pattern_or_nil)    -> autocmd description string
local utils = require('faster.utils')

local M = {}

-- Rounded size in MiB (one decimal) and the raw byte count, or nil on stat
-- failure / no file.
local function get_buf_size(bufnr)
  local ok, stats = pcall(function()
    return vim.uv.fs_stat(vim.api.nvim_buf_get_name(bufnr))
  end)
  if not (ok and stats) then
    return
  end
  local size_mib = math.floor(0.5 + (stats.size / (1024 * 1024)) * 10) / 10
  return size_mib, stats.size
end

-- Race-defensive notify: plugins that replace vim.notify (nvim-notify, noice,
-- snacks) typically load on User VeryLazy, so before vim_did_enter we chain on
-- that first and fall back to UIEnter + timer if the plugin manager never fires
-- VeryLazy.
local function emit_notify(msg)
  local function emit()
    vim.notify(msg, vim.log.levels.INFO, { title = "faster.nvim" })
  end
  if vim.v.vim_did_enter == 1 then
    emit()
  else
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
local function run_disable_pass(name, bufnr, defer)
  vim.api.nvim_buf_call(bufnr, function()
    utils.run_on_features(
      FasterConfig.behaviours[name].features_disabled,
      function(f) f.disable() end,
      function(f) return f.defer == defer end
    )
  end)
end

-- Run enable for features at one defer level inside the bufnr's context, so
-- buffer-scoped features (treesitter, lsp, vimopts/syntax/filetype, ...) target
-- the right buffer. Global toggles (matchparen, indent_blankline) re-enable
-- idempotently if this runs for several buffers.
local function enable_pass(name, bufnr, defer)
  vim.api.nvim_buf_call(bufnr, function()
    utils.run_on_features(
      FasterConfig.behaviours[name].features_disabled,
      function(f) f.enable() end,
      function(f) return f.defer == defer end
    )
  end)
end

-- Three-pass disable for one buffer. defer=true side-effects (setting
-- filetype="") synchronously fire FileType autocmds; user code on FileType
-- (e.g. vim.treesitter.start) can re-enable defer=false features. We re-run
-- defer=false on the next tick to override that.
local function disable_for_buffer(spec, bufnr)
  pcall(vim.api.nvim_buf_set_var, bufnr, spec.triggered_var, true)
  run_disable_pass(spec.name, bufnr, false)
  run_disable_pass(spec.name, bufnr, true)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      run_disable_pass(spec.name, bufnr, false)
    end
  end)
end

-- Evaluate a buffer against resolved params and, if it matches, disable.
-- Deferred with vim.schedule so we run AFTER the BufReadPost -> FileType chain;
-- otherwise user FileType autocmds re-enable features after our disable.
local function process_buffer(spec, cfg, params, bufnr)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local size_mib, size_bytes = get_buf_size(bufnr)
    if size_mib == nil then return end
    local matched, message = spec.evaluate(params, size_mib, size_bytes, bufnr)
    if not matched then return end
    if cfg.notify and message then emit_notify(message) end
    disable_for_buffer(spec, bufnr)
  end)
end

-- Resolve which params apply to a buffer by matching its name against the
-- extra_patterns (first match wins), falling back to the base config. Used for
-- the current-buffer path at init time, where no autocmd fires to carry the
-- per-pattern thresholds.
local function params_for_buffer(spec, cfg, bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  for _, override in ipairs(cfg.extra_patterns or {}) do
    if override.pattern and vim.fn.match(fname, vim.fn.glob2regpat(override.pattern)) >= 0 then
      return spec.params_from_override(cfg, override)
    end
  end
  return spec.params_from_cfg(cfg)
end

function M.init(spec, opts)
  opts = opts or {}
  local cfg = FasterConfig.behaviours[spec.name]
  local augroup = vim.api.nvim_create_augroup(spec.augroup, {})

  local default_params = spec.params_from_cfg(cfg)
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = cfg.pattern,
    group = augroup,
    callback = function(args) process_buffer(spec, cfg, default_params, args.buf) end,
    desc = spec.desc(default_params, nil),
  })

  for _, override in ipairs(cfg.extra_patterns or {}) do
    if override.pattern ~= nil then
      local params = spec.params_from_override(cfg, override)
      vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = override.pattern,
        group = augroup,
        callback = function(args) process_buffer(spec, cfg, params, args.buf) end,
        desc = spec.desc(params, override.pattern),
      })
    end
  end

  -- Process the currently open buffer too: useful when init() is called via
  -- :Faster enable <behaviour> while sitting on an already-open matching file.
  -- Skip when init() is part of a group enable (:Faster enable all|behaviours)
  -- — the user explicitly asked for everything to be on, so don't re-disable.
  if not opts.skip_current then
    local cur = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(cur) ~= "" then
      process_buffer(spec, cfg, params_for_buffer(spec, cfg, cur), cur)
    end
  end
end

function M.stop(spec)
  -- pcall: stop() may be called when the augroup doesn't exist (behaviour was
  -- never armed, or already stopped). nvim_del_augroup_by_name errors on a
  -- missing group, so guard to keep stop() idempotent.
  pcall(vim.api.nvim_del_augroup_by_name, spec.augroup)
  -- Restore EVERY buffer this behaviour disabled, each in its own context. The
  -- disable path is per-buffer (nvim_buf_call + per-bufnr option backups), so
  -- the restore must be too: a plain current-buffer restore would leave any
  -- other triggered buffer stuck with features off. Within each buffer, restore
  -- defer=true (filetype/syntax/vimopts) before defer=false (lsp): lsp.enable()
  -- bails when &filetype is still empty, so filetype must come back first.
  -- The triggered marker is the source of truth for what we disabled; clear it
  -- as we go so :Faster status reports runtime state honestly.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local ok, triggered = pcall(vim.api.nvim_buf_get_var, bufnr, spec.triggered_var)
    if ok and triggered == true and vim.api.nvim_buf_is_valid(bufnr) then
      enable_pass(spec.name, bufnr, true)
      enable_pass(spec.name, bufnr, false)
    end
    pcall(vim.api.nvim_buf_del_var, bufnr, spec.triggered_var)
  end
end

return M
