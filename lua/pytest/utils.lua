local utils = {}

---Extend a list with another list, from left to right
---@param list table
---@param extension table
---@return table
function utils.list_extend(list, extension)
   local new_list = {}
   for _, value in ipairs(list) do
      table.insert(new_list, value)
   end
   for _, value in ipairs(extension) do
      table.insert(new_list, value)
   end
   return new_list
end

function utils.scape_special_chars(str)
   for _, char in ipairs({ '(', ')', '[', ']', '.', '*', '+', '-', '?', '^', '$' }) do
      str = str:gsub('%' .. char, '%%' .. char)
   end

   return str
end

---Verify if the dependencies are available
---@return boolean, string
function utils.verify_dependencies()
   local ok = true
   local msg = ""
   local pytest = require 'pytest.pytest'

   local settings = require('pytest.config').get()
   if settings.docker.enabled then
      require 'pytest.docker'.is_container_running(function(container_running, message)
         if not container_running then
            ok = false
            msg = message
         end
      end):wait()
   elseif not pytest.is_pytest_available() then
      ok = false
      return ok, "pytest is not available"
   end

   if not ok then
      return ok, msg
   end

   if settings.django then
      pytest.is_pytest_django_available(function(pytest_available, message)
         if not pytest_available then
            ok = false
            msg = message
         end
      end)
   end

   return ok, msg
end

---Get the git root directory
---@return string
function utils.get_git_root()
   local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
   return (result.code == 0 and result.stdout:gsub("[\n\r]", "") or "")
end

---Get current working directory safely (works in fast event contexts)
---@return string
function utils.safe_getcwd()
   local ok, cwd = pcall(vim.uv.cwd)
   if ok and cwd then
      return cwd
   end
   -- Fallback, but this might fail in fast events
   return vim.fn.getcwd()
end

---Get the buffer from the filepath
---@param filepath string
---@return nil | number
function utils.get_buffer_from_filepath(filepath)
   local buffer = vim.fn.bufnr(filepath, true)
   if buffer == -1 then
      return nil
   end
   return buffer
end

---Validate args, if it is a string, convert it to a table
---split using comma or space
---@param args string | string[] | function List of args
---@return string[]
function utils.validate_args(args)
   if not args or args == "" then
      return {}
   end

   if type(args) == "function" then
      args = args()
   end

   assert(type(args) == "table" or type(args) == "string", "Args must be a string or a table")

   local result = {}

   if type(args) == 'string' then
      args = args:gsub(",", " ")
      local parsed_args = vim.split(args, ' ')

      -- Remove any empty space (case when has multiple spaces)
      for _, arg in ipairs(parsed_args) do
         if arg ~= '' then
            table.insert(result, arg)
         end
      end
   else
      result = args
   end

   return result
end

---Logger helper
---@param msg string
---@param log_level number
---@param opts table
function utils.notify(msg, log_level, opts)
   opts = opts or {}
   opts = utils.list_extend(opts, { title = "Pytest.nvim" })
   vim.schedule(function() vim.notify(msg, log_level, opts) end)
end

---Info logging
---@param msg string
function utils.info(msg)
   utils.notify(msg, vim.log.levels.INFO, { timeout = 3000 })
end

---Warning logging
---@param msg string
function utils.warn(msg)
   utils.notify(msg, vim.log.levels.WARN, { timeout = 3000 })
end

---Error logging
---@param msg string
function utils.error(msg)
   utils.notify(msg, vim.log.levels.ERROR, { timeout = 3000 })
end

return utils
