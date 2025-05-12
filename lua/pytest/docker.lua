local utils = require 'pytest.utils'
local pytest = require 'pytest.pytest'

---Verify if the container is running
---@param callback function
local function is_container_running(callback)
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
local function find_docker_compose(path)
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

---Obtain the text in the docker-compose file using `docker compose config` function
---@return string[]
local function get_docker_compose_lines()
   local settings = require('pytest.config').get()

   local docker_compose_name = settings.docker.docker_compose_file or 'docker-compose.yml'

   if type(docker_compose_name) == "function" then
      docker_compose_name = docker_compose_name()
   end

   local docker_compose_text = vim.system({ "docker", "compose", "-f", docker_compose_name, "config" }):wait().stdout
   if not docker_compose_text then
      return {}
   end

   return vim.split(docker_compose_text, '\n', { plain = true })
end

---Obtain the line number of the service in the docker-compose file
---@param path? string
---@return number
local function get_docker_compose_service_line(path)
   local docker_compose_path = ''
   local settings = require('pytest.config').get()

   if not path or path == '' then
      docker_compose_path = find_docker_compose()
   else
      docker_compose_path = path
   end

   local lineno = -1
   if docker_compose_path == '' then
      return lineno
   end

   local docker_compose_lines = get_docker_compose_lines()

   if #docker_compose_lines == 0 then
      return lineno
   end

   local service = settings.docker.docker_compose_service

   if not service or service == '' then
      return lineno
   end

   local possibles = {}

   for _, line in ipairs(docker_compose_lines) do
      lineno = lineno + 1
      if line:match('^%s*' .. service .. ':') then
         local spaces = #line:match("(%s*)" .. service .. ":")
         table.insert(possibles, { text = line, spaces = spaces, lineno = lineno })
      end
   end

   local temp_result = 100

   for _, p in ipairs(possibles) do
      if p.spaces < temp_result then
         lineno = p.lineno
      end
   end

   return lineno
end

---Get the volume path from the docker-compose file
---@param path? string
---@return string
local function get_docker_compose_volume(path)
   local docker_compose_path = ''
   local settings = require('pytest.config').get()

   if not path or path == '' then
      docker_compose_path = find_docker_compose()
   else
      docker_compose_path = path
   end

   local docker_compose_lines = get_docker_compose_lines()

   if #docker_compose_lines == 0 then
      return ''
   end

   local service_line = get_docker_compose_service_line(docker_compose_path)
   local volume = ''

   if service_line == -1 then
      return volume
   end

   local path_prefix = settings.docker.local_path_prefix or ''

   if path_prefix and path_prefix ~= '' then
      path_prefix = vim.fs.joinpath(docker_compose_path, path_prefix)
   end

   local volume_match = false
   for i, line in ipairs(docker_compose_lines) do
      if service_line < 0 then
         if line:match('^%s*volumes:') then
            if volume_match then
               return volume
            end

            volume_match = true
         end
      else
         service_line = service_line - 1
      end

      if volume_match then
         if line:match('^%s*source:%s' .. path_prefix .. '$') then
            -- There is on the next line
            volume = docker_compose_lines[i+1]:match('^%s*target:%s(.*)')
            break
         end
      end
   end

   return volume
end

---Parse a file or a list of files to docker internal path
---@param docker_path string
---@param path_prefix string
---@param local_root string
---@param elements string | table
---@return table
local function parse_docker_elements(docker_path, path_prefix, local_root, elements)
   local parsed = {}
   if type(elements) == "string" then
      elements = { elements }
   end

   -- Transform each element to docker path format
   for _, element in ipairs(elements) do
      if not element:find("::") and element:find(".*%.py$") then
         local relative_file = element:match(utils.escape_special_chars(local_root) ..
            utils.escape_special_chars(path_prefix) .. '[/\\](.*)')

         -- Fallback in case the path is transformed.
         if not relative_file then
            relative_file = element
         end

         local docker_file_path = vim.fs.joinpath(docker_path, relative_file)
         parsed = utils.list_extend(parsed, { docker_file_path })
      else
         parsed = utils.list_extend(parsed, { element })
      end
   end

   return parsed
end

---Build docker command to passed files
---@param settings table
---@param elements table
---@return table
local function build_docker_command(settings, elements)
   local docker_compose_path = find_docker_compose()
   local docker_path = settings.docker.docker_path or ''

   if settings.docker.enable_docker_compose then
      local volume = get_docker_compose_volume(docker_compose_path)
      if volume == '' then
         utils.error('Docker compose / volume not found')
         return {}
      end
      settings.docker.docker_path = volume
      docker_path = volume
   end

   local path_prefix = settings.docker.local_path_prefix
   if path_prefix and path_prefix ~= '' then
      local path_char = vim.fn.has("win32") == 1 and "\\" or "/"

      path_prefix = path_char .. path_prefix
   end

   local parsed_files = parse_docker_elements(docker_path, path_prefix, docker_compose_path, elements)
   local container = settings.docker.container

   local report_name = "pytest_report.xml"

   local output_file = vim.fs.joinpath(docker_compose_path, path_prefix, report_name)

   require 'pytest.parse.xml'.set_output_file(output_file)

   -- In docker create the report in project's root
   local pytest_command = pytest.build_command(parsed_files, report_name)
   return utils.list_extend({ 'docker', 'exec', '-i', container }, pytest_command)
end

return {
   is_container_running = is_container_running,
   find_docker_compose = find_docker_compose,
   get_docker_compose_service_line = get_docker_compose_service_line,
   get_docker_compose_volume = get_docker_compose_volume,
   build_docker_command = build_docker_command,
   parse_docker_files = parse_docker_elements,
}
