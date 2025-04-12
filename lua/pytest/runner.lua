local utils = require 'pytest.utils'
local config = require 'pytest.config'
local docker = require 'pytest.docker'
local pytest = require 'pytest.pytest'
local test = require 'pytest.test'

---Main function to run the tests for the current file
---@param file? string
---@param opts? PytestConfig
---@param callback? function
local function test_file(file, opts, callback)
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
         test.run(new_test, callback)
      end
      return
   end

   local command = pytest.build_command(current_file)
   new_test.command = command
   test.run(new_test, callback)
end


---Main function to run the tests for the current file
---@param element? string
---@param opts? PytestConfig
---@param callback? function
local function test_element(element, opts, callback)
   element = element or vim.fn.expand('%:p')
   local new_test = {}

   test.set_state(
      { filenames = {}, bufnr = nil }
   )

   local settings = config.get(opts)

   if settings.docker.enabled then
      local docker_command = docker.build_docker_command(settings, { element })
      if #docker_command > 0 then
         new_test.command = docker_command
         test.run(new_test, callback)
      end
      return
   end

   local command = pytest.build_command(element)
   new_test.command = command
   test.run(new_test, callback)
end

return {
   test_file = test_file,
   test_element = test_element
}
