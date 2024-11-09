local M = {}

-- Illuminate plugin
-- https://github.com/RRethy/vim-illuminate

M.illuminate = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableIlluminate', M.illuminate.enable, {})
    vim.api.nvim_create_user_command('FasterDisableIlluminate', M.illuminate.disable, {})
  end,

  enable = function()
    if vim.fn.exists(':IlluminateResumeBuf') ~= 2 then
      return
    end
    vim.cmd('IlluminateResumeBuf')
  end,

  disable = function()
    if vim.fn.exists(':IlluminatePauseBuf') ~= 2 then
      return
    end
    vim.cmd('IlluminatePauseBuf')
  end,
}

-- MatchParen

M.matchparen = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableMatchparen', M.matchparen.enable, {})
    vim.api.nvim_create_user_command('FasterDisableMatchparen', M.matchparen.disable, {})
  end,

  enable = function()
    if vim.fn.exists(':DoMatchParen') ~= 2 then
      return
    end
    vim.cmd('DoMatchParen')
  end,

  disable = function()
    if vim.fn.exists(':NoMatchParen') ~= 2 then
      return
    end
    vim.cmd('NoMatchParen')
  end
}

-- LSP

M.lsp = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableLsp', M.lsp.enable, {})
    vim.api.nvim_create_user_command('FasterDisableLsp', M.lsp.disable, {})
  end,

  enable = function()
    if vim.fn.exists(':LspStart') ~= 2 then
      return
    end
    vim.cmd('LspStart')
  end,

  disable = function()
    if vim.fn.exists(':LspStop') ~= 2 then
      return
    end
    vim.cmd('LspStop')
  end
}


-- Treesitter

local treesitter_backup = {}
local treesitter_disabled = false

M.treesitter = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableTreesitter', M.treesitter.enable, {})
    vim.api.nvim_create_user_command('FasterDisableTreesitter', M.treesitter.disable, {})
  end,

  enable = function()
    local status_ok, _ = pcall(require, 'nvim-treesitter.configs')
    if not status_ok then
      return
    end

    if vim.fn.exists(':TSBufEnable') ~= 2 then
      return
    end

    if treesitter_disabled == true then
      -- Return treesitter module state from backup
      for _, mod_state in ipairs(treesitter_backup) do
        if mod_state.enable then
          vim.cmd('TSBufEnable ' .. mod_state.mod_name)
        end
      end
      treesitter_disabled = false
    end
  end,

  disable = function()
    local status_ok, ts_config = pcall(require, 'nvim-treesitter.configs')
    if not status_ok then
      return
    end

    if vim.fn.exists(':TSBufDisable') ~= 2 then
      return
    end

    -- Backup current treesitter module "enable" state
    if treesitter_disabled == false then
      for _, mod_name in ipairs(ts_config.available_modules()) do
        local module_config = ts_config.get_module(mod_name) or {}
        table.insert(treesitter_backup, { mod_name = mod_name, enable = module_config.enable })
      end
      treesitter_disabled = true
    end

    for _, mod_name in ipairs(ts_config.available_modules()) do
      vim.cmd('TSBufDisable ' .. mod_name)
    end
  end

}

-- Indent Blankline
-- https://github.com/lukas-reineke/indent-blankline.nvim

M.indent_blankline = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableIndentblankline', M.indent_blankline.enable, {})
    vim.api.nvim_create_user_command('FasterDisableIndentblankline', M.indent_blankline.disable, {})
  end,

  enable = function()
    if vim.fn.exists(':IBLEnable') ~= 2 then
      return
    end
    vim.cmd('IBLEnable')
  end,

  disable = function()
    if vim.fn.exists(':IBLDisable') ~= 2 then
      return
    end
    vim.cmd('IBLDisable')
  end
}


-- Vimopts
--

local vimopts_backup = {}
local vimopts_disabled = false

M.vimopts = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableVimopts', M.vimopts.enable, {})
    vim.api.nvim_create_user_command('FasterDisableVimopts', M.vimopts.disable, {})
  end,

  enable = function()
    if vimopts_disabled == true then
      vim.opt_local.swapfile = vimopts_backup.swapfile
      vim.opt_local.foldmethod = vimopts_backup.foldmethod
      vim.opt_local.undolevels = vimopts_backup.undolevels
      vim.opt_local.undoreload = vimopts_backup.undoreload
      vim.opt_local.list = vimopts_backup.list
      vimopts_disabled = false
    end
  end,

  disable = function()
    if vimopts_disabled == false then
      vimopts_backup.swapfile = vim.opt_local.swapfile
      vimopts_backup.foldmethod = vim.opt_local.foldmethod
      vimopts_backup.undolevels = vim.opt_local.undolevels
      vimopts_backup.undoreload = vim.opt_local.undoreload
      vimopts_backup.list = vim.opt_local.list
      vimopts_disabled = true
    end

    vim.opt_local.swapfile = false
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.undolevels = -1
    vim.opt_local.undoreload = 0
    vim.opt_local.list = false
  end
}

-- Syntax

local syntax_backup = {}
local syntax_disabled = false

M.syntax = {
  on = true,
  defer = true,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableSyntax', M.syntax.enable, {})
    vim.api.nvim_create_user_command('FasterDisableSyntax', M.syntax.disable, {})
  end,

  enable = function()
    if syntax_disabled == true then
      vim.opt_local.syntax = syntax_backup.syntax
      syntax_disabled = false
    end
  end,

  disable = function()
    if syntax_disabled == false then
      syntax_backup.syntax = vim.opt_local.syntax
      syntax_disabled = true
    end
    vim.cmd 'syntax clear'
    vim.opt_local.syntax = 'off'
  end
}


-- Filetype

local filetype_backup = {}
local filetype_disabled = false

M.filetype = {
  on = true,
  defer = true,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableFiletype', M.filetype.enable, {})
    vim.api.nvim_create_user_command('FasterDisableFiletype', M.filetype.disable, {})
  end,

  enable = function()
    if filetype_disabled == true then
      vim.opt_local.filetype = filetype_backup.filetype
      filetype_disabled = false
    end
  end,

  disable = function()
    if filetype_disabled == false then
      filetype_backup.filetype = vim.opt_local.filetype
      filetype_disabled = true
    end
    vim.opt_local.filetype = ""
  end
}

-- Lualine
-- https://github.com/nvim-lualine/lualine.nvim

M.lualine = {
  on = true,
  defer = false,

  commands = function()
    vim.api.nvim_create_user_command('FasterEnableLualine', M.lualine.enable, {})
    vim.api.nvim_create_user_command('FasterDisableLualine', M.lualine.disable, {})
  end,

  enable = function()
    pcall(function()
      require('lualine').hide({ unhide = true })
    end)
  end,

  disable = function()
    pcall(function()
      require('lualine').hide()
    end)
  end
}

return M
