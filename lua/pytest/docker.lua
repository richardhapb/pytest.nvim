local utils = require 'pytest.utils'
local pytest = require 'pytest.pytest'

local docker = {}


---Verify if the container is running
---@param callback function
function docker.is_container_running(callback)
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

---Search for the docker-compose file in the current directory
---@param path? string
---@return string
function docker.find_docker_compose(path)
   local cwd = path or utils.safe_getcwd()
   local git_root = utils.get_git_root()

   local settings = require('pytest.config').get()
   local docker_compose_name = settings.docker.docker_compose_file or 'docker-compose.yml'
   if type(docker_compose_name) == "function" then
      docker_compose_name = docker_compose_name()
   end

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
function docker.get_docker_compose_service_line(path)
   local docker_compose_path = ''
   local settings = require('pytest.config').get()

   if not path or path == '' then
      docker_compose_path = docker.find_docker_compose()
   else
      docker_compose_path = path
   end

   local lineno = -1
   if docker_compose_path == '' then
      return lineno
   end

   local docker_compose_name = settings.docker.docker_compose_file or 'docker-compose.yml'

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
function docker.get_docker_compose_volume(path)
   local docker_compose_path = ''
   local settings = require('pytest.config').get()

   if not path or path == '' then
      docker_compose_path = docker.find_docker_compose()
   else
      docker_compose_path = path
   end


   local docker_compose_name = settings.docker.docker_compose_file or 'docker-compose.yml'

   local docker_compose_file = io.open(docker_compose_path .. '/' .. docker_compose_name, 'r')
   if not docker_compose_file then
      return ''
   end

   local service_line = docker.get_docker_compose_service_line(docker_compose_path)
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

---Build docker command to passed files
---@param settings table
---@param files table
---@return table
function docker.build_docker_command(settings, files)
   local docker_compose_path = docker.find_docker_compose()
   local docker_path = settings.docker.docker_path or ''

   if settings.docker.enable_docker_compose then
      local volume = docker.get_docker_compose_volume(docker_compose_path)
      if volume == '' then
         utils.error('Docker compose / volume not found')
         return {}
      end
      settings.docker.docker_path = volume
      docker_path = volume
   end

   local path_prefix = settings.docker.local_path_prefix
   if path_prefix and path_prefix ~= '' then
      path_prefix = '/' .. path_prefix
   end

   local parsed_files = docker.parse_docker_files(docker_path, path_prefix, docker_compose_path, files)
   local container = settings.docker.container

   local pytest_command = pytest.build_command(parsed_files)
   return utils.list_extend({ 'docker', 'exec', container }, pytest_command)
end

---Parse a file or a list of files to docker internal path
---@param docker_path string
---@param path_prefix string
---@param local_root string
---@param files string | table
---@return table
function docker.parse_docker_files(docker_path, path_prefix, local_root, files)
   local parsed = {}
   if type(files) == "string" then
      files = { files }
   end

   -- Transform each file to docker path format
   for _, file in ipairs(files) do
      local relative_file = file:match(utils.scape_special_chars(local_root) ..
         utils.scape_special_chars(path_prefix) .. '/(.*)')

      local docker_file_path = docker_path .. relative_file
      parsed = utils.list_extend(parsed, {docker_file_path})
   end

   return parsed
end

return docker
