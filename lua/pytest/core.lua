local config = require 'pytest.config'
local utils = require 'pytest.utils'
local docker = require 'pytest.docker'
local pytest = require 'pytest.pytest'


local core = {}

local ns = vim.api.nvim_create_namespace('pytest_test')

core.state = {
   last_output = nil,
   last_job_id = nil,
   lines = {},
   dependencies_verified = false,
   working = false,
   filename = nil,
   job_id = nil,
   current_bufnr = nil,
   has_stdout = false
}

---Clear any results and reset state
---@param bufnr? number
local function clear_state(bufnr)
   if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
      bufnr = core.state.current_bufnr or 0
   end

   vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
   vim.diagnostic.reset(ns, bufnr)

   core.state.last_job_id = core.state.job_id
   core.state.current_bufnr = bufnr

   core.state.working = false
   core.state.job_id = nil
   core.state.lines = {}
   core.state.filename = nil
   core.state.has_stdout = false
end

---Get the line and error message of the failed test for the current file
---@param stdout string[]
---@param index number
---@return table
function core._get_error_detail(stdout, index)
   local detail = { line = -1, error = '' }

   if not core.state.filename then
      core.state.filename = vim.fn.expand('%:t')
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

      local linenr = line:match(core.state.filename:gsub('%.', '%%.') .. ':(%d+)')
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
      utils.error("Parser not found")
      return
   end
   local tree = parser:parse()[1]
   local root = tree:root()

   local parsed_query = vim.treesitter.query.get("python", 'custom')
   if not parsed_query then
      utils.error("Query not found")
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

local function update_marks(stdout, bufnr)
   core.state.lines = get_tests_lines(stdout, bufnr)
   for _, line in ipairs(core.state.lines) do
      local lineno, stat = next(line)
      if not lineno then
         return
      end
      local text = stat == 'passed' and '\t✅' or ''
      text = stat == 'failed' and '\t❌' or text
      vim.api.nvim_buf_set_extmark(bufnr, ns, lineno, 0, { virt_text = { { text } } })
   end
   core.state.last_output = stdout
end


---Main function to run the tests for the current file
---Test file with pytest
---@param file? string
---@param opts? PytestConfig
function core.test_file(file, opts)
   local current_file = file or vim.fn.expand('%:p')
   local bufnr = utils.get_buffer_from_filepath(current_file) or vim.api.nvim_get_current_buf()

   if core.state.working then
      core.cancel_test()
   end

   clear_state(bufnr)

   core.state.working = true

   config.get(opts)

   local settings = config.get()
   core.state.filename = current_file:match("[^/]+$")

   if settings.docker.enabled then
      local docker_command = docker.build_docker_command(settings, { current_file })
      if #docker_command > 0 then
         core.run_test(docker_command)
      end
      return
   end

   local command = pytest.build_command(current_file)
   core.run_test(command)
end

function core.run_test(command)
   -- Only update marks in current buffer
   local ok_dep, msg = utils.verify_dependencies()
   if not ok_dep then
      utils.error(msg)
      return
   end

   local bufnr = core.state.current_bufnr or vim.api.nvim_get_current_buf()
   utils.info("Running tests...")

   core.state.job_id = vim.fn.jobstart(
      command, {
         stdout_buffered = true,
         stderr_buffered = true,
         on_stdout = function(_, stdout)
            if stdout then
               core.state.has_stdout = true
               update_marks(stdout, bufnr)
            end
         end,
         on_stderr = function(_, stderr)
            if stderr and not core.state.has_stdout then
               core.state.last_output = stderr
            end
         end,
         on_exit = function(_, exit_code)
            local failed = {}
            local i = 1
            for _, line in ipairs(core.state.lines) do
               local lineno, outcome = next(line)

               if outcome == 'failed' then
                  local error = core._get_error_detail(core.state.last_output, i)
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
               core.state.job_id = nil
            end

            local message = exit_code == 0 and 'Tests passed 👌' or 'Tests failed 😢'
            utils.info(message)
            vim.diagnostic.set(ns, bufnr, failed, {})
            core.state.working = false
            core.state.job_id = nil

            -- Show the output if fails
            if exit_code == 1 and config.get().open_output_onfail then
               core.show_last_output()
            end
         end
      })
end

---Display the last output (stdout or stderr) in a new buffer
core.show_last_output = function()
   if core.state.last_output then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, core.state.last_output)
      vim.cmd.split()
      vim.api.nvim_set_current_buf(bufnr)
   end
end

core.cancel_test = function()
   if core.state.working and core.state.job_id then
      local ok = pcall(vim.fn.jobstop, core.state.job_id)
      if ok then
         utils.info("Pytest job cancelled, running the new test")
      end

      clear_state()
   end
end

return core
