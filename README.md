# Faster.nvim

Faster.nvim is a Neovim plugin inspired by
[bigfile.nvim](https://github.com/LunarVim/bigfile.nvim).

bigfile.nvim concept and code for handling of big files has been used as a
starting point for faster.nvim.

Some Neovim plugins and features can make Neovim slow when editing big files and
executing macros. Faster.nvim will selectively disable some features when big
file is opened or macro is executed.

Faster.nvim also gives ability to define custom behaviours and features so user
can disable other plugins or Neovim options based on custom behaviour or the
ones already implemented in this plugin.

This plugin will have minimal impact on the speed of Neovim if no extra
configuration or plugins are used. But as more and more Neovim options are
enabled and plugins installed its impact can be significant.

# Speed comparison

Speed comparison was done with three neovim configs:

- Left: [Highly customized Neovim](https://github.com/pteroctopus/neovim-config) (a lot of plugins and options)
- Middle: Vanilla Neovim: `nvim -u NONE`
- Right: Highly customized Neovim (a lot of plugins and options) but with
  faster.nvim plugin

**NOTE!:** Speed will certainly be different for executions on different
computers and with different plugins. If your Neovim is slow even with
faster.nvim that means that some other plugin or options is used that is not
considered in faster.nvim. Resolution would be to find the offending plugin or
option and configure a new feature that faster.nvim can use as explained below.

Bigfile opening speed:

https://github.com/pteroctopus/faster.nvim/assets/138196695/20496c45-a36e-488f-927a-dda2ea939750

Macro execution speed:

https://github.com/pteroctopus/faster.nvim/assets/138196695/99e5e890-6001-4d3f-b89c-316b9a24cced

# Installation

- lazy.nvim

```lua
return {
    'pteroctopus/faster.nvim'
}
```

# Configuration

Call:

```lua
require('faster').setup()
```

Or if you use lazy.nvim use opts like below. Further Examples are going to
assume lazy.nvim is being used.

## Minimal configuration

```lua
return {
    'pteroctopus/faster.nvim'
}
```

## Default configuration without function overrides:

```lua
opts = {
  -- Behaviour table contains configuration for behaviours faster.nvim uses
  behaviours = {
    -- Bigfile configuration controls disabling and enabling of features when
    -- big file is opened 
    bigfile = {
      -- Behaviour can be turned on or off. To turn on set to true, otherwise
      -- set to false
      on = true,
      -- Table which contains names of features that will be disabled when
      -- bigfile is opened. Feature names can be seen in features table below.
      -- features_disabled can also be set to "all" and then all features that
      -- are on (on=true) are going to be disabled for this behaviour
      features_disabled = {
        "illuminate", "matchparen", "lsp", "treesitter",
        "indent_blankline", "vimopts", "syntax", "filetype"
      },
      -- Files larger than `filesize` are considered big files. Value is in MB.
      filesize = 2,
      -- Autocmd pattern that controls on which files behaviour will be applied.
      -- `*` means any file.
      pattern = "*",
      -- Optional extra patterns and sizes for which bigfile behaviour will apply.
      -- Note! that when multiple patterns (including the main one) and filesizes
      -- are defined: bigfile behaviour will be applied for minimum filesize of
      -- those defined in all applicable patterns for that file.
      -- extra_pattern example in multi line comment is bellow:
      --[[
      extra_patterns = {
        -- If this is used than bigfile behaviour for *.md files will be
        -- triggered for filesize of 1.1MiB
        { filesize = 1.1, pattern = "*.md" },
        -- If this is used than bigfile behaviour for *.log file will be
        -- triggered for the value in `behaviours.bigfile.filesize`
        { pattern  = "*.log" },
        -- Next line is invalid without the pattern and will be ignored
        { filesize = 3 },
      },
      ]]
      -- By default `extra_patterns` is an empty table: {}.
      extra_patterns = {},
    },
    -- Fast macro configuration controls disabling and enabling features when
    -- macro is executed
    fastmacro = {
      -- Behaviour can be turned on or off. To turn on set to true, otherwise
      -- set to false
      on = true,
      -- Table which contains names of features that will be disabled when
      -- macro is executed. Feature names can be seen in features table below.
      -- features_disabled can also be set to "all" and then all features that
      -- are on (on=true) are going to be disabled for this behaviour.
      -- Specificaly: lualine plugin is disabled when macros are executed because
      -- if a recursive macro opens a buffer on every iteration this error will
      -- happen after 300-400 hundred iterations:
      -- `E5108: Error executing lua Vim:E903: Process failed to start: too many open files: "/usr/bin/git"`
      features_disabled = { "lualine" },
    }
  },
  -- Feature table contains configuration for features faster.nvim will disable
  -- and enable according to rules defined in behaviours.
  -- Defined feature will be used by faster.nvim only if it is on (`on=true`).
  -- Defer will be used if some features need to be disabled after others.
  -- defer=false features will be disabled first and defer=true features last.
  features = {
    -- Neovim filetype plugin
    -- https://neovim.io/doc/user/filetype.html
    filetype = {
      on = true,
      defer = true,
    },
    -- Illuminate plugin
    -- https://github.com/RRethy/vim-illuminate
    illuminate = {
      on = true,
      defer = false,
    },
    -- Indent Blankline
    -- https://github.com/lukas-reineke/indent-blankline.nvim
    indent_blankline = {
      on = true,
      defer = false,
    },
    -- Neovim LSP
    -- https://neovim.io/doc/user/lsp.html
    lsp = {
      on = true,
      defer = false,
    },
    -- Lualine
    -- https://github.com/nvim-lualine/lualine.nvim
    lualine = {
      on = true,
      defer = false,
    },
    -- Neovim Pi_paren plugin
    -- https://neovim.io/doc/user/pi_paren.html
    matchparen = {
      on = true,
      defer = false,
    },
    -- Neovim syntax
    -- https://neovim.io/doc/user/syntax.html
    syntax = {
      on = true,
      defer = true,
    },
    -- Neovim treesitter
    -- https://neovim.io/doc/user/treesitter.html
    treesitter = {
      on = true,
      defer = false,
    },
    -- Neovim options that affect speed when big file is opened:
    -- swapfile, foldmethod, undolevels, undoreload, list
    vimopts = {
      on = true,
      defer = false,
    }
  }
}
```

## Full options for a behaviour

```lua
-- key is also a name this behaviour
test_behaviour = {
  -- Behaviour can be turned on or off. To turn on set to true, otherwise
  -- set to false
  on = true,
  -- Table which contains names of features that will be disabled when
  -- macro is executed. Feature names can be seen in features table.
  -- features_disabled can also be set to "all" and then all features that
  -- are on (on=true) are going to be disabled for this behaviour
  features_disabled = {
        "illuminate", "matchparen", "lsp", "treesitter", "indent_blankline",
        "vimopts", "syntax", "filetype" },
  -- init key takes a function that initializes the behaviour, for example sets
  -- autocommands based on some rule
  init = function() print('test_behaviour initialized') end,
  -- stop key takes a function that stops the behaviour, for example deletes
  -- autocommands and enable features if they were disabled by init
  stop = function() print('test_behaviour stopped') end,
},
```

## Full options for a feature

```lua
-- Feature table contains configuration for features faster.nvim will disable
-- and enable according to rules defined in behaviours.
-- Defined feature will be used by faster.nvim only if it is on (`on=true`).
-- Defer will be used if some features need to be disabled after others.
-- defer=false features will be disabled first and defer=true features last.
-- key is also a name of this feature
test_feature = {
  -- Feature will be used by faster.nvim only if on is set to true
  on = true,
  -- Features with defer=false will be disabled first
  defer = false,
  -- enable key takes a function that contains code that will enable a feature
  enable = function() print('this should enable a feature') end,
  -- disable key takes a function that contains code that will disable a feature
  disable = function() print('this should disable a feature') end,
  -- commands key takes a function that should be used to define commands that
  -- will enable/disable a feature in runtime
  commands = function()
    vim.api.nvim_create_user_command(
      'FasterEnableTestfeature', print('Test feature enabled'), {})
    vim.api.nvim_create_user_command(
      'FasterDisableTestfeature', print('Test feature disabled'), {})
  end,
},
```

# Commands

Although faster.nvim will disable and enable features based on the rules defined
in a behaviour it also offers convenience commands that can be used during
Neovim execution without restarting it.

Note that disabling and enabling features will work only if the feature has `on`
set to `true` in the configuration.

| Command                      | Description                                                                                                      |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| FasterDisableAllFeatures     | Disables all defined features that are on                                                                        |
| FasterDisableBigfile         | Disables bigfile behaviour                                                                                       |
| FasterDisableFastmacro       | Disables fastmacro behaviour                                                                                     |
| FasterDisableFiletype        | Disables filetype for the current buffer                                                                         |
| FasterDisableIlluminate      | Disables illuminate plugin for the current buffer                                                                |
| FasterDisableIndentblankline | Disables indent blank line plugin globally                                                                       |
| FasterDisableLsp             | Disables LSP client for currently opened buffers. Will not disable LSP for any new buffers opened.               |
| FasterDisableLualine         | Disables lualine plugin globally                                                                                 |
| FasterDisableMatchparen      | Disables parentheses matching globally, even for newly opened buffers                                            |
| FasterDisableSyntax          | Disabled default syntax highlighting for current buffer                                                          |
| FasterDisableTreesitter      | Disables treesitter for the current buffer                                                                       |
| FasterDisableVimopts         | Disable neovim options connected to slowness of Neovim when big files are opened but only for the current buffer |
| FasterEnableAllFeatures      | Enables all defined features that are on                                                                         |
| FasterEnableBigfile          | Enables bigfile behaviour                                                                                        |
| FasterEnableFastmacro        | Enables fastmacro behaviour                                                                                      |
| FasterEnableFiletype         | Enables filetype for the current buffer                                                                          |
| FasterEnableIlluminate       | Enables illuminate for the current buffer                                                                        |
| FasterEnableIndentblankline  | Enables indent blank line plugin globally                                                                        |
| FasterEnableLsp              | Enables LSP client for currently opened buffers                                                                  |
| FasterEnableLualine          | Enables lualine plugin globally                                                                                  |
| FasterEnableMatchparen       | Enables parentheses matching globally                                                                            |
| FasterEnableSyntax           | Enables default syntax highlighting for current buffer                                                           |
| FasterEnableTreesitter       | Enables treesitter for the current buffer                                                                        |
| FasterEnableVimopts          | Enables neovim options connected to slowness of Neovim whn bif files are opened but only for the current buffer  |
| FasterPrintConfig            | Prints faster.nvim configuration. Takes into account default configuration and user defined one and merges them. |
