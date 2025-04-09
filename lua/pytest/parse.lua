local utils = require 'pytest.utils'

---@class TSParser
---@field query vim.treesitter.Query
---@field text string
---@field text_lines string[]
---@field stdout string[]
---@field bufnr number


local M = {}

if vim.fn.has("win32") == 1 then
   OUTPUT_FILE = "C:\\tmp\\pytest_report.xml"
else
   OUTPUT_FILE = "/tmp/pytest_report.xml"
end

local ns = vim.api.nvim_create_namespace('pytest_test')

local TSParser = {}
TSParser.__index = TSParser

---Create a new TSParser instance
---@param stdout string[]
---@return TSParser?
function TSParser.new(stdout)
   if not stdout then
      utils.error("Pytest stdout is required")
      return nil
   end

   local self = setmetatable({}, TSParser)
   local tmp_file = io.open(OUTPUT_FILE, "r")

   if tmp_file then
      self.text = tmp_file:read("*a")
      if self.text then
         self.text_lines = vim.split(self.text, '\n', { plain = true })
      end
      self.parser = vim.treesitter.get_string_parser(self.text, "xml")
      tmp_file:close()
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
function TSParser:get_names_from_output(function_name)
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
function TSParser:get_function_name(source)
   return source:match('%sname="([^"]*)"') or ""
end

---Get the lines of test functions for the current file
---@return TestResult[]?
function TSParser:get_test_results()
   if self.text_lines == nil or #self.text_lines == 0 then
      return {}
   end

   local test_results = {}

   local root = self.parser:parse()[1]:root()
   for id, node in self.query:iter_captures(root, self.text_lines) do
      local name = self.query.captures[id]
      if name == "passed" or name == "not_passed" then
         local node_text = vim.treesitter.get_node_text(node, self.text)
         local function_name = self:get_function_name(node_text)

         local names = self:get_names_from_output(function_name)

         local test_result = nil
         if name == "passed" then
            test_result = {
               line = -1,
               state = "passed",
               filename = names.filename,
               class_name = names.class_name,
               function_name = function_name,
               function_line = 1,
               message = ""
            }
         else
            local state = node_text:find("skipped") and "skipped" or "failed"
            local error_detail = self:get_error_detail(node, names)

            test_result = {
               line = error_detail.line,
               state = state,
               filename = names.filename,
               class_name = names.class_name,
               function_name = function_name,
               function_line = 1,
               message = error_detail.message
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
---@return table
function TSParser:get_error_detail(node, names)
   local detail = { line = -1, message = '' }

   if not names or not names.filename then
      return {}
   end

   local lines = vim.split(vim.treesitter.get_node_text(node:parent(), self.text), '\n', { plain = true })
   for _, ch_node in ipairs(node:named_children()) do
      local node_text = vim.treesitter.get_node_text(ch_node, self.text)
      local message = node_text:match('message="([^"]*)"')
      if message then
         detail.message = message:gsub("%s+", " ")
         break
      end
   end

   for _, line in ipairs(lines) do
      local linenr = line:match(names.filename:gsub('%.', '%%.') .. ':(%d+)')
      if linenr and detail.line == -1 then
         detail.line = tonumber(linenr) - 1
      end

      if detail.message ~= '' and detail.line > 0 then
         break
      end
   end

   return detail
end

function M.update_marks(bufnr, test_results)
   for _, test_result in ipairs(test_results) do
      if not test_result.funcion_line then
         return
      end
      local text = test_result.state == 'passed' and '\t✅' or ''
      text = test_result.state == 'skipped' and '\t💤' or text
      text = test_result.state == 'failed' and '\t❌' or text
      vim.api.nvim_buf_set_extmark(bufnr, ns, test_result.funcion_line, 1, { virt_text = { { text } } })
   end
end

M.TSParser = TSParser
M.NS = ns
M.OUTPUT_FILE = OUTPUT_FILE

return M
