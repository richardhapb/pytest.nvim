local ns = vim.api.nvim_create_namespace('pytest_test')

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
   update_marks = update_marks
}
