local utils = require 'pytest.utils'
local config = require 'pytest.config'
local docker = require 'pytest.docker'
local pytest = require 'pytest.pytest'
local test = require 'pytest.test'

local M = {}

---Main function to run the tests for the current file
---Test file with pytest
---@param file? string
---@param opts? PytestConfig
function M.test_file(file, opts)
   local current_file = file or vim.fn.expand('%:p')
   local new_test = {}
   local filenames = { current_file:match("[^/]+$") }
   local bufnr = utils.get_buffer_from_filepath(current_file) or vim.api.nvim_get_current_buf()

   test.set_state(
      { filenames = filenames, bufnr = bufnr }
   )

   local settings = config.get(opts)

   if settings.docker.enabled then
      local docker_command = docker.build_docker_command(settings, { current_file })
      if #docker_command > 0 then
         new_test.command = docker_command
         test.run(new_test)
      end
      return
   end

   local command = pytest.build_command(current_file)
   new_test.command = command
   test.run(new_test)
end

return M
