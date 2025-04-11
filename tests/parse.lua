---@diagnostic disable: undefined-field
local python = require 'pytest.parse.python'

vim.opt.rtp:append(vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "nvim-treesitter"))

require 'pytest'.setup()

describe("Get failed details", function()
   local python_test_class = [[
   class Foo:
      def setup_something(self):
          pass

      def test_foo(self):
          self.setup_something()
          assert True
   ]]

   local python_test_function = [[
   def setup_something(self):
       pass

   def test_foo(self):
       self.setup_something()
       assert True
   ]]


   it("Assert class lnum and function lnum", function ()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(python_test_class, '\n'))
      local python_parser = python.PythonParser.new(buf)
      if not python_parser then
         assert.is.False(true)
         return
      end

      local class_lnum, function_lnum = python_parser:get_test_elements_lnum('Foo', 'test_foo')

      assert.is.equal(0, class_lnum)
      assert.is.equal(4, function_lnum)
   end)

   it("Assert function lnum", function ()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(python_test_function, '\n'))
      local python_parser = python.PythonParser.new(buf)
      if not python_parser then
         assert.is.False(true)
         return
      end

      local class_lnum, function_lnum = python_parser:get_test_elements_lnum('Foo', 'test_foo')

      assert.is.equal(0, class_lnum)
      assert.is.equal(3, function_lnum)

      class_lnum, function_lnum = python_parser:get_test_elements_lnum('Foo', 'setup_something')

      assert.is.equal(0, class_lnum)
      assert.is.equal(0, function_lnum)
   end)
end)
