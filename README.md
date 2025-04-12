
# Pytest.nvim

<img width="885" alt="image" src="https://github.com/user-attachments/assets/4405219d-1c18-4086-9f84-a47dd60c67c5" />

## About the project

Testing integrated in neovim with `pytest`. Include Docker support. This project is in progress, I will be adding more features in the future and I open to contributions.

## Getting Started

These instructions will help you set up and use `pytest.nvim` in your Neovim environment.

### Prerequisites

- Neovim 0.9.0 or later
- `pytest` in your environment (pip install `pytest`)
- `xml` and `python` Treessitter parsers

### Installation

1. Install the `pytest.nvim` plugin using your preferred plugin manager, (requires Treesitter as a dependency):

    LazyVim:

    ```lua
    {
      "richardhapb/pytest.nvim",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      opts = {}, -- Define the options here 
      config = function(_, opts)
        require('nvim-treesitter.configs').setup {
          ensure_installed = { 'python', 'xml' },
        }

        require('pytest').setup(opts)
      end
    }
    ```

    Packer:

    ```lua
    use {
      "richardhapb/pytest.nvim",
      requires = { "nvim-treesitter/nvim-treesitter" },
      config = function()
        require('nvim-treesitter.configs').setup {
          ensure_installed = { 'python', 'xml' },
        }
        
        require('pytest').setup() -- Define the options here
      end,
      opt = true
    }
    ```

   Ensure the Treesitter dependencies:

   ```lua
   require('nvim-treesitter.configs').setup {
     ensure_installed = { 'python', 'xml' },
   }
   ```


### Usage

1. Load the `pytest` plugin in your Neovim configuration if you haven't already done so. For example:

    ```lua
    require('pytest').setup()
    ```

2. Use the `:Pytest` command to run the tests in the current buffer.

| Command | Description |
|---------|-------------|
| `:Pytest` | Checks the entire buffer |
| `:PytestOutput` | Shows the output of the tests (pytest will show failed tests output by default) |
| `:PytestAttach` | Attaches the test to the current buffer - runs tests on save in any Python file |
| `:PytestDetach` | Detaches the test from the last attached buffer |
| `:PytestEnableDocker` | Enables Docker support |
| `:PytestDisableDocker` | Disables Docker support |
| `:PytestUI` | Centralized UI for running tests (in progress). Currently shows pass/fail messages and marks; messages can be viewed with the `PytestOutput` command |

The default keybinding that runs `:Pytest` is `<leader>TT`.

## Defaults

The plugin provides the following default keymap:

- `<leader>TT` - Run pytest for the current file (normal mode)
- `<leader>Ta` - Attach pytest to the current buffer (normal mode)
- `<leader>Td` - Detach pytest from the current buffer (normal mode)


---

Default settings, is not necessary to set up, but you can change the settings in your configuration file.

```lua
require 'pytest'.setup {
   docker = {
      enabled = false,  -- Enable docker support
      container = 'app-1',  -- Container where the tests will be run
      docker_path = '/usr/src/app',  -- This is the default path, if you use docker compose this is obtained from the docker compose file
      docker_path_prefix = 'app', -- This is the prefix for the path in the cwd in your local, for example: root/app/<docker_app_content>
      enable_docker_compose = false,  -- Enable docker compose support
      docker_compose_file = 'docker-compose.yml',  -- This is the default docker compose file name
      docker_compose_service = 'app',  -- This is docker service name in docker compose for looking for retrieve docker path
   },

   django = {
      enabled = false,  -- Enable django support 
      django_settings_module = ""  -- Set the DJANGO_SETTINGS_MODULE variable to pytest
   },

   add_args = "",  -- Additional arguments to pass to pytest
   open_output_onfail = false, -- Open the buffer with output automatically if fails

   -- You can overwrite this callback with your custom keymaps,
   -- this is called when open a Python file and buffer number is passed as an argument
   keymaps_callback = function(bufnr)
      vim.keymap.set('n', '<leader>TT', '<CMD>Pytest<CR>', { buffer = bufnr, desc = 'Run Pytest' })
      vim.keymap.set('n', '<leader>Ta', '<CMD>PytestAttach<CR>', { buffer = bufnr, desc = 'Attach Pytest to buffer' })
      vim.keymap.set('n', '<leader>Td', '<CMD>PytestDetach<CR>', { buffer = bufnr, desc = 'Detach Pytest' })
   end
}
```

Options can be callbacks, for example:
```lua
require 'pytest'.setup {
   docker = {
      enabled = function()
         return vim.fn.getcwd():match(".*/(.*)$") == "work"  -- Only enable docker if the last dir of cwd is "work"
      end,

      container = function()
         local app = utils.get_my_awesome_app()
         return app .. '-version-2'
      end
   },
}
```
---

- If Docker is disabled, all Docker-related features are also disabled.

- When Docker Compose is enabled, its configuration takes precedence over the plugin’s direct settings.

- The prefix_app setting maps your local directory to the Docker path.

   > For example, if your current working directory is `~/projects/`, and the prefix is app, the Docker path `/usr/src/app` will map to `~/projects/app`.

- Docker is responsible only for path mapping and executing the Pytest command inside a running container — the container must already be running.

- If you're using Docker Compose, the plugin retrieves the Docker path from the volume configuration.

   > For example, if your docker-compose.yml contains:
   >
   > ```yaml
   > volumes:
   >   - app:/usr/src/app
   > ```

> Then `/usr/src/app` will be used as the Docker path.

- If `enable_docker_compose` is set to false, the plugin will fall back to the manually configured path instead. (Note: the container itself is not retrieved from Docker Compose at this point.)

- If `django` is enabled, the plugin will be check for the `pytest-django` extension for pytest, you can install it with `pip install pytest-django`, also you can define in `django_settings_module` the settings module to use (can be a custom settings for testing purposes).

  > ```lua
  > django = {
  >   enabled = true,
  >   django_settings_module = "myapp.settings_test"  -- This will pass the option `DJANGO_SETTINGS_MODULE` to `pytest`
  > }
  > ```

- You can pass additional arguments to pytest command:
  > ```lua
  > require 'pytest'.setup {
  >   add_args = { "-vv", "-s" } -- Verbose output
  > }
  > ```

---

## Features

- [x] Docker integration
- [x] Path from docker compose file
- [ ] Container name from docker compose file
- [x] Tests for docker compose file
- [x] Custom args for pytest command
- [x] Pass function as settings
- [x] Handle single file testing
- [ ] Handle multiple files
- [ ] Handle modules and project
- [x] Integrate treesitter for parsing
- [ ] Centralized UI
- [x] Parse error lines from XML output of pytest, instead of relying on stdout 

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git switch -c feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

