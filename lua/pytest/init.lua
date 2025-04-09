local config = require('pytest.config')
local runner = require('pytest.runner')
local utils = require('pytest.utils')
local test = require('pytest.test')

local M = {}

---Main settings for pytest.nvim
---@param opts? PytestConfig
M.setup = function(opts)
   opts = opts or {}
   if opts then
      config.opts = vim.tbl_deep_extend("force", config.defaults, opts)
   end
   M.settings = config.get(opts)

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
            config.opts = vim.tbl_deep_extend("force", config.opts, { docker = { enabled = true } })
         end, {
            nargs = 0,
         })

         vim.api.nvim_buf_create_user_command(bufnr, 'PytestDisableDocker', function()
            config.opts = vim.tbl_deep_extend("force", config.opts, { docker = { enabled = false } })
         end, {
            nargs = 0,
         })

         M.settings.keymaps_callback(bufnr)
      end
   })
end

-- API functions
M.test_file = runner.test_file

return M
