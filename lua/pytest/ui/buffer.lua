local parse_output = require 'pytest.parse.output'

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

   local win = vim.api.nvim_win
   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_open_win(buf, true, win_config)

   return win, buf
end

---Match the icon according to element_type
---@param element_type string
---@return string
local function get_icon(element_type)
   if not element_type or element_type == "" then
      return ""
   end

   local icons = {
      ["root"] = "🏗️",
      ["pkg"] = "📦",
      ["module"] = "🗃️",
      ["class"] = "🧪",
      ["function"] = "⚙️",
   }

   return icons[element_type] or ""
end

---Verify the children of an element recursively
---@param parent TestRoot | TestPkg | TestModule | TestClass | TestFunction
---@param lines string[]
---@param spaces integer
---@return string[] Deserialized objects as a hierarchy list
local function check_for_childs(parent, lines, spaces)
   local gap = string.rep(' ', spaces)
   if parent.name then
      table.insert(lines, gap .. get_icon(parent.type) .. parent.name)
   end

   for _, child in pairs(parent) do
      if type(child) == "table" and next(child) then
         check_for_childs(child, lines, spaces + 1)
      end
   end

   return lines
end

--- Write the buffer with the elements tree
---@param tests_tree table
---@param opts table
local function write_buffer(tests_tree, opts)
   local lines = {}
   local tests = check_for_childs(tests_tree, lines, 0)

   vim.api.nvim_buf_set_lines(opts.buf, 0, -1, false, tests)
end

--- Load all tests of the projects and store them in a buffer
local function load_project()
   local win, buf = build_buffer()
   local opts = { buf = buf, win = win }
   parse_output.collect_tests(write_buffer, opts)
end

return {
   load_project = load_project
}
