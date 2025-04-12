local parse_output = require 'pytest.parse.output'
local putils = require 'pytest.parse.utils'
local runner = require 'pytest.runner'

TAB_SPACES = 1

ICONS = {
   ["root"] = "🏗️",
   ["pkg"] = "📦",
   ["module"] = "🗃️",
   ["class"] = "🧪",
   ["function"] = "⚙️",
}

---Create a floating window with a buffer
---@return integer window number
---@return integer buffer number
local function build_buffer()
   local width = math.floor(vim.o.columns * 0.5)
   local height = math.floor(vim.o.lines * 0.5)

   local col = width * 0.5
   local row = height * 0.5

   local win_config = {
      relative = 'win',
      border = 'rounded',
      focusable = true,
      col = col,
      row = row,
      width = width,
      height = height,
      style = 'minimal',
      title = "Available tests"
   }

   local buf = vim.api.nvim_create_buf(false, true)
   local win = vim.api.nvim_open_win(buf, true, win_config)

   return win, buf
end

---Match the icon according to element_type
---@param element_type string
---@return string
local function get_icon(element_type)
   if not element_type or element_type == "" then
      return ""
   end

   return ICONS[element_type] or ""
end

---Verify the children of an element recursively
---@param parent TestRoot | TestPkg | TestModule | TestClass | TestFunction
---@param lines string[] destination table
---@param spaces integer length of tab
---@return string[] Deserialized objects as a hierarchy list
local function check_for_childs(parent, lines, spaces)
   local gap = string.rep(' ', spaces)
   if parent.name then
      table.insert(lines, gap .. get_icon(parent.type) .. parent.name)
   end

   for _, child in pairs(parent) do
      if type(child) == "table" and next(child) then
         check_for_childs(child, lines, spaces + TAB_SPACES)
      end
   end

   return lines
end

---Removes UI icons from a test path string
---@param path string The path containing potential UI icons
---@return string The cleaned path without UI icons
local function sanitize_string(path)
   for _, icon in pairs(ICONS) do
      path = path:gsub(icon, "")
   end

   return path
end

---Builds a full test path from a hierarchical list of test elements
---@param lines table Array of strings representing the test hierarchy
---@param index number The current line index in the hierarchy
---@return string The complete test path including both file path and test identifiers
local function build_test_path(lines, index)
   local top_lines = vim.list_slice(lines, 1, index)
   local path_elements = {}
   local test_elements = {}
   local is_path = false

   local current_line = vim.trim(lines[index])

   if current_line:find(".*%.py$") then
      is_path = true
   end

   local function insert_element(element)
      if is_path then
         table.insert(path_elements, 1, element)
      else
         table.insert(test_elements, 1, element)
      end
   end

   insert_element(current_line)

   local line_tab = putils.calculate_tab(lines[index])
   local level = line_tab / TAB_SPACES

   local i = #top_lines
   while i > 1 do
      local line = top_lines[i]
      local tab = putils.calculate_tab(line)
      line = vim.trim(line)


      vim.trim(lines[index])

      if tab / TAB_SPACES < level then
         if line:find(".*%.py$") then
            is_path = true
         end
         insert_element(line)
         level = tab / TAB_SPACES
      end

      if level == 0 then
         break
      end

      i = i - 1
   end

   if not is_path then
      path_elements = test_elements
      test_elements = {}
   end

   -- Pytest uses :: to denote nested tests after the filename
   local test_string = #test_elements > 0 and "::" .. table.concat(test_elements, '::') or ""
   return sanitize_string(vim.fs.joinpath(unpack(path_elements)) .. test_string)
end

---Writes the test hierarchy to a buffer and sets up key mappings
---@param tests_tree table The tree structure of tests to display
---@param opts table Configuration options containing:
---  - buf: integer Buffer handle
---  - win: integer Window handle
local function write_buffer(tests_tree, opts)
   local tests = check_for_childs(tests_tree, {}, 0)

   vim.api.nvim_buf_set_lines(opts.buf, 0, -1, false, tests)

   -- Run selected test with <CR>
   vim.keymap.set('n', '<CR>', function()
      local row = unpack(vim.api.nvim_win_get_cursor(opts.win))
      local test_path = build_test_path(tests, row)
      runner.test_element(test_path, nil, function(_, results)
         local state = "passed"
         for _, result in ipairs(results) do
            if state == "failed" then
               break
            end

            if result.state ~= "passed" then
               state = result.state
            end
         end

         putils.update_marks(opts.buf, { { state = state, function_lnum = row - 1 } })
      end)
   end, { noremap = true, buffer = opts.buf })
end

---Creates a floating window and loads all project tests into it
---@return nil
local function load_project()
   local win, buf = build_buffer()
   local opts = { buf = buf, win = win }
   parse_output.collect_tests(write_buffer, opts)
end

return {
   load_project = load_project
}
