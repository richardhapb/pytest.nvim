local config = require('pytest.config')
local core = require('pytest.core')

local M = {}


---Main settings for pytest.nvim
---@param opts? table
M.setup = function(opts)
   opts = opts or {}
   config.settings = vim.tbl_deep_extend('force', config.settings, opts)
end


-- API functions
M.test_file = core.test_file


local group = vim.api.nvim_create_augroup('Pytest', { clear = true })
local attach_id = nil

vim.api.nvim_create_autocmd('FileType', {
   group = group,
   pattern = 'python',
   callback = function()
      local bufnr = vim.api.nvim_get_current_buf()

      vim.api.nvim_buf_create_user_command(bufnr, 'Pytest', function()
         core.test_file()
      end, {
         nargs = 0,
      })

      vim.api.nvim_buf_create_user_command(bufnr, 'PytestOutput', function()
         if core.status.last_stdout then
            core.show_last_stdout()
         else
            vim.notify('No output to show', vim.log.levels.INFO)
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
               core.test_file(file)
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


      vim.keymap.set('n', '<leader>T', '<CMD>Pytest<CR>', { buffer = bufnr, desc = 'Run Pytest' })
   end
})

return M
