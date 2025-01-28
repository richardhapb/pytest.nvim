local config = {}

config.settings = {
   docker = {
      enabled = true,
      container = 'ddirt-web-1',
      docker_path = '/usr/src/app',
   },
}

return config

