local config = {}

---@class DockerConfig
---@field enabled boolean | function Enable/disable looking for docker container to locate pytest
---@field container string | function Container name or a callback for get it
---@field docker_path string | function Internal docker path or a callback for get it
---@field local_path_prefix string | function Prefix for matching in local environment from cwd, or a callback for get it
---@field enable_docker_compose boolean | function Enable/disable the docker compose usage for match the path
---@field docker_compose_file string | function Docker compose name, for locating and match the docker path and local path prefix or a callback for get it
---@field docker_compose_service string | function Name of the service inside docker compose, for locating the path or a callback for get it

---@class DjangoConfig
---@field enabled boolean | function Enable/diable django support
---@field django_settings_module string | function Set the DJANGO_SETTINGS_MODULE variable to pytest

---@class PytestConfig
---@field docker DockerConfig
---@field django DjangoConfig
---@field add_args string[] | string | function Additional arguments to pass to pytest
---@field open_output_onfail boolean | function Open the buffer with output automatically if fails
---@field keymaps_callback function function for set the keymaps

---Update the callbacks into a table
---@param opts table
---@return table Updated table
local function update_callbacks(opts)
   for k, v in pairs(opts) do
      if type(v) == "function" then
         opts[k] = v()
      end
   end

   return opts
end

---@type PytestConfig
config.defaults = {
   docker = {
      enabled = false,
      container = 'app-1',
      docker_path = '/usr/src/app',
      local_path_prefix = 'app',
      enable_docker_compose = false,
      docker_compose_file = 'docker-compose.yml',
      docker_compose_service = 'app',
   },

   django = {
      enabled = false,
      django_settings_module = ""
   },

   add_args = "",
   open_output_onfail = false,

   keymaps_callback = function(bufnr)
      vim.keymap.set('n', '<leader>TT', '<CMD>Pytest<CR>', { buffer = bufnr, desc = 'Run Pytest' })
      vim.keymap.set('n', '<leader>Ta', '<CMD>PytestAttach<CR>', { buffer = bufnr, desc = 'Attach Pytest to buffer' })
      vim.keymap.set('n', '<leader>Td', '<CMD>PytestDetach<CR>', { buffer = bufnr, desc = 'Detach Pytest' })
   end
}

-- This is used to retain the original user options
-- and keep the callbacks for use
-- when the command is executed
config.opts = config.settings

---Update config and return config
---@param opts? PytestConfig
config.update = function(opts)
   opts = opts or {}

   if opts ~= nil and opts.docker ~= nil then
      opts.docker = update_callbacks(opts.docker)
   end

   if opts ~= nil and opts.django ~= nil then
      opts.django = update_callbacks(opts.django)
   end

   return vim.tbl_deep_extend('force', config.opts, opts)
end

---Get the config
---@param opts? table
---@return PytestConfig
config.get = function(opts)
   opts = opts or {}

   return config.update(vim.tbl_deep_extend("force", config.opts, opts))
end

return config
