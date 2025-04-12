local utils = require 'pytest.utils'
local config = require 'pytest.config'
local parse = require 'pytest.parse.utils'
local xml = require 'pytest.parse.xml'

---@class Test
---@field command string[]
---@field job_id number
---@field has_sdout boolean
---@field results TestResult[]

---@class TestState
---@field bufnr number
---@field last_output? string[]
---@field has_stdout? boolean
---@field filenames? string[]
---@field working? boolean
---@field last_job_id? number

---@class FailedTest
---@field lnum number
---@field end_lnum number
---@field col number
---@field end_col number
---@field message string[]

---@class TestResult
---@field state 'passed' | 'skipped' | 'failed'
---@field filename string
---@field class_name string
---@field class_lnum number
---@field function_name string
---@field function_lnum number
---@field failed_test? FailedTest

local _test_state = {
   bufnr = nil,
   filenames = nil,
   working = false,
   last_output = nil,
   has_sdout = false
}

---Set the _test_state
---@param state TestState
local function set_state(state)
   _test_state = vim.tbl_extend("force", _test_state, state)
end

---Display the last output (stdout or stderr) in a new buffer
local function show_last_output()
   if _test_state.last_output then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, _test_state.last_output)
      vim.cmd.split()
      vim.api.nvim_set_current_buf(bufnr)
   end
end

---Update the last stdout state
---@param stdout string[]
local function update_last_output(stdout)
   _test_state.last_output = stdout
end

---Get the last stdout state
---@return string[] | nil
local function get_last_output()
   return _test_state.last_output
end

---Clear any results and reset state
---@param reset_buffer? boolean
local function reset_state(reset_buffer)
   local ns = parse.NS

   if _test_state.bufnr and vim.api.nvim_buf_is_valid(_test_state.bufnr) then
      vim.api.nvim_buf_clear_namespace(_test_state.bufnr, ns, 0, -1)
      vim.diagnostic.reset(ns, _test_state.bufnr)
   end

   _test_state.working = false
   _test_state.filenames = nil
   _test_state.has_stdout = false

   if reset_buffer then
      _test_state.bufnr = nil
   end
end

---Cancel a running test
local function cancel_test()
   if _test_state.working and _test_state.last_job_id then
      local ok = pcall(vim.fn.jobstop, _test_state.last_job_id)
      if ok then
         utils.info("Pytest job cancelled, running the new test")
      end

      reset_state()
   end
end


---Run a test
---@param test Test
local function run(test)
   -- Only update marks in current buffer
   local ok_dep, msg = utils.verify_dependencies()
   if not ok_dep then
      utils.error(msg)
      return
   end
   local ns = parse.NS

   if _test_state.working then
      cancel_test()
   end
   reset_state()
   _test_state.working = true

   local bufnr = _test_state.bufnr or vim.api.nvim_get_current_buf()
   utils.info("Running tests...")

   test.job_id = vim.fn.jobstart(
      test.command, {
         stdout_buffered = true,
         stderr_buffered = true,
         on_stdout = function(_, stdout)
            if stdout then
               _test_state.has_stdout = true
               update_last_output(stdout)
            end
         end,
         on_stderr = function(_, stderr)
            if stderr and not _test_state.has_stdout then
               update_last_output(stderr)
            end
         end,
         on_exit = function(_, exit_code)
            local failed = {}
            local i = 1
            local parser = xml.XmlParser.new(_test_state.last_output)

            if not parser then
               utils.error("Error building the parser")
               return
            end

            test.results = parser:get_test_results()
            parse.update_marks(bufnr, test.results)
            for _, test_result in ipairs(test.results) do
               if test_result.failed_test and test_result.state == 'failed' then
                  local failed_test = test_result.failed_test or {}

                  table.insert(failed, {
                     bufnr = bufnr,
                     lnum = failed_test.lnum,
                     end_lnum = failed_test.lnum,
                     col = 0,
                     end_col = 0,
                     text = 'Test failed',
                     severity = vim.diagnostic.severity.ERROR,
                     message = 'Test failed\n' .. table.concat(failed_test.message, "\n"),
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
            _test_state.working = false
            test.job_id = nil

            -- Show the output if fails
            if exit_code == 1 and config.get().open_output_onfail then
               show_last_output()
            end
         end
      })
end

return {
   set_state = set_state,
   reset_state = reset_state,
   run = run,
   show_last_output = show_last_output,
   cancel_test = cancel_test,
   update_last_output = update_last_output,
   get_last_output = get_last_output,
}
