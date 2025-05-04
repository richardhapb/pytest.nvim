local ns = vim.api.nvim_create_namespace('pytest_test')


--- Get the number of spaces at the beginning of the line.
---@param line string
---@return number
local function calculate_tab(line)
   return #(line:match("^%s*") or "")
end


---Look for the deepest node in a tests tree and the end line of the element
---@param tests_tree string[] lines of the test hierarchical tree
---@param index number index of the row in tests_tree element
--- @return number, number: the maximum depth of tabs and the parent end index
local function get_section_info(tests_tree, index)
   assert(index <= #tests_tree, "Index out of range in tests tree")

   local tabs = calculate_tab(tests_tree[index])
   local result = tabs
   local end_index = index

   for _, line in ipairs(vim.list_slice(tests_tree, index + 1)) do
      local current_tabs = calculate_tab(line)

      if current_tabs <= tabs then
         break
      end

      result = current_tabs
      end_index = end_index + 1
   end

   return result, end_index
end

--- Update the test result marks in the buffer
---@param bufnr number
---@param test_results TestResult[]
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

return {
   NS = ns,
   update_marks = update_marks,
   calculate_tab = calculate_tab,
   get_section_info = get_section_info,
}
