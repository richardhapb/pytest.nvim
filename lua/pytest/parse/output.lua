local pytest = require 'pytest.pytest'

---@class TestRoot
---@field name string
---@field type string
---@field pkgs? TestPkg[]
---
---@class TestPkg
---@field name? string
---@field type string
---@field pkgs? TestPkg[]
---@field modules? TestModule[]
---@field classes? TestClass[]

---@class TestModule
---@field name? string
---@field type string
---@field modules? TestModule[]
---@field classes? TestClass[]

---@class TestClass
---@field name? string
---@field type string
---@field functions? TestFunction[]

---@class TestFunction
---@field name? string
---@field type string

---Get the keywords used by `pytest` when it collects
---@return table
local function collect_keywords()
   return {
      ["<Dir"] = "root",
      ["<Package"] = "pkg",
      ["<Module"] = "module",
      ["<UnitTestCase"] = "class",
      ["<Class"] = "class",
      ["<TestCaseFunction"] = "function",
      ["<Function"] = "function",
   }
end

---Get the plural postfix for the element
---@param element_type string
---@return string
local function get_plural_postfix(element_type)
   return element_type == "class" and "es" or "s"
end

---Create an Test element instance of kind of element
---@param name string
---@param element_type string
---@return TestRoot | TestPkg | TestModule | TestClass | TestFunction
local function create_element_instance(name, element_type)
   return {
      name = name,
      type = element_type
   }
end


local function calculate_tab(line)
   return #(line:match("^%s*") or "")
end

---Insert a child into the parent in place
---@param parent TestRoot | TestPkg | TestModule | TestClass | TestFunction
---@param instance TestRoot | TestPkg | TestModule | TestClass | TestFunction | nil
---@param element_type string
---@return TestRoot | TestPkg | TestModule | TestClass | TestFunction
local function insert_child(parent, instance, element_type)
   local plural_post = get_plural_postfix(element_type)
   if not parent[element_type .. plural_post] then
      parent[element_type .. plural_post] = {}
   end
   table.insert(parent[element_type .. plural_post], instance)
   return parent
end

--- Parse the collected session and fill the data into the fields
--- This function calls itself recursively to traverse the tree
---@param lines string[]
---@param parent TestRoot | TestPkg | TestModule | TestClass | TestFunction
---@param spaces number
---@return TestRoot | TestPkg | TestModule | TestClass | TestFunction
local function parse_collect_section(lines, parent, spaces)
   local collect_kw = collect_keywords()
   local i = 1
   while i <= #lines do
      local line = lines[i]

      for pattern, element_type in pairs(collect_kw) do
         if line:find(pattern) then
            local line_spaces = calculate_tab(line)

            -- if the line is less indented than expected, return to let the caller insert as sibling
            if line_spaces < spaces then
               return parent
            end

            local name = line:match("<[^>]+%s([^>]+)>")
            local instance = create_element_instance(name, element_type)
            insert_child(parent, instance, element_type)

            i = i + 1

            -- Process potential children for this instance
            if i <= #lines and calculate_tab(lines[i]) > line_spaces then
               parse_collect_section(vim.list_slice(lines, i), instance, calculate_tab(lines[i]))
               -- Skip lines belonging to children
               while i <= #lines and calculate_tab(lines[i]) > line_spaces do
                  i = i + 1
               end
            end
            goto continue
         end
      end
      i = i + 1
      ::continue::
   end
   return parent
end

local function collect_tests(callback, opts)
   return pytest.collect_tests(function(collect)
      -- Filter only lines that start with '<'
      local lines = vim.split(collect, '\n', { plain = true })

      -- Filter only lines that start with '<'
      local filtered = vim.tbl_filter(function(line)
         return line:match("^%s*<")
      end, lines)

      local root = {
         name = "root",
         type = "root",
         pkgs = {},
         modules = {},
         classes = {},
         functions = {}
      }

      for i, line in ipairs(filtered) do
         if line:find("<Dir") then
            root =  parse_collect_section(vim.list_slice(filtered, i + 1), root, 0)
         end
      end

      vim.schedule(function() callback(root, opts) end)
   end)
end

return {
   parse_collect_section = parse_collect_section,
   collect_tests = collect_tests,
}
