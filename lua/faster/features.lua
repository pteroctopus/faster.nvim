local M = {}

-- Illuminate plugin
-- https://github.com/RRethy/vim-illuminate

M.illuminate = {
  on = true,
  defer = false,
  -- Use the Lua API directly so that requiring forces vim-illuminate to load
  -- (it's commonly lazy-loaded on CursorHold, in which case the
  -- :IlluminatePauseBuf user command doesn't exist yet at BufReadPost time).
  enable = function()
    pcall(function()
      require('illuminate').resume_buf()
      -- resume_buf only clears the per-buffer pause flag; illuminate refreshes
      -- highlights on CursorMoved. Force one so the user sees results
      -- immediately after :Faster enable illuminate without having to move
      -- the cursor.
      pcall(function()
        require('illuminate.engine').refresh_references(
          vim.api.nvim_get_current_buf(),
          vim.api.nvim_get_current_win()
        )
      end)
    end)
  end,

  disable = function()
    pcall(function() require('illuminate').pause_buf() end)
  end,

  -- vim-illuminate's public `is_paused()` only returns the global pause flag,
  -- not per-buffer state. `pause_buf()` correctly sets a per-buffer flag
  -- internally, but there's no public probe for it. We return nil ("?") for
  -- per-buffer queries; users can verify via "do I see other instances of
  -- the word under cursor highlighted?".
  is_active = function(_)
    local ok, illuminate = pcall(require, 'illuminate')
    if not ok then return nil end
    -- If the global pause flag is set, illuminate is definitely off.
    if type(illuminate.is_paused) == 'function' and illuminate.is_paused() then
      return false
    end
    return nil
  end,
}

-- MatchParen

M.matchparen = {
  on = true,
  defer = false,
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
  end,

  is_active = function(_)
    -- :NoMatchParen sets g:loaded_matchparen = 0 (or undefines it).
    return vim.g.loaded_matchparen == 1
  end,
}

-- LSP

M.lsp = {
  on = true,
  defer = false,
  enable = function()
    -- Filetype check first — warn even if :LspStart isn't available, since
    -- "filetype is empty" is the actionable signal for the user. :LspStart
    -- resolves the server from &filetype; with an empty filetype no server
    -- matches and the start is a silent no-op.
    if vim.bo.filetype == "" then
      vim.notify(
        "[faster.nvim] LSP enable skipped — &filetype is empty. " ..
        "Run `:Faster enable filetype` first.",
        vim.log.levels.WARN,
        { title = "faster.nvim" }
      )
      return
    end
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
  end,

  is_active = function(bufnr)
    bufnr = bufnr or 0
    return #vim.lsp.get_clients({ bufnr = bufnr }) > 0
  end,
}


-- Treesitter
--
-- Uses Neovim's built-in vim.treesitter API (stable since 0.9), which works
-- for both nvim-treesitter v0.x (master) and v1 (main / archived). The old
-- v0.x API (require 'nvim-treesitter.configs', :TSBufDisable, available_modules)
-- was removed in v1 and would silently no-op there.

M.treesitter = {
  on = true,
  defer = false,
  enable = function()
    pcall(vim.treesitter.start, 0)
  end,

  disable = function()
    pcall(vim.treesitter.stop, 0)
  end,

  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    -- vim.treesitter.highlighter.active is keyed by bufnr.
    local ok, hl = pcall(require, 'vim.treesitter.highlighter')
    if not ok or not hl then return nil end
    return hl.active and hl.active[bufnr] ~= nil
  end,
}

-- Indent Blankline
-- https://github.com/lukas-reineke/indent-blankline.nvim

M.indent_blankline = {
  on = true,
  defer = false,
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
  end,

  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ok, conf = pcall(require, 'ibl.config')
    if not ok or type(conf.get_config) ~= 'function' then return nil end
    local c = conf.get_config(bufnr)
    if c == nil then return nil end
    return c.enabled
  end,
}


-- Vimopts
--

local vimopts_backup = {}
local vimopts_disabled = false

M.vimopts = {
  on = true,
  defer = false,
  enable = function()
    if vimopts_disabled == true then
      vim.opt_local.swapfile = vimopts_backup.swapfile
      vim.opt_local.foldmethod = vimopts_backup.foldmethod
      vim.opt_local.undolevels = vimopts_backup.undolevels
      vim.opt_local.undoreload = vimopts_backup.undoreload
      vim.opt_local.list = vimopts_backup.list
      vim.opt_local.spell = vimopts_backup.spell
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
      vimopts_backup.spell = vim.opt_local.spell
      vimopts_disabled = true
    end

    vim.opt_local.swapfile = false
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.undolevels = -1
    vim.opt_local.undoreload = 0
    vim.opt_local.list = false
    vim.opt_local.spell = false
  end,

  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    -- "Active" = opts have NOT been clamped by our disable. Use undolevels
    -- as the proxy; -1 is the value we set on disable.
    local undolevels = vim.api.nvim_get_option_value("undolevels",
      { buf = bufnr, scope = "local" })
    return undolevels ~= -1
  end,
}

-- Syntax

local syntax_backup = {}
local syntax_disabled = false

M.syntax = {
  on = true,
  defer = true,
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
  end,

  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local syn = vim.api.nvim_get_option_value("syntax",
      { buf = bufnr, scope = "local" })
    return syn ~= "" and syn ~= "off" and syn ~= "OFF"
  end,
}


-- Filetype

local filetype_backup = {}
local filetype_disabled = false

M.filetype = {
  on = true,
  defer = true,
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
  end,

  is_active = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_get_option_value("filetype",
      { buf = bufnr, scope = "local" })
    return ft ~= ""
  end,
}

-- Lualine
-- https://github.com/nvim-lualine/lualine.nvim

M.lualine = {
  on = true,
  defer = false,
  -- lualine doesn't expose a public is_hidden query, and probing &statusline
  -- isn't reliable across configs. Track state ourselves with a global var.
  enable = function()
    pcall(function()
      require('lualine').hide({ unhide = true })
      vim.g.faster_lualine_hidden = false
    end)
  end,

  disable = function()
    pcall(function()
      require('lualine').hide()
      vim.g.faster_lualine_hidden = true
    end)
  end,

  is_active = function(_)
    -- nil = we never touched lualine, assume it's running (the default)
    if vim.g.faster_lualine_hidden == nil then return true end
    return not vim.g.faster_lualine_hidden
  end,
}

M.mini_clue = {
  on = true,
  defer = false,
  -- mini.clue has no public is_disabled query; track state ourselves.
  enable = function()
    pcall(function()
      MiniClue.enable_all_triggers()
      vim.g.faster_mini_clue_disabled = false
    end)
  end,

  disable = function()
    pcall(function()
      MiniClue.disable_all_triggers()
      vim.g.faster_mini_clue_disabled = true
    end)
  end,

  is_active = function(_)
    if vim.g.faster_mini_clue_disabled == nil then return true end
    return not vim.g.faster_mini_clue_disabled
  end,
}

return M
