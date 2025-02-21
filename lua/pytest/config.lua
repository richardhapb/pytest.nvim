local config = {}

config.settings = {
   docker = {
      enabled = true,
      container = 'app-1',
      docker_path = '/usr/src/app',
      docker_path_prefix = 'app',
      docker_compose_file = 'docker-compose.yml',
      docker_compose_service = 'app',
      enable_docker_compose = true,
   },
}

config.update = function(opts)
   opts = opts or {}
   config.settings = vim.tbl_deep_extend('force', config.settings, opts)
end

config.get = function()
   return config.settings
end

return config

