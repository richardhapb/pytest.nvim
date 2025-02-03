local settings = require('pytest.config').settings

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


---Verify if pytest-django is available in local or docker according to the settings
---@param callback function
function utils.is_pytest_django_available(callback)
   local docker_command = {}
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
         callback(false, "Container not running")
      else
         callback(false, "Error executing docker ps: " .. result.stderr)
      end
   end)

   return job
end


---Verify if the dependencies are available
function utils.verify_dependencies()
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

return utils

