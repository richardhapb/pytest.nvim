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


local group = vim.api.nvim_create_augroup('DjangoTest', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
   group = group,
   pattern = 'python',
   callback = function()
      local bufnr = vim.api.nvim_get_current_buf()

      vim.api.nvim_buf_create_user_command(bufnr, 'DjangoTest', function()
         core.test_file()
      end, {
         nargs = 0,
      })

      vim.api.nvim_buf_create_user_command(bufnr, 'DjangoTestOutput', function()
         if core.status.last_stdout then
            core.show_last_stdout()
         else
            vim.notify('No output to show', vim.log.levels.INFO)
         end
      end, {
         nargs = 0,
      })

      vim.keymap.set('n', '<leader>T', '<CMD>DjangoTest<CR>', { buffer = bufnr, desc = 'Run Django tests' })
   end
})

return M

