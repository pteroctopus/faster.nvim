local M = {}

-- UTILS

function M.print_error(e)
  vim.api.nvim_echo({ { e, "ErrorMsg" } }, true, {})
end

function M.print_config()
  print(vim.inspect(Config))
end

-- BEHAVIOURS

function M.enable_fast_macro()
  Config.behaviours.fastmacro.init()
end

function M.disable_fast_macro()
  --TODO disableFastMacro
end

function M.enable_big_file()
  Config.behaviours.bigfile.init()
end

function M.disable_big_file()
  --TODO disableBigFile
end

-- FEATURES

function M.enable_all_features()
  for _, f in pairs(Config.features) do
    if f.on then
      f.enable()
    end
  end
end

function M.disable_all_features()
  for _, f in pairs(Config.features) do
    if f.on then
      f.disable()
    end
  end
end

function M.run_on_features(feature_names, func, cond_func)
  if func == nil then return end

  local features = {}

  if feature_names == 'all' then
    features = Config.features
  else
    for _, fname in ipairs(feature_names) do
      local f = Config.features[fname]
      features[fname] = f
    end
  end

  for _, f in pairs(features) do
    if f.on and (cond_func ~= nil and cond_func(f)) then
      func(f)
    end
  end
end

return M
