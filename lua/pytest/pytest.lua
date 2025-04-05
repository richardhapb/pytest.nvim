local utils = require'pytest.utils'

local pytest = {}

---Build pytest command
---@param args table | string
---@return table
function pytest.build_command(args)
   if type(args) == "string" then
      args = { args }
   end
   return utils.list_extend({ 'pytest', '-v' }, args)
end

---Verify if pytest is available in local or docker according to the settings
---@param callback function
function pytest.is_pytest_django_available(callback)
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

         -- TODO: load django option from config
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

return pytest

