local utils = require('faster.utils')

-- Features

vim.api.nvim_create_user_command('FasterEnableAllFeatures', utils.enable_all_features, {})
vim.api.nvim_create_user_command('FasterDisableAllFeatures', utils.disable_all_features, {})


-- Behaviours

vim.api.nvim_create_user_command('FasterEnableBigfile', utils.enable_big_file, {})
vim.api.nvim_create_user_command('FasterDisableBigfile', utils.disable_big_file, {})

vim.api.nvim_create_user_command('FasterEnableFastmacro', utils.enable_fast_macro, {})
vim.api.nvim_create_user_command('FasterDisableFastmacro', utils.disable_fast_macro, {})

-- Utilities

vim.api.nvim_create_user_command('FasterPrintConfig', utils.print_config, {})
