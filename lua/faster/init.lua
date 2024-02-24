local features = require('faster.features')
local behaviours = require('faster.behaviours')

local M = {}

local default_config = {
  features = features,
  behaviours = behaviours,
}

Config = {}

function M.setup(opts)
  Config = vim.tbl_deep_extend("force", default_config, opts or {})

  -- Initialize features
  for _, f in pairs(Config.features) do
    if f.on then
      f.commands()
    end
  end

  -- Initialize behaviours
  for _, b in pairs(Config.behaviours) do
    if b.on then
      b.init()
    end
  end

  -- Initialize commands
  require('faster.commands')
end

M.config = M.setup

return M
