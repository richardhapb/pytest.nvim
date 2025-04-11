---@diagnostic disable: undefined-field, duplicate-set-field
local xml = require 'pytest.parse.xml'
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
   local stdout_local = io.open(vim.fs.joinpath('tests', 'fixtures', 'pytest_stdout_local.txt'), "r")
   local output_local = ""
   local stdout_docker = io.open(vim.fs.joinpath('tests', 'fixtures', 'pytest_stdout_docker.txt'), "r")
   local output_docker = ""
   local report_local_file = vim.fs.joinpath('tests', 'fixtures', 'pytest_report_local.xml')
   local report_local = io.open(report_local_file, "r")
   local report_output_local = ""
   local report_docker_file = vim.fs.joinpath('tests', 'fixtures', 'pytest_report_docker.xml')
   local report_docker = io.open(report_docker_file, "r")
   local report_output_docker = ""
   local test_results = {}

   if stdout_local then
      output_local = stdout_local:read("*a")
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

   it("Match local error results", function()
      xml.set_output_file(report_local_file)
      local parser = xml.XmlParser.new(vim.split(output_local, "\n", { plain = true }))

      if parser then
         test_results = parser:get_test_results()
      end

      local expected_lnums = { 149, 274 }

      local i = 1
      local messages = {}

      for message in report_output_local:gmatch('message="([^"]*)"') do
         table.insert(messages, message)
      end

      for _, test_result in ipairs(test_results) do
         if test_result.state == 'failed' then
            assert.is.equal(expected_lnums[i], test_result.failed_test.lnum)
            assert.is.True(compare_texts(
               vim.split(xml.decode_xml_entities(messages[i]:gsub("%s+", " ")), '\n', { plain = true }),
               test_result.failed_test.message))
            i = i + 1
         end
      end
   end)

   it("Match docker error results", function()
      xml.set_output_file(report_docker_file)
      local parser = xml.XmlParser.new(vim.split(output_docker, "\n", { plain = true }))

      if parser then
         test_results = parser:get_test_results()
      end

      local expected_lnums = { 51, 40 }

      local i = 1
      local messages = {}

      for message in report_output_docker:gmatch('message="([^"]*)"') do
         table.insert(messages, message)
      end

      for _, test_result in ipairs(test_results) do
         if test_result.state == 'failed' then
            assert.is.equal(expected_lnums[i], test_result.failed_test.lnum)
            assert.is.True(compare_texts(
               vim.split(xml.decode_xml_entities(messages[i]:gsub("%s+", " ")), '\n', { plain = true }),
               test_result.failed_test.message))
            i = i + 1
         end
      end

      -- Last test should be skipped
      assert.is.equal(test_results[#test_results].state, 'skipped')
      assert.is.equal(test_results[#test_results].function_name, 'test_save_interval')
   end)
end)
