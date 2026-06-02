local utils = require('faster.utils')

-- Build the dispatch tables once, after FasterConfig is populated by setup().

---@type table<string, fun()>
local enable  = {}
---@type table<string, fun()>
local disable = {}

local function notify_action(action, target)
  vim.notify(
    string.format("faster.nvim: %s %s", action, target),
    vim.log.levels.INFO,
    { title = "faster.nvim" }
  )
end

-- Behaviours (bigfile, fastmacro, ...): toggle runtime + config flag.
for name, b in pairs(FasterConfig.behaviours) do
  enable[name] = function()
    b.on = true
    b.init()
    notify_action("enabled behaviour", name)
  end
  disable[name] = function()
    b.stop()
    b.on = false
    notify_action("disabled behaviour", name)
  end
end

-- Group targets: all features, all behaviours, or everything.
local function enable_all_features_with_flag()
  -- Enable defer=true features (filetype, syntax, vimopts) first so that
  -- features that depend on them (e.g. lsp reads &filetype) see the restored
  -- values when they enable. pairs() ordering is undefined, so we explicitly
  -- run two passes.
  for _, f in pairs(FasterConfig.features) do
    if f.defer == true then
      f.on = true
      f.enable()
    end
  end
  for _, f in pairs(FasterConfig.features) do
    if f.defer ~= true then
      f.on = true
      f.enable()
    end
  end
end
local function disable_all_features_with_flag()
  for _, f in pairs(FasterConfig.features) do
    f.disable()
    f.on = false
  end
end
local function enable_all_behaviours()
  -- skip_current = true: re-arm autocmds but don't process the currently
  -- open buffer. Group enable means "everything on now"; processing the
  -- current buffer here would queue a feature disable that immediately
  -- undoes the feature enable that happens right after.
  for _, b in pairs(FasterConfig.behaviours) do
    b.on = true
    b.init({ skip_current = true })
  end
end
local function disable_all_behaviours()
  for _, b in pairs(FasterConfig.behaviours) do
    b.stop()
    b.on = false
  end
end

enable.features = function()
  enable_all_features_with_flag()
  notify_action("enabled", "all features")
end
disable.features = function()
  disable_all_features_with_flag()
  notify_action("disabled", "all features")
end

enable.behaviours = function()
  enable_all_behaviours()
  notify_action("enabled", "all behaviours")
end
disable.behaviours = function()
  disable_all_behaviours()
  notify_action("disabled", "all behaviours")
end

enable.all = function()
  enable_all_behaviours()
  enable_all_features_with_flag()
  notify_action("enabled", "all behaviours and features")
end
disable.all = function()
  disable_all_behaviours()
  disable_all_features_with_flag()
  notify_action("disabled", "all behaviours and features")
end

-- Individual features (illuminate, matchparen, lsp, treesitter, ...).
-- Toggling f.on lets behaviours skip features the user opted out of.
for name, f in pairs(FasterConfig.features) do
  enable[name] = function()
    f.on = true
    f.enable()
    notify_action("enabled feature", name)
  end
  disable[name] = function()
    f.disable()
    f.on = false
    notify_action("disabled feature", name)
  end
end

local actionless = {
  config = function() utils.print_config() end,
  status = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = {
      string.format("faster.nvim status (buffer %d: %s)",
        bufnr, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")),
      "",
      "  behaviours:               on        active",
    }
    -- Sort behaviour names for stable output.
    local bnames = vim.tbl_keys(FasterConfig.behaviours)
    table.sort(bnames)
    for _, name in ipairs(bnames) do
      local b = FasterConfig.behaviours[name]
      local active_str
      if type(b.is_active) == "function" then
        local ok, result = pcall(b.is_active, bufnr)
        if not ok then
          active_str = "error"
        elseif result == nil then
          active_str = "?"
        else
          active_str = tostring(result)
        end
      else
        active_str = "?"
      end
      table.insert(lines, string.format("    %-22s    %-7s   %s",
        name, tostring(b.on), active_str))
    end
    table.insert(lines, "")
    table.insert(lines, "  features:                 on        active")
    -- Sort feature names for stable output.
    local fnames = vim.tbl_keys(FasterConfig.features)
    table.sort(fnames)
    for _, name in ipairs(fnames) do
      local f = FasterConfig.features[name]
      local active_str
      if type(f.is_active) == "function" then
        local ok, result = pcall(f.is_active, bufnr)
        if not ok then
          active_str = "error"
        elseif result == nil then
          active_str = "?"
        else
          active_str = tostring(result)
        end
      else
        active_str = "?"
      end
      table.insert(lines, string.format("    %-22s    %-7s   %s",
        name, tostring(f.on), active_str))
    end
    print(table.concat(lines, "\n"))
  end,
  help = function()
    local targets = vim.tbl_keys(enable)
    table.sort(targets)
    print(table.concat({
      "Usage: :Faster <command> [target]",
      "",
      "  enable  <target>",
      "  disable <target>",
      "  config",
      "  status",
      "  help",
      "",
      "Targets: " .. table.concat(targets, ", "),
    }, "\n"))
  end,
}

local actions = { enable = enable, disable = disable }

local function dispatch(opts)
  local args = opts.fargs
  if #args == 0 then
    actionless.help()
    return
  end

  local action = args[1]

  if actionless[action] then
    actionless[action]()
    return
  end

  local targets = actions[action]
  if not targets then
    utils.print_error(string.format(
      "[faster.nvim] unknown command: %q. Try `:Faster help`.", action
    ))
    return
  end

  local target = args[2]
  if not target then
    utils.print_error(string.format(
      "[faster.nvim] :Faster %s needs a target. Try `:Faster help`.", action
    ))
    return
  end

  local handler = targets[target]
  if not handler then
    utils.print_error(string.format(
      "[faster.nvim] unknown target %q for `:Faster %s`. Try `:Faster help`.", target, action
    ))
    return
  end

  handler()
end

-- Tab-completion: top-level commands at position 1, targets at position 2.
local top_level = { "enable", "disable", "config", "status", "help" }

local function complete(arglead, cmdline, _)
  local args = vim.split(cmdline, "%s+", { trimempty = false })
  local function filter(list)
    return vim.tbl_filter(function(x)
      return x:find("^" .. vim.pesc(arglead)) ~= nil
    end, list)
  end
  if #args <= 2 then
    return filter(top_level)
  elseif #args == 3 and (args[2] == "enable" or args[2] == "disable") then
    local list = vim.tbl_keys(actions[args[2]])
    table.sort(list)
    return filter(list)
  end
  return {}
end

vim.api.nvim_create_user_command("Faster", dispatch, {
  nargs = "*",
  complete = complete,
  desc = "faster.nvim — :Faster help for usage",
})
