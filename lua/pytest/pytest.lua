local utils = require 'pytest.utils'
local config = require 'pytest.config'

local pytest = {}

---Build pytest command
---@param args table | string
---@return table
function pytest.build_command(args)
   if type(args) == "string" then
      args = { args }
   end

   local settings = config.get()
   local user_args = utils.validate_args(settings.add_args)
   local django_settings_module = settings.django.django_settings_module

   if django_settings_module ~= "" then
      table.insert(user_args, '--ds=' .. django_settings_module)
   end

   return utils.list_extend({ 'pytest', '-v' }, utils.list_extend(user_args, args))
end

function pytest.is_pytest_available()
   return vim.fn.executable("pytest") == 1
end

---Verify if pytest is available in local or docker according to the settings
---@param callback function
function pytest.is_pytest_django_available(callback)
   local docker_command = {}

   local settings = require('pytest.config').get()
   if settings.docker.enabled then
      docker_command = { "docker", "exec", settings.docker.container }
   end

   local command = utils.list_extend(docker_command, { 'pip', 'show', 'pytest-django' })
   local job = vim.system(command, { text = true }, function(stdout)
      if stdout.code == 0 then
         callback(true, 'pytest-django installed')
      else
         callback(false, 'pytest-django is not intalled. Installed it with `pip install pytest-django`')
      end
   end)

   return job
end

return pytest
