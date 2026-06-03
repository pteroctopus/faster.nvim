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

-- Primary cleanup trigger: a sentinel command queued behind the macro in the
-- typeahead (see _execute_macro). Because the macro (including recursive @)
-- expands at the front of the typeahead, anything fed after it drains only
-- once the whole macro has finished -> deterministic, zero-latency cleanup.
-- Guarded by cleanup_pending so it no-ops if the poll backstop got there first.
function M._cleanup()
  if not cleanup_pending then return end
  restore_after_macro()
end

-- Backstop only. The sentinel handles the normal path instantly; this catches
-- the one case the sentinel can't: a macro that errors (e.g. a failed search
-- at EOF) causes Vim to flush the typeahead, taking the sentinel with it. Then
-- this poll detects reg_executing() == "" and restores state so eventignore
-- doesn't stay 'all' and freeze the editor.
--
-- Autocmds are blocked by eventignore='all' (which we want for max macro
-- throughput); libuv timers (used by vim.defer_fn) are not, so we poll.
-- Transitions: reg_executing() goes "" -> <reg> -> "" across the lifetime of
-- one macro invocation. If the macro completes before the first poll, we bail
-- after ~100 ms of idle polls. The latency here is irrelevant since this only
-- runs on the rare error-flush path.
local function poll_macro_done()
  if not cleanup_pending then return end

  if vim.fn.reg_executing() ~= "" then
    -- Macro is currently running; reset idle counter.
    macro_seen = true
    idle_polls = 0
    vim.defer_fn(poll_macro_done, 10)
  elseif macro_seen then
    -- We saw it running, now it's done.
    restore_after_macro()
  else
    -- Macro hasn't started yet (or completed before first poll). Re-check
    -- after 10 ms; bail out and clean up after ~100 ms of no activity.
    idle_polls = idle_polls + 1
    if idle_polls >= 10 then
      restore_after_macro()
    else
      vim.defer_fn(poll_macro_done, 10)
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
  -- eventignore = 'all' is fine here because cleanup doesn't rely on autocmds:
  -- the primary trigger is a <Cmd> sentinel in the typeahead (below) and the
  -- backstop poller uses vim.defer_fn (libuv timer) — neither is blocked by
  -- eventignore.
  saved_eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'
  saved_lazyredraw = vim.o.lazyredraw
  vim.o.lazyredraw = true

  cleanup_pending = true
  macro_seen = false
  idle_polls = 0

  vim.fn.feedkeys(count .. '@' .. reg, '')

  -- Queue the cleanup sentinel directly behind the macro in the typeahead.
  -- It runs the instant the macro drains (recursion included) -> no latency,
  -- no race with the poll. <Cmd>...<CR> is an ex command, not an autocmd, so
  -- it still fires under eventignore='all'.
  vim.fn.feedkeys(
    vim.keycode('<Cmd>lua require("faster.macro")._cleanup()<CR>'),
    'n'
  )

  -- Backstop for the error-flush case only (see poll_macro_done). First poll
  -- fires next tick; subsequent polls run at 10 ms cadence.
  vim.defer_fn(poll_macro_done, 0)
end

function M.init()
  vim.keymap.set({ 'n' }, '@', M._execute_macro)
end

function M.stop()
  vim.keymap.del('n', '@')

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
