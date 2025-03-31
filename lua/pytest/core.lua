local config = require('pytest.config')
local utils = require('pytest.utils')


local core = {}

local ns = vim.api.nvim_create_namespace('pytest_test')
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
   local detail = { line = -1, error = '' }

   if not core.status.filename then
      core.status.filename = vim.fn.expand('%:t')
   end

   local count = 1
   for _, line in ipairs(stdout) do
      local error = line:match('^E%s+(.*)')
      if error and detail.error == '' then
         if count == index then
            detail.error = error
         else
            count = count + 1
         end
      end

      local linenr = line:match(core.status.filename:gsub('%.', '%%.') .. ':(%d+)')
      if linenr and detail.line == -1 and detail.error ~= '' then
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
   -- TODO: Refactor this function
   local tests = {}

   for _, line in ipairs(stdout) do
      if line:match('.*%.py::.*::.*') then
         table.insert(tests, line)
      end
   end

   if #tests == 0 then
      for _, line in ipairs(stdout) do
         if line:match('.*%.py::.*') then
            table.insert(tests, line)
         end
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
      -- TODO: Extract this to a function
      local class_name, function_name, stat = test:match('.*%.py::(.*)::(.-)%s+(.*)%s+%[')
      if not function_name then
         class_name, function_name, stat = test:match('.*%.py::(.*)::(.-)%s+(.*)%s+%[?')
         if not function_name then
            function_name, stat = test:match('.*%.py::(.-)%s+([^%s]+)%s')
            class_name = ''
         end
      end

      local active_class = ''
      if function_name then
         for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
            local capture_name = parsed_query.captures[id]
            if capture_name == 'class' then
               local range = { node:range() }
               local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1]
               if line:match(class_name) then
                  active_class = class_name
               end
            end

            if capture_name == 'function' then
               local range = { node:range() }
               local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1]
               if line:match(function_name) and active_class == class_name then
                  table.insert(lines, { [range[1]] = string.lower(stat) })
                  active_class = ''
               end
            end
         end
      end
   end
   return lines
end


---Main function to run the tests for the current file
---Test file with pytest
---@param file? string
---@param opts? PytestConfig
core.test_file = function(file, opts)
   if core.status.working then
      vim.print('Tests are already running')
      return
   end

   config.update(opts)

   local settings = config.get()
   local current_file = file or vim.fn.expand('%:p')
   local bufnr = utils.get_buffer_from_filepath(current_file) or vim.api.nvim_get_current_buf()

   local docker_command = {}

   core.status.filename = current_file:match("[^/]+$")

   if settings.docker.enabled then
      local docker_compose_path = utils.find_docker_compose()
      local docker_path = settings.docker.docker_path or ''

      utils.is_container_running(function(running, message)
         if not running then
            vim.print(message)
            return
         end
         if settings.docker.enable_docker_compose then
            local volume = utils.get_docker_compose_volume(docker_compose_path)
            if volume == '' then
               vim.print('Docker compose / volume not found')
               return
            end
            settings.docker.docker_path = volume
            docker_path = volume
         end

         local path_prefix = settings.docker.local_path_prefix
         if path_prefix and path_prefix ~= '' then
            path_prefix = '/' .. path_prefix
         end

         local relative_file = current_file:match(utils.scape_special_chars(docker_compose_path) ..
            utils.scape_special_chars(path_prefix) .. '/(.*)')

         local docker_file_path = docker_path .. '/' .. relative_file
         local container = settings.docker.container

         docker_command = { 'docker', 'exec', container }

         current_file = docker_file_path
      end):wait()

      if #docker_command == 0 then
         return
      end
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
                  if not lineno then
                     return
                  end
                  local text = stat == 'passed' and '\t✅' or ''
                  text = stat == 'failed' and '\t❌' or text
                  vim.api.nvim_buf_set_extmark(bufnr, ns, lineno, 0, { virt_text = { { text } } })
               end
               core.status.last_stdout = stdout
            end
         end,
         on_exit = function(_, exit_code)
            local failed = {}
            local i = 1
            for _, line in ipairs(core.status.lines) do
               local lineno, outcome = next(line)

               if outcome == 'failed' then
                  local error = core._get_error_detail(core.status.last_stdout, i)
                  local ok, col = pcall(vim.api.nvim_buf_get_lines, bufnr, error.line, error.line + 1, false)

                  -- TODO: Obtain range with treesitter
                  if ok and #col > 0 then
                     error.col = string.find(col[1], '[^%s]+') - 1
                     error.end_col = string.len(col[1])
                  else
                     error.col = 0
                     error.end_col = 0
                  end

                  if error.line == -1 then
                     error.line = lineno
                  end

                  table.insert(failed, {
                     bufnr = bufnr,
                     lnum = error.line,
                     end_lnum = error.line,
                     col = error.col,
                     end_col = error.end_col,
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

            local message = exit_code == 0 and 'Tests passed 👌' or 'Tests failed 😢'
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
