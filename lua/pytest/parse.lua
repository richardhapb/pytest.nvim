local utils = require 'pytest.utils'


local M = {}

M.NS = vim.api.nvim_create_namespace('pytest_test')

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

---Get the lines of test functions for the current file
---@param stdout string[]
---@param bufnr number
---@return TestResult[]?
function M.get_test_results(stdout, bufnr)
   -- TODO: Refactor this function
   local tests_executed = {}

   for _, line in ipairs(stdout) do
      if line:match('.*%.py::.*::.*') then
         table.insert(tests_executed, line)
      end
   end

   if #tests_executed == 0 then
      for _, line in ipairs(stdout) do
         if line:match('.*%.py::.*') then
            table.insert(tests_executed, line)
         end
      end
   end

   local parser = vim.treesitter.get_parser(bufnr, "python")
   if not parser then
      utils.error("Parser not found")
      return
   end
   local tree = parser:parse()[1]
   local root = tree:root()

   local parsed_query = vim.treesitter.query.get("python", 'custom')
   if not parsed_query then
      utils.error("Query not found")
      return
   end

   local test_results = {}

   for _, test_exec in ipairs(tests_executed) do
      -- TODO: Extract this to a function
      local class_name, function_name, stat = test_exec:match('.*%.py::(.*)::(.-)%s+(.*)%s+%[')
      if not function_name then
         class_name, function_name, stat = test_exec:match('.*%.py::(.*)::(.-)%s+(.*)%s+%[?')
         if not function_name then
            function_name, stat = test_exec:match('.*%.py::(.-)%s+([^%s]+)%s')
            class_name = ''
         end
      end

      local active_class = ''
      if function_name then
         for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
            local capture_name = parsed_query.captures[id]
            if capture_name == 'class' then
               local range = { node:range() }
               local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1]
               if line:match(class_name) then
                  active_class = class_name
               end
            end

            if capture_name == 'function' then
               local range = { node:range() }
               local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1]
               if line:match(function_name) and active_class == class_name then
                  table.insert(test_results,
                     { line = range[1], state = string.lower(stat), class_name = class_name, function_name =
                     function_name })
                  active_class = ''
               end
            end
         end
      end
   end
   return test_results
end

function M.update_marks(bufnr, test_results)
   for _, test_result in ipairs(test_results) do
      if not test_result.line then
         return
      end
      local text = test_result.state == 'passed' and '\t✅' or ''
      text = test_result.state == 'failed' and '\t❌' or text
      vim.api.nvim_buf_set_extmark(bufnr, M.NS, test_result.line, 0, { virt_text = { { text } } })
   end
end

return M
