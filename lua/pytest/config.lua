local config = {}

config.settings = {
   docker = {
      enabled = true,
      container = 'ddirt-web-1',
      docker_path = '/usr/src/app',
      docker_path_prefix = 'app',
      docker_compose_file = 'docker-compose.yml',
      docker_compose_service = 'web',
      enable_docker_compose = true,
   },
}

return config

