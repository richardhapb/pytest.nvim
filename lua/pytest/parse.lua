local utils = require 'pytest.utils'

---@class XmlParser
---@field query vim.treesitter.Query
---@field text string
---@field text_lines string[]
---@field stdout string[]
---@field parser vim.treesitter.LanguageTree
---@field get_filename_and_class_from_output fun(self: XmlParser, function_name: string): table
---@field get_function_name fun(self: XmlParser, source: string): string
---@field get_test_results fun(self: XmlParser): TestResult[]

---@class PythonParser
---@field query vim.treesitter.Query
---@field text string
---@field text_lines string[]
---@field bufnr number
---@field parser vim.treesitter.LanguageTree
---@field get_test_elements_lnum fun(self: PythonParser, class_name: string, function_name: string): number, number



local M = {}

local ns = vim.api.nvim_create_namespace('pytest_test')

local PythonParser = {}
PythonParser.__index = PythonParser

local XmlParser = {}
XmlParser.__index = XmlParser


if vim.fn.has("win32") == 1 then
   OUTPUT_FILE = "C:\\tmp\\pytest_report.xml"
else
   OUTPUT_FILE = "/tmp/pytest_report.xml"
end

LOCAL_OUTPUT_FILE = OUTPUT_FILE

---Set the environment variable `OUTPUT_FILE`
---@param output_file any
local function set_output_file(output_file)
   OUTPUT_FILE = output_file
end

---@param text string The XML text with encoded entities
---@return string - The decoded text with proper characters
local function decode_xml_entities(text)
   local entities = {
      ["&lt;"] = "<",
      ["&gt;"] = ">",
      ["&amp;"] = "&",
      ["&quot;"] = '"',
      ["&apos;"] = "'",
      ["&#10;"] = "\n",
      ["&#13;"] = "\r",
   }

   return (text:gsub("(%&[^;]+%;)", function(entity)
      return entities[entity] or entity
   end))
end

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

---Create a new TSParser instance
---@param stdout string[]
---@return XmlParser?
function XmlParser.new(stdout)
   if not stdout then
      utils.error("Pytest stdout is required")
      return nil
   end

   local self = setmetatable({}, XmlParser)
   local tmp_file = io.open(OUTPUT_FILE, "r")

   if tmp_file then
      self.text = tmp_file:read("*a")
      if self.text then
         self.text_lines = vim.split(self.text, '\n', { plain = true })
      end
      self.parser = vim.treesitter.get_string_parser(self.text, "xml")
      tmp_file:close()

      -- If run in docker clean the volume
      if require'pytest.config'.get().docker.enabled then
         os.remove(OUTPUT_FILE)
         OUTPUT_FILE = LOCAL_OUTPUT_FILE
      end
   else
      self.text = ""
      self.text_lines = {}
      self.parser = nil
   end

   self.stdout = stdout or {}
   self.query = vim.treesitter.query.get("xml", "pytest")

   if not self.query then
      utils.error("Pytest query for XML not found. Make sure you have defined it in queries/xml/pytest.scm")
      return nil
   end
   return self
end

---Get all filenames from pytest output
---@param function_name string
---@return table
function XmlParser:get_filename_and_class_from_output(function_name)
   local filename = ""
   local class_name = ""
   for _, line in ipairs(self.stdout) do
      if line:find(".-::" .. function_name) then
         filename = line:gsub("::" .. function_name, ""):match("([^%s/]-%.py)%s*")
      elseif line:find(".-::.-::" .. function_name) then
         filename, class_name = line:gsub("::" .. function_name, ""):match("/?([^%s/]-%.py)::(.*)%s*")
      end
   end

   return {
      filename = filename,
      class_name = class_name
   }
end

---Get the function name from a `passed` or `not_passed` node
---@param source string
---@return string
function XmlParser:get_function_name(source)
   return source:match('%sname="([^"]*)"') or ""
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

---Get the lines of test functions for the current file
---@return TestResult[]?
function XmlParser:get_test_results()
   if self.text_lines == nil or #self.text_lines == 0 then
      return {}
   end

   local test_results = {}
   local python_parser = PythonParser.new()

   local root = self.parser:parse()[1]:root()
   for id, node in self.query:iter_captures(root, self.text_lines) do
      local name = self.query.captures[id]
      if name == "passed" or name == "not_passed" then
         local node_text = vim.treesitter.get_node_text(node, self.text)
         local function_name = ""

         if name == "passed" then
            function_name = self:get_function_name(node_text)
         else
            local parent_node = node

            -- The tag with name is two levels up
            for _ = 1, 3 do
               parent_node = parent_node:parent() or parent_node
            end

            if parent_node then
               local parent_node_text = vim.treesitter.get_node_text(parent_node, self.text)
               function_name = self:get_function_name(parent_node_text)
            end
         end

         local names = self:get_filename_and_class_from_output(function_name)

         local function_lnum = 0
         local class_lnum = 0
         if python_parser then
            class_lnum, function_lnum = python_parser:get_test_elements_lnum(names.class_name, function_name)
         end

         local test_result = nil
         if name == "passed" then
            test_result = {
               state = "passed",
               filename = names.filename,
               class_name = names.class_name,
               class_lnum = class_lnum,
               function_name = function_name,
               function_lnum = function_lnum,
            }
         else
            local state = node_text:find("skipped") and "skipped" or "failed"
            local error_detail = self:get_error_detail(node, names)

            local failed_test = nil
            if state == "failed" then
               failed_test = {
                  lnum = error_detail.lnum,
                  message = error_detail.message
               }
            end

            test_result = {
               state = state,
               filename = names.filename,
               class_name = names.class_name,
               class_lnum = class_lnum,
               function_name = function_name,
               function_lnum = function_lnum,
               failed_test = failed_test
            }
         end

         table.insert(test_results, test_result)
      end
   end

   return test_results
end

---Get the line and error message of the failed test for the current file
---@param node TSNode
---@param names table[filename, class_name]
---@return table[lnum, message]
function XmlParser:get_error_detail(node, names)
   local lnum = -1
   local err_message = ""

   if not names or not names.filename then
      return {}
   end

   local parent = node:parent()
   local lines = {}
   if parent then
      lines = vim.split(vim.treesitter.get_node_text(parent, self.text), '\n', { plain = true })
   end

   for _, ch_node in ipairs(node:named_children()) do
      local node_text = vim.treesitter.get_node_text(ch_node, self.text)
      local message = node_text:match('message="([^"]*)"')
      if message then
         err_message = message:gsub("%s+", " ")
         break
      end
   end

   for _, line in ipairs(lines) do
      local linenr = line:match(names.filename:gsub('%.', '%%.') .. ':(%d+)')
      if linenr and lnum == -1 then
         lnum = tonumber(linenr) - 1
      end

      if err_message ~= '' and lnum > 0 then
         break
      end
   end


   err_message = decode_xml_entities(err_message)

   return {
      lnum = lnum,
      message = vim.split(err_message, '\n', { plain = true })
   }
end

local function update_marks(bufnr, test_results)
   for _, test_result in ipairs(test_results) do
      if not test_result.function_lnum then
         return
      end
      local text = test_result.state == 'passed' and '\t✅' or ''
      text = test_result.state == 'skipped' and '\t💤' or text
      text = test_result.state == 'failed' and '\t❌' or text
      vim.api.nvim_buf_set_extmark(bufnr, ns, test_result.function_lnum, 1, { virt_text = { { text } } })
   end
end

M.XmlParser = XmlParser
M.PythonParser = PythonParser
M.OUTPUT_FILE = OUTPUT_FILE
M.NS = ns
M.set_output_file = set_output_file
M.update_marks = update_marks
M.decode_xml_entities = decode_xml_entities

return M
