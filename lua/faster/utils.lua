local M = {}

-- UTILS

function M.print_error(e)
  vim.api.nvim_echo({ { e, "ErrorMsg" } }, true, {})
end

function M.print_config()
  print(vim.inspect(FasterConfig))
end

-- FEATURES

function M.enable_all_features()
  for _, f in pairs(FasterConfig.features) do
    if f.on then
      f.enable()
    end
  end
end

function M.disable_all_features()
  for _, f in pairs(FasterConfig.features) do
    if f.on then
      f.disable()
    end
  end
end

function M.run_on_features(feature_names, func, cond_func)
  if func == nil then return end

  local features = {}

  if feature_names == 'all' then
    features = FasterConfig.features
  else
    for _, fname in ipairs(feature_names) do
      local f = FasterConfig.features[fname]
      features[fname] = f
    end
  end

  for _, f in pairs(features) do
    -- A nil cond_func means "every selected feature". The old contract
    -- (nil -> match nothing) silently ran no-ops and was an easy footgun.
    if f.on and (cond_func == nil or cond_func(f)) then
      func(f)
    end
  end
end

return M
