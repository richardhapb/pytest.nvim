local utils = require 'pytest.utils'

---@class TSParser
---@field query vim.treesitter.Query
---@field text_lines string[]
---@field bufnr number


local M = {}

if vim.fn.has("win32") == 1 then
   OUTPUT_FILE = "C:\\tmp\\pytest_report.xml"
else
   -- OUTPUT_FILE = "/tmp/pytest_report.xml"
   OUTPUT_FILE = "/Users/richard/plugins/pytest.nvim/tests/fixtures/pytest_report_local.xml"
end

local ns = vim.api.nvim_create_namespace('pytest_test')

local TSParser = {}
TSParser.__index = TSParser

---Create a new TSParser instance
---@return TSParser?
function TSParser.new()
   local self = setmetatable({}, TSParser)

   local tmp_file = io.open(OUTPUT_FILE, "r")

   if tmp_file then
      self.text_lines = tmp_file:read("*a")
      self.parser = vim.treesitter.get_string_parser(self.text_lines, "xml")
      tmp_file:close()
   else
      self.text_lines = {}
      self.parser = nil
   end

   self.query = vim.treesitter.query.get("xml", "pytest")
   if not self.query then
      utils.error("Pytest query for XML not found. Make sure you have defined it in queries/xml/pytest.scm")
      return nil
   end
   return self
end

function TSParser:get_fail_nodes(name)
end

---Get the lines of test functions for the current file
---@param stdout string[]
---@param bufnr number
---@return TestResult[]?
function TSParser:get_test_results(stdout, bufnr)
   local test_results = {}

   local root = self.parser:parse()[1]:root()
   for id, node in self.query:iter_captures(root, self.text_lines) do
      local name = self.query.captures[id]
      if name == "case_passed" then
         -- vim.print(self.query.captures[id])
         -- vim.print(vim.treesitter.get_node_text(node, self.text_lines))
      end
      if name == "not_passed" then
         local node_text = vim.treesitter.get_node_text(node, self.text_lines)
         vim.print(self.query.captures[id])
         local state = node_text:find("skipped") and "skipped" or "failed"

         vim.print(state)
      end
   end

   return test_results
end

---Get the line and error message of the failed test for the current file
---@param stdout string[]
---@param index number
---@param test_result TestResult
---@return table
function M.get_error_detail(stdout, index, test_result)
   local detail = { line = -1, error = '' }

   if not test_result.filename then
      test_result.filename = vim.fn.expand('%:t')
   end

   local count = 1
   for _, line in ipairs(stdout) do
      local error = line:match('^E%s+(.*)')
      if error and detail.error == '' then
         if count == index then
            detail.error = error
         else
            count = count + 1
         end
      end

      local linenr = line:match(test_result.filename:gsub('%.', '%%.') .. ':(%d+)')
      if linenr and detail.line == -1 then
         if count == index then
            detail.line = tonumber(linenr) - 1
         end
      end

      if detail.error ~= '' and detail.line > 0 then
         break
      end
   end

   return detail
end

function M.update_marks(bufnr, test_results)
   for _, test_result in ipairs(test_results) do
      if not test_result.line then
         return
      end
      local text = test_result.state == 'passed' and '\t✅' or ''
      text = test_result.state == 'failed' and '\t❌' or text
      vim.api.nvim_buf_set_extmark(bufnr, ns, test_result.line, 0, { virt_text = { { text } } })
   end
end

M.TSParser = TSParser
M.NS = ns

local parser = M.TSParser.new()

if parser then
   vim.print(parser:get_test_results())
end

return M
