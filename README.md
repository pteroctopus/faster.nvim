# Faster.nvim

Faster.nvim is a Neovim plugin inspired by
[bigfile.nvim](https://github.com/LunarVim/bigfile.nvim).

bigfile.nvim concept and code for handling of big files has been used as a
starting point for faster.nvim.

Some Neovim plugins and features can make Neovim slow when editing big files,
files with very long lines (minified JS/JSON/CSS), or while executing macros.
Faster.nvim will selectively disable some features when a big file is opened,
a long-line file is opened, or a macro is executed.

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

# Requirements

- Neovim 0.10+

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
      -- When true, fires a one-shot `vim.notify` (INFO level, title
      -- "faster.nvim") each time bigfile mode activates for a buffer,
      -- e.g. "faster.nvim active for big_log.txt (5.3 MiB)". Works with
      -- any notify plugin (nvim-notify, noice, mini.notify, snacks.notifier)
      -- and falls back to the built-in command-line message if no plugin
      -- replaces vim.notify. On launch-with-file-arg (e.g. `nvim big.log`),
      -- the message may still land in the cmdline if your notify plugin
      -- lazy-loads after BufReadPost. Set to false to silence.
      notify = true,
    },
    -- Long-line behaviour catches files that aren't large in total bytes but
    -- have very long lines (minified JS/JSON/CSS, single-line log files).
    -- These choke treesitter and syntax highlighting harder than typical big
    -- files, but bigfile detection misses them because their byte count is
    -- low. Detection uses filesize / line_count as a cheap heuristic.
    longline = {
      on = true,
      -- Same shape as bigfile.features_disabled. "all" is also accepted.
      features_disabled = {
        'illuminate', 'matchparen', 'lsp',
        'treesitter', 'indent_blankline',
        'vimopts', 'syntax', 'filetype',
      },
      -- File must be at least this size (MiB) to be considered. Default
      -- 10 KiB skips tiny files even if their line count is artificially low.
      filesize = 0.01,
      -- Trigger when filesize_bytes / line_count > avg_bytes_per_line.
      avg_bytes_per_line = 250,
      pattern = "*",
      -- Same extra_patterns shape as bigfile; both filesize and
      -- avg_bytes_per_line are overridable per pattern.
      --[[
      extra_patterns = {
        { pattern = "*.js",  avg_bytes_per_line = 200 },
        { pattern = "*.css", filesize = 0.05 },
      },
      ]]
      extra_patterns = {},
      -- Same vim.notify behaviour as bigfile (see notify above).
      notify = true,
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
      -- Specificaly:
      -- * lualine plugin is disabled when macros are executed because
      -- if a recursive macro opens a buffer on every iteration this error will
      -- happen after 300-400 hundred iterations:
      -- `E5108: Error executing lua Vim:E903: Process failed to start: too many open files: "/usr/bin/git"`
      -- * mini.clue plugin is disabled when macros are executed because it breaks execution of some macros
      features_disabled = { "lualine", "mini_clue" },
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
    },
    -- Mini.clue
    -- https://github.com/nvim-mini/mini.clue
    mini_clue = {
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
},
```

The feature is automatically reachable through the unified `:Faster` command
once registered (see Commands below):

```
:Faster enable test_feature
:Faster disable test_feature
```

# Commands

faster.nvim exposes a single user command, `:Faster`, with subcommands for
runtime control. Tab-completion suggests valid actions and targets at every
position.

```
:Faster <action> [target]
```

Note that enabling/disabling a feature only takes effect if the feature has
`on = true` in the configuration.

## Actions

| Action  | Argument                  | What it does                                                                |
| ------- | ------------------------- | --------------------------------------------------------------------------- |
| enable  | `<behaviour>` / `<feature>` / `features` / `behaviours` / `all` | Re-enables a behaviour or feature. Group targets (`features`, `behaviours`, `all`) act on every member at once. Group `enable` only re-arms behaviours, it does NOT re-process the current buffer (so just-enabled features stay enabled). |
| disable | `<behaviour>` / `<feature>` / `features` / `behaviours` / `all` | Disables a behaviour or feature. Group targets disable every member at once. |
| config  | —                         | Prints the merged faster.nvim configuration (defaults + user overrides)      |
| status  | —                         | Prints behaviour/feature `on` (config) plus runtime `active` state for the current buffer |
| help    | —                         | Prints usage and the list of valid targets                                   |

## Targets

**Behaviours:** `bigfile`, `longline`, `fastmacro`

**Features:** `illuminate`, `matchparen`, `lsp`, `treesitter`, `indent_blankline`, `vimopts`, `syntax`, `filetype`, `lualine`, `mini_clue`

**Group targets:**
- `features` — every feature with `on=true`
- `behaviours` — every behaviour (init/stop all at once)
- `all` — every behaviour AND every feature

## Examples

```
:Faster enable bigfile          " re-arm the bigfile behaviour after disabling it
:Faster disable bigfile         " stop bigfile from triggering on file open
:Faster disable features        " disable every feature whose on=true
:Faster disable behaviours      " stop bigfile + longline + fastmacro
:Faster disable all             " disable every behaviour AND every feature
:Faster enable all              " re-arm everything
:Faster enable treesitter       " re-enable treesitter for the current buffer
:Faster disable mini_clue       " disable mini.clue triggers globally
:Faster status                  " quick view of config + runtime state
:Faster config                  " print the merged config
```

## `:Faster status`

Two columns:

- `on` — the static config flag (whether faster.nvim is configured to control this).
- `active` — the runtime state probed against the current buffer:
  - For **behaviours** (`bigfile`, `longline`): `true` once the behaviour has triggered for this buffer (criteria matched and features were disabled). `fastmacro` reports whether the `@` keymap interception is installed (global, not per-buffer).
  - For **features**: whether the feature is currently enabled in this buffer, queried via plugin-specific probes (e.g. `vim.treesitter.highlighter.active[bufnr]`, `&syntax`, LSP client count, IBL config).
  - `?` means the runtime state can't be reliably probed. Currently only `illuminate` — vim-illuminate's public `is_paused()` only reports a global flag, not per-buffer state, so we can't tell whether the active buffer is paused. (`lualine` and `mini_clue` track state through internal flags set by `:Faster enable/disable`, so they report a real true/false.)

Example on a 4 MiB markdown file (bigfile-triggered, longline criteria not met):

```
faster.nvim status (buffer 1: 3Mfile.md)

  behaviours:               on        active
    bigfile                   true      true
    fastmacro                 true      true
    longline                  true      false

  features:                 on        active
    filetype                  true      false
    illuminate                true      ?
    indent_blankline          true      false
    lsp                       true      false
    lualine                   true      true
    matchparen                true      false
    mini_clue                 true      true
    syntax                    true      false
    treesitter                true      false
    vimopts                   true      false
```

`lualine` and `mini_clue` `active=true` here is correct — bigfile's default `features_disabled` doesn't include them (they're in `fastmacro`'s list).
