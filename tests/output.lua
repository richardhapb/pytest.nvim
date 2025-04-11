---@diagnostic disable: undefined-field
local output = require 'pytest.parse.output'

local collect_out = io.open(vim.fs.joinpath('tests', 'fixtures', 'collect.txt'), 'r')
---@type string | string[]
local collect = ""
if collect_out then
   collect = collect_out:read("*a")
   collect = vim.split(collect, '\n', { plain = true })
   collect = vim.list_slice(collect, 5)
end

describe("Ensure parsing of collect output", function()
   it("Modules must be retrieved correctly", function()
      assert(#collect > 0, "Output is empty")
      assert(type(collect) == "table", "Output must be a table")

      local root = {
         name = "Root",
         pkgs = {},
         modules = {},
         classes = {},
         functions = {}
      }
      local result = output.parse_collect_section(collect, root, 0)
      vim.print(result)
   end)
end)
