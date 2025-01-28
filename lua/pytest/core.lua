local config = require('pytest.config')
local utils = require('pytest.utils')

local settings = config.settings

local core = {}

local ns = vim.api.nvim_create_namespace('django_test')
core.status = {
   last_stdout = nil,
   lines = {},
   dependencies_verified = false,
   working = false,
   filename = nil
}


---Get the line and error message of the failed test for the current file
---@param stdout string[]
---@param index number
---@return table
function core._get_error_detail(stdout, index)
   local detail = { line = 0, error = '' }

   if not core.status.filename then
      core.status.filename = vim.fn.expand('%:t')
   end

   local count = 1
   for _, line in ipairs(stdout) do
      local error = line:match('E%s+(.*)')
      if error and detail.error == '' then
         if count == index then
            detail.error = error
         else
            count = count + 1
         end
      end

      local linenr = line:match(core.status.filename:gsub('%.', '%%.') .. ':(%d+)')
      if linenr and detail.line == 0 then
         if count == index then
            detail.line = tonumber(linenr) - 1
         end
      end

      if detail.error ~= '' and detail.line > 0 then
         break
      end
   end

   return detail
end


---Get the lines of test functions for the current file
---@param stdout string[]
---@param bufnr number
---@return table?
local function get_tests_lines(stdout, bufnr)
   local tests = {}

   for _, line in ipairs(stdout) do
      if line:match('.*%.py::.*::.*') then
         table.insert(tests, line)
      end
   end

   local parser = vim.treesitter.get_parser(bufnr, "python")
   if not parser then
      print("Parser not found")
      return
   end
   local tree = parser:parse()[1]
   local root = tree:root()

   local parsed_query = vim.treesitter.query.get("python", 'custom')
   if not parsed_query then
      print("Query not found")
      return
   end

   local lines = {}

   for _, test in ipairs(tests) do
      local function_name, stat = test:match('.*%.py::.*::(.-)%s+(.*)%s+%[')

      if function_name then
         for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
            local capture_name = parsed_query.captures[id]
            if capture_name == 'function' then
               local range = { node:range() }
               local line = vim.fn.getline(range[1] + 1)
               if line:match(function_name) then
                  table.insert(lines, { [range[1]] = string.lower(stat) })
               end
            end
         end
      end
   end
   return lines
end


---Main function to run the tests for the current file
core.test_file = function()
   if core.status.working then
      vim.notify('Tests are already running', vim.log.levels.INFO)
      return
   end
   local current_dir = vim.fn.getcwd()
   local current_file = vim.fn.expand('%:p')

   local bufnr = vim.api.nvim_get_current_buf()

   local docker_command = {}

   core.status.filename = vim.fn.expand('%:t')

   if settings.docker.enabled then
      local docker_path = settings.docker.docker_path
      local relative_file = current_file:match(current_dir .. '/(.*)')
      local docker_file_path = docker_path .. '/' .. relative_file
      local container = settings.docker.container

      docker_command = { 'docker', 'exec', container }

      current_file = docker_file_path
   end

   local command = utils.list_extend(docker_command, { 'pytest', '-v', current_file })

   vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
   vim.diagnostic.reset(ns, bufnr)

   core.status.working = true

   vim.fn.jobstart(
      command, {
         stdout_buffered = true,
         on_stdout = function(_, stdout)
            if stdout then
               core.status.lines = get_tests_lines(stdout, bufnr)
               for _, line in ipairs(core.status.lines) do
                  local lineno, stat = next(line)
                  local text = stat == 'passed' and '\t✅' or '\t❌'
                  vim.api.nvim_buf_set_extmark(bufnr, ns, lineno, 0, { virt_text = { { text } } })
               end
               core.status.last_stdout = stdout
            end
         end,
         on_exit = function(_, _)
            local failed = {}
            local i = 1
            for _, line in ipairs(core.status.lines) do
               local _, outcome = next(line)

               if outcome == 'failed' then
                  local error = core._get_error_detail(core.status.last_stdout, i)

                  table.insert(failed, {
                     bufnr = bufnr,
                     lnum = error.line,
                     col = 0,
                     text = 'Test failed',
                     severity = vim.diagnostic.severity.ERROR,
                     message = 'Test failed\n' .. error.error,
                     source = 'Django test',
                     code = 'TestError',
                     namespace = ns,
                  })
                  i = i + 1
               end
            end

            local message = #failed > 0 and 'Tests failed' or 'Tests passed'
            vim.notify(message, vim.log.levels.INFO)
            vim.diagnostic.set(ns, bufnr, failed, {})

            core.status.working = false
         end
      })
end


---Display the last stdout output in a new buffer
core.show_last_stdout = function()
   if core.status.last_stdout then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, core.status.last_stdout)
      vim.cmd.split()
      vim.api.nvim_set_current_buf(bufnr)
   end
end

return core

