---@diagnostic disable: undefined-field, duplicate-set-field
local parse = require 'pytest.parse'
vim.opt.rtp:append(vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "nvim-treesitter"))

require 'pytest'.setup()

local compare_texts = function(table1, table2)
   local equal = true
   for i, line1 in ipairs(table1) do
      if table2[i] ~= line1 then
         equal = false
         break
      end
   end

   return equal
end


describe("Get failed details", function()
   local stdout_local = io.open(vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'pytest_stdout_local.txt'), "r")
   local output_local = ""
   local stdout_docker = io.open(vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'pytest_stdout_docker.txt'), "r")
   local output_docker = ""
   local report_local_file = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'pytest_report_local.xml')
   local report_local = io.open(report_local_file, "r")
   local report_output_local = ""
   local report_docker_file = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'pytest_report_docker.xml')
   local report_docker = io.open(report_docker_file, "r")
   local report_output_docker = ""
   local test_results = {}

   if stdout_local then
      output_local = stdout_local:read("*a"), "\n", { plain = true }
      stdout_local:close()
   end

   if stdout_docker then
      output_docker = stdout_docker:read("*a")
      stdout_docker:close()
   end

   if report_local then
      report_output_local = report_local:read("*a")
      report_local:close()
   end

   if report_docker then
      report_output_docker = report_docker:read("*a")
      report_docker:close()
   end

   it("Match local error resutls", function()
      parse.set_output_file(report_local_file)
      local parser = parse.XmlParser.new(vim.split(output_local, "\n", { plain = true }))
      if parser then
         test_results = parser:get_test_results()
      end

      local expected_lnums = { 149, 274 }
      local expected_messages = { "assert 3 &lt; 0",
         "AssertionError: assert not True&#10; +  where True = hasattr(                                   uuid  ...                           geometry\n0  16272ee8-9a60-4dea-a4b1-76a8281732d4  ...  POINT (-7835709.939 -2708222.708)\n1  3ed960c0-13e9-441d-baf9-7a27181c35a4  ...  POINT (-7836296.593 -2707541.801)\n2  f51a5fbc-1a4a-4a36-9c4e-b8c67598e1f3  ...  POINT (-7836074.399 -2698175.727)\n\n[3 rows x 17 columns], 'group')&#10; +    where                                    uuid  ...                           geometry\n0  16272ee8-9a60-4dea-a4b1-76a8281732d4  ...  POINT (-7835709.939 -2708222.708)\n1  3ed960c0-13e9-441d-baf9-7a27181c35a4  ...  POINT (-7836296.593 -2707541.801)\n2  f51a5fbc-1a4a-4a36-9c4e-b8c67598e1f3  ...  POINT (-7836074.399 -2698175.727)\n\n[3 rows x 17 columns] = &lt;analytics.alerts.Alerts object at 0x7fb938dfb020&gt;.data" }

      local i = 1
      for _, test_result in ipairs(test_results) do
         if test_result.state == 'failed' then
            assert.is.equal(expected_lnums[i], test_result.failed_test.lnum)
            vim.print(test_result.failed_test.message)
            vim.print(vim.split(parse.decode_xml_entities(expected_messages[i]:gsub("%s+", " ")), '\n', { plain = true }))
            assert.is.True(compare_texts(
               vim.split(parse.decode_xml_entities(expected_messages[i]:gsub("%s+", " ")), '\n', { plain = true }),
               test_result.failed_test.message))
            i = i + 1
         end
      end
   end)
end)
