local config = require('pytest.config')
local runner = require('pytest.runner')
local utils = require('pytest.utils')
local test = require('pytest.test')

local _settings = {}

---Main settings for pytest.nvim
---@param opts? PytestConfig
local setup = function(opts)
   opts = opts or {}
   if opts then
      config.update_hard_opts(opts)
   end
   _settings = config.get(opts)

   local group = vim.api.nvim_create_augroup('Pytest', { clear = true })
   local attach_id = nil

   vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'python',
      callback = function()
         local bufnr = vim.api.nvim_get_current_buf()

         vim.api.nvim_buf_create_user_command(bufnr, 'Pytest', function()
            runner.test_file()
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestOutput', function()
            if test.get_last_output() then
               test.show_last_output()
            else
               utils.info('No output to show')
            end
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestAttach', function()
            local file = vim.fn.expand('%:p')
            attach_id = vim.api.nvim_create_autocmd('BufWritePost', {
               group = group,
               pattern = "*.py",
               callback = function()
                  runner.test_file(file)
               end,
            })
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestDetach', function()
            if attach_id then
               vim.api.nvim_del_autocmd(attach_id)
               attach_id = nil
            end
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestEnableDocker', function()
            config.update_hard_opts({ docker = { enabled = true } })
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestDisableDocker', function()
            config.update_hard_opts({ docker = { enabled = false } })
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestUI', function()
            require 'pytest.ui.buffer'.load_project()
         end, {
            nargs = 0,
         })

         _settings.keymaps_callback(bufnr)
      end
   })
end

return {
   test_file = runner.test_file,
   setup = setup,
   settings = _settings,
}
