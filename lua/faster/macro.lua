local utils = require('faster.utils')

local M = {}

local cleanup_pending = false
local saved_eventignore = nil
local saved_lazyredraw = nil
local macro_seen = false
local idle_polls = 0

local function restore_after_macro()
  cleanup_pending = false
  macro_seen = false
  idle_polls = 0

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

-- Poll vim.fn.reg_executing() to detect "macro done" without relying on
-- autocmds (autocmds are blocked by eventignore='all'; libuv timers used
-- by vim.defer_fn are not). We use async feedkeys (mode '') so Vim's main
-- loop stays responsive — sync feedkeys('x') can hang on recursive macros
-- that grow the typeahead (e.g. /search<CR>...@q calling itself).
--
-- Transitions watched: reg_executing() goes "" -> <reg> -> "" across the
-- lifetime of one macro invocation.
local IDLE_POLL_LIMIT = 2 -- ~20 ms before assuming sub-poll macro is done
local POLL_INTERVAL_MS = 10

local function poll_macro_done()
  if not cleanup_pending then return end

  if vim.fn.reg_executing() ~= "" then
    macro_seen = true
    idle_polls = 0
    vim.defer_fn(poll_macro_done, POLL_INTERVAL_MS)
  elseif macro_seen then
    restore_after_macro()
  else
    -- Macro hasn't been observed running yet — either hasn't started or
    -- completed faster than our polling cadence. After IDLE_POLL_LIMIT
    -- empty polls, assume it's done and clean up.
    idle_polls = idle_polls + 1
    if idle_polls >= IDLE_POLL_LIMIT then
      restore_after_macro()
    else
      vim.defer_fn(poll_macro_done, POLL_INTERVAL_MS)
    end
  end
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

  -- Suppress autocommands AND screen redraws during macro execution.
  -- eventignore = 'all' blocks autocmds (including SafeState) but does not
  -- block vim.defer_fn (libuv timer), so the polling cleanup still fires.
  saved_eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'
  saved_lazyredraw = vim.o.lazyredraw
  vim.o.lazyredraw = true

  cleanup_pending = true
  macro_seen = false
  idle_polls = 0

  vim.fn.feedkeys(count .. '@' .. reg, '')

  -- First poll on next event tick (essentially 0 ms) so short macros'
  -- cleanup is near-instant; subsequent polls at POLL_INTERVAL_MS.
  vim.defer_fn(poll_macro_done, 0)
end

function M.init()
  vim.keymap.set({ 'n' }, '@', M._execute_macro)
end

function M.stop()
  pcall(vim.keymap.del, 'n', '@')

  cleanup_pending = false
  macro_seen = false
  idle_polls = 0

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
