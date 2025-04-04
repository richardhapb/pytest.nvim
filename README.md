
# Pytest.nvim

<img width="885" alt="image" src="https://github.com/user-attachments/assets/4405219d-1c18-4086-9f84-a47dd60c67c5" />

## About the project

Testing integrated in neovim with pytest. Include Docker support. This project is in progress, I will be adding more features in the future and I open to contributions.

## Getting Started

These instructions will help you set up and use `pytest.nvim` in your Neovim environment.

### Prerequisites

- Neovim 0.5.0 or later
- pytest in your environment (pip install pytest)

### Installation

1. Install the `pytest.nvim` plugin using your preferred plugin manager:

    Lazyvim:


    ```lua
    {
      "richardhapb/pytest.nvim",
      opts = {}
    }
    ```

   Packer:

    ```lua
    use {
      "richardhapb/pytest.nvim",
      opt = true
    }
    ```

   Vim-Plug:

    ```vim
    Plug 'richardhapb/pytest.nvim'
    ```

### Usage

1. Load the `pytest` plugin in your Neovim configuration if you haven't already done so. For example:

    ```lua
    require('pytest').setup()
    ```

2. Use the `:Pytest` command to run the tests in the current buffer.

    - To check the entire buffer:

        ```vim
        :Pytest
        ```

    - To check the output of the tests:

        ```vim
        :PytestOutput
        ```

    - You can attach the test to the current buffer, this runs test on save:
      
        ```vim
        :PytestAttach
        ```
    - You can detach the test from the current buffer:
      
        ```vim
        :PytestDetach
        ```
    - Docker enable on the way
      
        ```vim
        :PytestEnableDocker
        ```
    - Docker disabled on the way
      
        ```vim
        :PytestDisableDocker
        ```

The default keybinding that runs `:Pytest` is `<leader>T`.

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
      enabled = true,  -- Enable docker support
      container = 'app-1',  -- Container where the tests will be run
      docker_path = '/usr/src/app',  -- This is the default path, if you use docker compose this is obtained from the docker compose file
      docker_path_prefix = 'app', -- This is the prefix for the path in the cwd in your local, for example: root/app/<docker_app_content>
      docker_compose_file = 'docker-compose.yml',  -- This is the default docker compose file name
      docker_compose_service = 'app',  -- This is for looking for the docker path in docker compose
      enable_docker_compose = true,  -- Enable docker compose support
   },

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

