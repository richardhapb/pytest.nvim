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

return config

