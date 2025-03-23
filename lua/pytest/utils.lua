local utils = {}


---Extend a list with another list, from left to right
---@param list table
---@param extension table
---@return table
function utils.list_extend(list, extension)
   local new_list = {}
   for _, value in ipairs(list) do
      table.insert(new_list, value)
   end
   for _, value in ipairs(extension) do
      table.insert(new_list, value)
   end
   return new_list
end

function utils.scape_special_chars(str)
   for _, char in ipairs({ '(', ')', '[', ']', '.', '*', '+', '-', '?', '^', '$' }) do
      str = str:gsub('%' .. char, '%%' .. char)
   end

   return str
end

---Verify if pytest-django is available in local or docker according to the settings
---@param callback function
function utils.is_pytest_django_available(callback)
   local docker_command = {}
   local settings = require('pytest.config').get()
   if settings.docker.enabled then
      docker_command = { "docker", "exec", settings.docker.container }
   end
   local command = utils.list_extend(docker_command, { "pytest", "-V", "-V" })

   local job = vim.system(command, { text = true }, function(result)
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

   return job
end

---Verify if the container is running according to the settings
---@param callback function
function utils.is_container_running(callback)
   local settings = require('pytest.config').get()
   local command = { "docker", "ps", "--format", "{{.Names}}" }
   local container = settings.docker.container
   local job = vim.system(command, { text = true }, function(result)
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
         callback(false, "Container is not running")
      else
         callback(false, "Error executing docker ps: " .. result.stderr)
      end
   end)

   return job
end

---Verify if the dependencies are available
function utils.verify_dependencies()
   local settings = require('pytest.config').get()
   if settings.docker.enabled then
      utils.is_container_running(function(container_runnings, message)
         if not container_runnings then
            vim.print(message)
            settings.docker.enabled = false
         end
      end):wait()
   end

   utils.is_pytest_django_available(function(pytest_available, _)
      if not pytest_available then
         local docker_command = {}
         if settings.docker.enabled then
            docker_command = { 'docker', 'exec', settings.docker.container }
         end

         local command = utils.list_extend(docker_command, { 'pip', 'install', 'pytest', 'pytest-django' })
         vim.system(command, { text = true }, function(stdout)
            if stdout.code == 0 then
               vim.print('pytest-django installed')
            else
               vim.print('Error installing pytest-django: ' .. stdout.stderr)
            end
         end)
      end
   end)
end

---Get the git root directory
---@return string
function utils.get_git_root()
   local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
   return git_root
end

---Search for the docker-compose file in the current directory
---@param path? string
---@return string
function utils.find_docker_compose(path)
   local cwd = path or vim.fn.getcwd()
   local git_root = utils.get_git_root()
   local settings = require('pytest.config').get()
   local docker_compose_name = settings.docker.compose_file_name or 'docker-compose.yml'

   for _, dir in ipairs({ cwd, git_root }) do
      local docker_compose = vim.fn.findfile(docker_compose_name, cwd .. ';')

      if docker_compose ~= '' then
         return dir
      end
   end

   return ''
end

---Obtain the line number of the service in the docker-compose file
---@param path? string
---@return number
function utils.get_docker_compose_service_line(path)
   local docker_compose_path = ''
   local settings = require('pytest.config').get()

   if not path or path == '' then
      docker_compose_path = utils.find_docker_compose()
   else
      docker_compose_path = path
   end

   local lineno = -1
   if docker_compose_path == '' then
      return lineno
   end

   local docker_compose_name = settings.docker.compose_file_name or 'docker-compose.yml'

   local docker_compose_file = io.open(docker_compose_path .. '/' .. docker_compose_name, 'r')
   if not docker_compose_file then
      return lineno
   end

   local service = settings.docker.docker_compose_service

   if not service or service == '' then
      return lineno
   end

   for line in docker_compose_file:lines() do
      lineno = lineno + 1
      if line:match('^%s*' .. service .. ':') then
         docker_compose_file:close()
         return lineno
      end
   end

   docker_compose_file:close()
   return -1
end

---Get the volume path from the docker-compose file
---@param path? string
---@return string
function utils.get_docker_compose_volume(path)
   local docker_compose_path = ''
   local settings = require('pytest.config').get()

   if not path or path == '' then
      docker_compose_path = utils.find_docker_compose()
   else
      docker_compose_path = path
   end


   local docker_compose_name = settings.docker.compose_file_name or 'docker-compose.yml'

   local docker_compose_file = io.open(docker_compose_path .. '/' .. docker_compose_name, 'r')
   if not docker_compose_file then
      return ''
   end

   local service_line = utils.get_docker_compose_service_line(docker_compose_path)
   local volume = ''

   if service_line == -1 then
      return volume
   end

   local path_prefix = settings.docker.local_path_prefix or ''

   if path_prefix and path_prefix ~= '' then
      path_prefix = '/' .. path_prefix
   end

   local volume_match = false
   for line in docker_compose_file:lines() do
      if service_line < 0 then
         if line:match('^%s*volumes:') then
            if volume_match then
               docker_compose_file:close()
               return volume
            end

            volume_match = true
         end
      else
         service_line = service_line - 1
      end

      if volume_match then
         if line:match('^%s*-%s+%.' .. path_prefix .. '/:(.*)') then
            volume = line:match('^%s*-%s+%.' .. path_prefix .. '/:(.*)')
            break
         end
      end
   end

   docker_compose_file:close()
   return volume
end

---Get the buffer from the filepath
---@param filepath string
---@return nil | number
function utils.get_buffer_from_filepath(filepath)
   local buffer = vim.fn.bufnr(filepath, true)
   if buffer == -1 then
      return nil
   end
   return buffer
end

return utils
