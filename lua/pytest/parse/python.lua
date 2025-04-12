local utils = require 'pytest.utils'

---@class PythonParser
---@field query vim.treesitter.Query
---@field text string
---@field text_lines string[]
---@field bufnr number
---@field parser vim.treesitter.LanguageTree
---@field get_test_elements_lnum fun(self: PythonParser, class_name: string, function_name: string): number, number

local PythonParser = {}
PythonParser.__index = PythonParser

---Create a new PythonParser instance
---@param bufnr? number
---@return PythonParser?
function PythonParser.new(bufnr)
   if not bufnr then
      bufnr = vim.api.nvim_get_current_buf()
   end

   local self = setmetatable({}, PythonParser)

   self.text_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   self.text = table.concat(self.text_lines, '\n')
   self.parser = vim.treesitter.get_string_parser(self.text, "python")

   self.query = vim.treesitter.query.get("python", "pytest")

   if not self.query then
      utils.error("Pytest query for Python not found. Make sure you have defined it in queries/python/pytest.scm")
      return nil
   end
   return self
end

---Get the function line in the buffer using function name
---@param class_name string
---@param function_name string
---@return number, number
function PythonParser:get_test_elements_lnum(class_name, function_name)
   local root = self.parser:parse()[1]:root()
   local has_class = class_name ~= ""
   local function_lnum = 0
   local class_lnum = 0

   local function look_for_function(parent_node)
      for _, child in parent_node:named_children() do
         local identifier = vim.split(vim.treesitter.get_node_text(child, self.text), '\n')[1]
         identifier = identifier:match("def%s+([^(]+)%(")

         if identifier == function_name then
            function_lnum = unpack(vim.treesitter.get_range(child, self.text))
            return function_lnum
         end
      end
      return 0
   end

   for id, node in self.query:iter_captures(root, self.text) do
      local name = self.query.captures[id]
      local identifier = vim.split(vim.treesitter.get_node_text(node, self.text), '\n')[1]
      identifier = identifier:match("class%s+([^(]+)%(") or identifier:match("def%s+([^(]+)%(")

      if has_class and name == "class" and identifier == class_name then
         class_lnum = unpack(vim.treesitter.get_range(node, self.text))
         function_lnum = look_for_function(node)
      elseif name == "function" and identifier == function_name then
         function_lnum = unpack(vim.treesitter.get_range(node, self.text))
      end
   end

   return class_lnum, function_lnum
end

return {
   PythonParser = PythonParser
}
