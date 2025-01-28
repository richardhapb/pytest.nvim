local ts_utils = require('nvim-treesitter.ts_utils')

local M = {}

local ns = vim.api.nvim_create_namespace('django_test')
local status = {
   last_stdout = nil,
   lines = {},
   dependencies_verified = false,
   working = false,
}

M.settings = {
   docker = {
      enabled = true,
      container = 'ddirt-web-1',
      docker_path = '/usr/src/app',
   },
}

M.setup = function(config)
   M.settings = vim.tbl_deep_extend('force', M.settings, config)
end

local function list_extend(list, extension)
   local new_list = {}
   for _, value in ipairs(list) do
      table.insert(new_list, value)
   end
   for _, value in ipairs(extension) do
      table.insert(new_list, value)
   end
   return new_list
end

local function is_pytest_django_available(callback)
   local docker_command = {}
   if M.settings.docker.enabled then
      docker_command = { "docker", "exec", M.settings.docker.container }
   end
   local command = list_extend(docker_command, { "pytest", "-V", "-V" })
   vim.system(command, { text = true }, function(result)
      if result.code == 0 then
         local output = result.stdout
         if not output then
            callback(false, "Error obtaining pytest plugins")
            return
         end

         for line in output:gmatch("[^\r\n]+") do
            if line:match("pytest%-django") then
               callback(true, "pytest-django available")
               return
            end
         end
         callback(false, "pytest-django not availabe")
      else
         callback(false, "Error executing pytest: " .. result.stderr)
      end
   end)
end

local function is_container_running(callback)
   local command = { "docker", "ps", "--format", "{{.Names}}" }
   local container = M.settings.docker.container
   vim.system(command, { text = true }, function(result)
      if result.code == 0 then
         local output = result.stdout
         if not output then
            callback(false, "Error obtaining docker containers")
            return
         end

         for line in output:gmatch("[^\r\n]+") do
            if line == container then
               callback(true, "Container running")
               return
            end
         end
         callback(false, "Container not running")
      else
         callback(false, "Error executing docker ps: " .. result.stderr)
      end
   end):wait()
end

local function get_error_detail(stdout, index)
   local detail = { line = 0, error = '' }

   vim.print(index)

   local count = 1
   for _, line in ipairs(stdout) do
      local error = line:match('E   (.*)')
      if error and detail.error == '' then
         if count == index then
            detail.error = error
         else
            count = count + 1
         end
      end

      local linenr = line:match('.*%.py:(%d+)')
      if linenr and detail.line == 0 and detail.error ~= '' then
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

local function get_tests_lines(stdout, bufnr)
   local tests = {}

   for _, line in ipairs(stdout) do
      if line:match('.*%.py::.*::.*') then
         table.insert(tests, line)
      end
   end

   local parser = vim.treesitter.get_parser(bufnr, "python")
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

M.test = function()
   if status.working then
      vim.notify('Tests are already running', vim.log.levels.INFO)
      return
   end
   local current_dir = vim.fn.getcwd()
   local current_file = vim.fn.expand('%:p')

   local bufnr = vim.api.nvim_get_current_buf()

   local docker_command = {}

   if M.settings.docker.enabled then
      local docker_path = M.settings.docker.docker_path
      local relative_file = current_file:match(current_dir .. '/(.*)')
      local docker_file_path = docker_path .. '/' .. relative_file
      local container = M.settings.docker.container

      docker_command = { 'docker', 'exec', container }

      current_file = docker_file_path
   end

   local command = list_extend(docker_command, { 'pytest', '-v', current_file })

   vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
   vim.diagnostic.reset(ns, bufnr)

   status.working = true

   vim.fn.jobstart(
      command, {
         stdout_buffered = true,
         on_stdout = function(_, stdout)
            if stdout then
               status.lines = get_tests_lines(stdout, bufnr)
               for _, line in ipairs(status.lines) do
                  local lineno, stat = next(line)
                  local text = stat == 'passed' and '\t✅' or '\t❌'
                  vim.api.nvim_buf_set_extmark(bufnr, ns, lineno, 0, { virt_text = { { text } } })
               end
               status.last_stdout = stdout
            end
         end,
         on_exit = function(_, _)
            local failed = {}
            local i = 1
            for _, line in ipairs(status.lines) do
               local _, outcome = next(line)

               if outcome == 'failed' then
                  local error = get_error_detail(status.last_stdout, i)

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

            status.working = false
         end
      })
end

M.show_last_stdout = function()
   if status.last_stdout then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, status.last_stdout)
      vim.cmd.split()
      vim.api.nvim_set_current_buf(bufnr)
   end
end

local group = vim.api.nvim_create_augroup('DjangoTest', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
   group = group,
   pattern = 'python',
   callback = function()
      if not status.dependencies_verified then
         if M.settings.docker.enabled then
            is_container_running(function(container_runnings, message)
               if not container_runnings then
                  vim.print(message)
                  M.settings.docker.enabled = false
               end
            end)
         end

         is_pytest_django_available(function(pytest_available, _)
            if not pytest_available then
               local docker_command = {}
               if M.settings.docker.enabled then
                  docker_command = { 'docker', 'exec', M.settings.docker.container }
               end

               local command = list_extend(docker_command, { 'pip', 'install', 'pytest', 'pytest-django' })
               vim.system(command, { text = true }, function(stdout)
                  if stdout.code == 0 then
                     vim.print('pytest-django installed')
                  else
                     vim.print('Error installing pytest-django: ' .. stdout.stderr)
                  end
               end)
            end

            status.dependencies_verified = true
         end)
      end

      local bufnr = vim.api.nvim_get_current_buf()

      vim.api.nvim_buf_create_user_command(bufnr, 'DjangoTest', function()
         M.test()
      end, {
         nargs = 0,
      })

      vim.api.nvim_buf_create_user_command(bufnr, 'DjangoTestOutput', function()
         if status.last_stdout then
            M.show_last_stdout()
         else
            vim.notify('No output to show', vim.log.levels.INFO)
         end
      end, {
         nargs = 0,
      })

      vim.keymap.set('n', '<leader>T', '<CMD>DjangoTest<CR>', { buffer = bufnr, desc = 'Run Django tests' })
   end
})

