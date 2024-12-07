local utils = require('faster.utils')

local M = {}

local function execute_macro()
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

  xpcall(
    function()
      vim.cmd('noautocmd normal! ' .. count .. '@' .. reg)
    end,
    function(e)
      utils.print_error(e)
    end
  )

  vim.keymap.set({ 'n' }, '@', execute_macro)

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

function M.init()
  vim.keymap.set({ 'n' }, '@', execute_macro)
end

function M.stop()
  vim.keymap.del('n', '@')

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
