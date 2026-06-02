local utils = require('faster.utils')

local M = {}

local cleanup_autocmd_id = nil
local saved_eventignore = nil
local saved_lazyredraw = nil

local function restore_after_macro()
  cleanup_autocmd_id = nil

  if saved_eventignore ~= nil then
    vim.o.eventignore = saved_eventignore
    saved_eventignore = nil
  end

  if saved_lazyredraw ~= nil then
    vim.o.lazyredraw = saved_lazyredraw
    saved_lazyredraw = nil
  end

  vim.keymap.set({ 'n' }, '@', M._execute_macro)

  utils.run_on_features(
    FasterConfig.behaviours.fastmacro.features_disabled,
    function(f) f.enable() end,
    function(f) return f.defer == true end
  )

  utils.run_on_features(
    FasterConfig.behaviours.fastmacro.features_disabled,
    function(f) f.enable() end,
    function(f) return f.defer == false end
  )
end

function M._execute_macro()
  local reg = vim.fn.nr2char(vim.fn.getchar())

  utils.run_on_features(
    FasterConfig.behaviours.fastmacro.features_disabled,
    function(f) f.disable() end,
    function(f) return f.defer == false end
  )

  utils.run_on_features(
    FasterConfig.behaviours.fastmacro.features_disabled,
    function(f) f.disable() end,
    function(f) return f.defer == true end
  )

  local count = vim.v.count or 1
  if count < 1 then count = 1 end

  vim.keymap.del('n', '@')

  -- Suppress autocommands and screen redraws during macro execution
  saved_eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'
  saved_lazyredraw = vim.o.lazyredraw
  vim.o.lazyredraw = true

  cleanup_autocmd_id = vim.api.nvim_create_autocmd('SafeState', {
    once = true,
    callback = restore_after_macro,
  })

  vim.fn.feedkeys(count .. '@' .. reg, '')
end

function M.init()
  vim.keymap.set({ 'n' }, '@', M._execute_macro)
end

function M.stop()
  vim.keymap.del('n', '@')

  if cleanup_autocmd_id then
    vim.api.nvim_del_autocmd(cleanup_autocmd_id)
    cleanup_autocmd_id = nil
  end

  if saved_eventignore ~= nil then
    vim.o.eventignore = saved_eventignore
    saved_eventignore = nil
  end

  if saved_lazyredraw ~= nil then
    vim.o.lazyredraw = saved_lazyredraw
    saved_lazyredraw = nil
  end

  utils.run_on_features(
    FasterConfig.behaviours.fastmacro.features_disabled,
    function(f) f.enable() end,
    function(f) return f.defer == true end
  )

  utils.run_on_features(
    FasterConfig.behaviours.fastmacro.features_disabled,
    function(f) f.enable() end,
    function(f) return f.defer == false end
  )
end

return M
