local utils = require 'pytest.utils'
local config = require 'pytest.config'
local parse = require 'pytest.parse'

---@class Test
---@field command string[]
---@field job_id number
---@field has_sdout boolean
---@field results TestResult[]

---@class TestState
---@field bufnr number
---@field last_output string[]
---@field filenames string[]
---@field working boolean
---@field last_job_id number

---@class TestResult
---@field line number
---@field state 'passed' | 'failed'
---@field filename string
---@field class_name string
---@field function_name string
---@field message string[]

local M = {}

local test_state = {
   bufnr = nil,
   filenames = nil,
   working = false,
   last_output = nil
}

---Clear any results and reset state
---@param reset_buffer? boolean
function M.reset_state(reset_buffer)
   local ns = parse.NS

   if test_state.bufnr and vim.api.nvim_buf_is_valid(test_state.bufnr) then
      vim.api.nvim_buf_clear_namespace(test_state.bufnr, ns, 0, -1)
      vim.diagnostic.reset(ns, test_state.bufnr)
   end

   test_state.working = false
   test_state.filenames = nil
   test_state.has_stdout = false

   if reset_buffer then
      test_state.bufnr = nil
   end
end

---Run a test
---@param test Test
function M.run(test)
   -- Only update marks in current buffer
   local ok_dep, msg = utils.verify_dependencies()
   if not ok_dep then
      utils.error(msg)
      return
   end
   local ns = parse.NS

   if test_state.working then
      M.cancel_test()
   end
   M.reset_state()
   test_state.working = true

   local bufnr = test_state.bufnr or vim.api.nvim_get_current_buf()
   utils.info("Running tests...")

   test.job_id = vim.fn.jobstart(
      test.command, {
         stdout_buffered = true,
         stderr_buffered = true,
         on_stdout = function(_, stdout)
            if stdout then
               test_state.has_stdout = true
               M.update_last_output(stdout)
            end
         end,
         on_stderr = function(_, stderr)
            if stderr and not test_state.has_stdout then
               M.update_last_output(stderr)
            end
         end,
         on_exit = function(_, exit_code)
            local failed = {}
            local i = 1
            test.results = parse.get_test_results(test_state.last_output, bufnr) or {}
            parse.update_marks(bufnr, test.results)
            for _, test_result in ipairs(test.results) do
               if test_result.state == 'failed' then
                  local error = parse.get_error_detail(test_state.last_output, i, test_result)
                  local ok, col = pcall(vim.api.nvim_buf_get_lines, bufnr, error.line, error.line + 1, false)

                  -- TODO: Obtain range with treesitter
                  if ok and #col > 0 then
                     error.col = (string.find(col[1], '[^%s]+') or 1) - 1
                     error.end_col = (string.len(col[1]) or error.col)
                  else
                     error.col = 0
                     error.end_col = 0
                  end

                  if error.line == -1 then
                     error.line = test_result.line
                  end

                  table.insert(failed, {
                     bufnr = bufnr,
                     lnum = error.line,
                     end_lnum = error.line,
                     col = error.col,
                     end_col = error.end_col,
                     text = 'Test failed',
                     severity = vim.diagnostic.severity.ERROR,
                     message = 'Test failed\n' .. error.error,
                     source = 'Django test',
                     code = 'TestError',
                     namespace = ns,
                  })
                  i = i + 1
               end
               test.job_id = nil
            end

            local message = exit_code == 0 and 'Tests passed 👌' or 'Tests failed 😢'
            utils.info(message)
            vim.diagnostic.set(ns, bufnr, failed, {})
            test_state.working = false
            test.job_id = nil

            -- Show the output if fails
            if exit_code == 1 and config.get().open_output_onfail then
               M.show_last_output()
            end
         end
      })
end

---Display the last output (stdout or stderr) in a new buffer
M.show_last_output = function()
   if test_state.last_output then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_state.last_output)
      vim.cmd.split()
      vim.api.nvim_set_current_buf(bufnr)
   end
end

---Cancel a running test
M.cancel_test = function()
   if test_state.working and test_state.last_job_id then
      local ok = pcall(vim.fn.jobstop, test_state.last_job_id)
      if ok then
         utils.info("Pytest job cancelled, running the new test")
      end

      M.reset_state()
   end
end

---Update the last stdout state
---@param stdout string[]
function M.update_last_output(stdout)
   test_state.last_output = stdout
end

---Get the last stdout state
---@return string[] | nil
function M.get_last_output()
   return test_state.last_output
end

return M
