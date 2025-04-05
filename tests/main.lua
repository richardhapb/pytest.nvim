---@diagnostic disable: undefined-field, duplicate-set-field
local core = require 'pytest.core'
local async = require 'plenary.async'

---@class Mock
---@field func string
---@field calls table
---@field return_values table

---Wrap a test function to mock functions
---@param mocks Mock[]
---@param test function
local test_wrapper = function(mocks, test)
   for _, mock in ipairs(mocks) do
      mock.calls = mock.calls or {}

      local modules = vim.split(mock.func, '%.')

      Mock_func = function(...)
         table.insert(mock.calls, { ... })
         if #mock.return_values == 0 then
            return nil
         end

         return table.remove(mock.return_values, 1)
      end

      if #modules > 1 then
         local var = '_G["' .. vim.fn.join(modules, '"]["') .. '"]'

         local chunk = loadstring(var .. ' = Mock_func')

         if chunk then
            chunk()
         end
      else
         _G[mock.func] = Mock_func
      end
   end

   test()

   for _, mock in ipairs(mocks) do
      mock.calls = {}
      mock.return_values = {}
   end
end


describe("Get failed details", function()
   local expand = vim.fn.expand

   it("should return the failed details", function()
      core.state.filename = nil

      local mocks = {
         {
            func = 'vim.fn.expand',
            calls = {},
            return_values = {
               'test_views.py'
            }
         }
      }

      test_wrapper(mocks, function()
         local error = core._get_error_detail({
            'E   AssertionError: assert 1 == 2',
            '',
            'apps/core/tests/test_views.py:10: AssertionError'
         }
         , 1)

         assert.is.equal(9, error.line)
         assert.is.equal('AssertionError: assert 1 == 2', error.error)
      end)
   end)

   it("Get details in app exception", function()
      local error_message = {
         '______________________________________________ TestMemoryUsageMiddleware.test_memory_threshold _______________________________________________',
         '',
         'self = <apps.memory_usage.tests.test_middlewares.TestMemoryUsageMiddleware testMethod=test_memory_threshold>',
         'mock_logger = <MagicMock name="logger" id="281472809980352">, mock_take_snapshot = <MagicMock name="_take_snapshot" id="281472806253200">',
         '',
         '    @patch("memory_usage.middlewares.AppMemoryMiddleware._take_snapshot")',
         '    @patch("memory_usage.middlewares.logger")',
         '    @patch("memory_usage.middlewares.AppMemoryMiddleware.threshold_mb", 1)',
         '    def test_memory_threshold(self, mock_logger: MagicMock, mock_take_snapshot: MagicMock) -> None:',
         '        """Test that a warning is logged when memory threshold is exceeded or not, the condition is strictly greater than."""',
         '',
         '        mock_take_snapshot.side_effect = [{"size_mb": 10}, {"size_mb": 12}, {"size_mb": 12}, {"size_mb": 13}]',
         '',
         '        with self.settings(MEMORY_USAGE=True, DEBUG=True):',
         '>           self.client.get("/")',
         '',
         'apps/memory_usage/tests/test_middlewares.py:74:',
         '_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _',
         '/usr/local/lib/python3.12/site-packages/django/test/client.py:1049: in get',
         '    response = super().get(path, data=data, secure=secure, headers=headers, **extra)',
         '/usr/local/lib/python3.12/site-packages/django/test/client.py:465: in get',
         '    return self.generic(',
         '/usr/local/lib/python3.12/site-packages/django/test/client.py:617: in generic',
         '    return self.request(**r)',
         '/usr/local/lib/python3.12/site-packages/django/test/client.py:1013: in request',
         '    self.check_exception(response)',
         '/usr/local/lib/python3.12/site-packages/django/test/client.py:743: in check_exception',
         '    raise exc_value',
         '/usr/local/lib/python3.12/site-packages/django/core/handlers/exception.py:55: in inner',
         '    response = get_response(request)',
         '_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _',
         '',
         'self = <memory_usage.middlewares.AppMemoryMiddleware object at 0xffff7eae95e0>, request = <WSGIRequest: GET  /',
         '>',
         '',
         '    def __call__(self, request: HttpRequest):',
         '        if not settings.DEBUG or not getattr(settings, "MEMORY_USAGE", False):',
         '            return self.get_response(request)',
         '',
         '        # Take memory snapshot before request',
         '        before_snapshot = self._take_snapshot(request)',
         '',
         '        response = self.get_response(request)',
         '',
         '        # Take memory snapshot after request',
         '        after_snapshot = self._take_snapshot(request)',
         '',
         '        # Calculate difference in memory usage',
         '        initial_mb = before_snapshot.get("size_mb", 0)',
         '        final_mb = after_snapshot.get("size_mb", 0)',
         '        diff_mb = max(final_mb - initial_mb, 0)',
         '',
         '        current_app_usage = self.apps_usage[self.current_app]',
         '',
         '        current_app_usage.size_mb += diff_mb',
         '        current_app_usage.requests += 1',
         '',
         '        if diff_mb > self.threshold_mb:',
         '            logger.warning(',
         '                "Significant memory change for %s: %.2f MB", self.current_app, diff_mb',
         '            )',
         '',
         '        now = time.time()',
         '        if now - self.timer_init > MEMORY_USAGE_SAVE_INTERVAL_SECONDS:',
         '            self.insert_into_db()',
         '            self.timer_init = now',
         '            self.apps_usage.clear()',
         '',
         '        self.current_app = "unknown"',
         '',
         '>       hello = 1 / 0',
         'E       ZeroDivisionError: division by zero',
         '',
         'apps/memory_usage/middlewares.py:158: ZeroDivisionError',
         '------------------------------------------------------------ Captured stderr call ------------------------------------------------------------',
         '[ERROR] 2025-01-28 04:42:24 Internal Server Error: / [django.request] /usr/local/lib/python3.12/site-packages/django/utils/log.py log_response() #241',
         'Traceback (most recent call last):',
         '  File "/usr/local/lib/python3.12/site-packages/django/core/handlers/exception.py", line 55, in inner',
         '    response = get_response(request)',
         '               ^^^^^^^^^^^^^^^^^^^^^',
         '  File "/usr/src/app/dirtystroke/../apps/memory_usage/middlewares.py", line 158, in __call__',
         '    hello = 1 / 0',
         '            ~~^~~',
         'ZeroDivisionError: division by zero',
      }

      local mocks = {
         {
            func = 'vim.fn.expand',
            calls = {},
            return_values = { 'test_middlewares.py' }
         }
      }

      core.state.filename = nil

      test_wrapper(mocks, function()
         local error = core._get_error_detail(error_message, 1)
         assert.is.equal(73, error.line)
         assert.is.equal('ZeroDivisionError: division by zero', error.error)
      end)
   end)

   it('Execution error message on test', function()
      local error_message = {
         '========================================== test session starts ==========================================',
         'platform linux -- Python 3.12.4, pytest-8.3.4, pluggy-1.5.0 -- /usr/local/bin/python',
         'cachedir: .pytest_cache',
         'django: version: 5.0.6, settings: dirtystroke.settings (from env)',
         'rootdir: /usr/src/app',
         'configfile: pyproject.toml',
         'testpaths: apps, dirtystroke',
         'plugins: django-4.9.0',
         'collected 5 items / 2 errors',
         '',
         '================================================ ERRORS =================================================',
         '____________________ ERROR collecting apps/memory_usage/tests/test_memory_pofiler.py ____________________',
         'ImportError while importing test module "/usr/src/app/apps/memory_usage/tests/test_memory_pofiler.py".',
         'Hint: make sure your test modules/packages have valid Python names.',
         'Traceback:',
         '/usr/local/lib/python3.12/site-packages/_pytest/python.py:493: in importtestmodule',
         '    mod = import_path(',
         '/usr/local/lib/python3.12/site-packages/_pytest/pathlib.py:587: in import_path',
         '    importlib.import_module(module_name)',
         '/usr/local/lib/python3.12/importlib/__init__.py:90: in import_module',
         '    return _bootstrap._gcd_import(name[level:], package, level)',
         '<frozen importlib._bootstrap>:1387: in _gcd_import',
         '    ???',
         '<frozen importlib._bootstrap>:1360: in _find_and_load',
         '    ???',
         '<frozen importlib._bootstrap>:1331: in _find_and_load_unlocked',
         '    ???',
         '<frozen importlib._bootstrap>:935: in _load_unlocked',
         '    ???',
         '/usr/local/lib/python3.12/site-packages/_pytest/assertion/rewrite.py:184: in exec_module',
         '    exec(co, module.__dict__)',
         'apps/memory_usage/tests/test_memory_pofiler.py:7: in <module>',
         '    from memory_usage.middlewares import AppMemoryProfiler, AppUsage',
         'apps/memory_usage/middlewares.py:6: in <module>',
         '    import psutil',
         'E   ModuleNotFoundError: No module named "psutil"',
         '_____________________ ERROR collecting apps/memory_usage/tests/test_middlewares.py ______________________',
         'ImportError while importing test module "/usr/src/app/apps/memory_usage/tests/test_middlewares.py".',
         'Hint: make sure your test modules/packages have valid Python names.',
         'Traceback:',
         '/usr/local/lib/python3.12/site-packages/_pytest/python.py:493: in importtestmodule',
         '    mod = import_path(',
         '/usr/local/lib/python3.12/site-packages/_pytest/pathlib.py:587: in import_path',
         '    importlib.import_module(module_name)',
         '/usr/local/lib/python3.12/importlib/__init__.py:90: in import_module',
         '    return _bootstrap._gcd_import(name[level:], package, level)',
         '<frozen importlib._bootstrap>:1387: in _gcd_import',
         '    ???',
         '<frozen importlib._bootstrap>:1360: in _find_and_load',
         '    ???',
         '<frozen importlib._bootstrap>:1331: in _find_and_load_unlocked',
         '    ???',
         '<frozen importlib._bootstrap>:935: in _load_unlocked',
         '    ???',
         '/usr/local/lib/python3.12/site-packages/_pytest/assertion/rewrite.py:184: in exec_module',
         '    exec(co, module.__dict__)',
         'apps/memory_usage/tests/test_middlewares.py:4: in <module>',
         '    from memory_usage.middlewares import AppMemoryMiddleware',
         'apps/memory_usage/middlewares.py:6: in <module>',
         '    import psutil',
         'E   ModuleNotFoundError: No module named "psutil"',
         '======================================== short test summary info ========================================',
         'ERROR apps/memory_usage/tests/test_memory_pofiler.py',
         'ERROR apps/memory_usage/tests/test_middlewares.py',
         '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 2 errors during collection !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
      }

      local mocks = {
         {
            func = 'vim.fn.expand',
            calls = {},
            return_values = { 'test_memory_profiler.py' }
         },
      }

      core.state.filename = nil
      test_wrapper(mocks, function()
         local error = core._get_error_detail(error_message, 1)

         assert.is.equal(-1, error.line)
         assert.is.equal('ModuleNotFoundError: No module named "psutil"', error.error)
      end)
   end
   )

   it('Execution error message with description', function()
      local error_message = {
         '__________________________________ TestProfileViews.test_profile_view ___________________________________',
         '',
         'self = <apps.users.tests.test_profile_views.TestProfileViews testMethod=test_profile_view>',
         '',
         '    CONSTANT_WITH_E    This is a fake error that not should be captured',
         '    def test_profile_view(self):',
         '        response = self.client.get("/profiles")',
         '        self.assertEqual(response.status_code, 301)',
         '>       self.assertTemplateUsed(response, "apps/users/profiles/profiles.html")',
         '',
         'apps/users/tests/test_profile_views.py:16:',
         '_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _',
         '/usr/local/lib/python3.12/site-packages/django/test/testcases.py:712: in assertTemplateUsed',
         '    self._assert_template_used(template_name, template_names, msg_prefix, count)',
         '/usr/local/lib/python3.12/site-packages/django/test/testcases.py:677: in _assert_template_used',
         '    self.assertTrue(',
         'E   AssertionError: False is not true : Template "apps/users/profiles/profiles.html" was not a template used to render the response. Actual template(s) used: errors/404.html, base/base_public.html, base/head.html, base/bottom_sources.html, base/bottom_sources.html',
         '----------------------------------------- Captured stderr setup -----------------------------------------',
         'Using existing test database for alias "default" ("test_dirtystroke_dev")...',
         '----------------------------------------- Captured stderr call ------------------------------------------',
         '------------------------------------------- Captured log call -------------------------------------------',
         '======================================== short test summary info ========================================',
         'FAILED apps/users/tests/test_profile_views.py::TestProfileViews::test_profile_view - AssertionError: False is not true : Template "apps/users/profiles/profiles.html" was not a template used to render the response. Actual template(s) used: errors/404.html, base/base_public.html, base/head.html, base/bottom_sources.html, base/bottom_sources.html',
         '=========================================== 1 failed in 4.85s ===========================================',
      }

      local mocks = {
         {
            func = 'vim.fn.expand',
            calls = {},
            return_values = { 'test_profile_views.py' }
         },
      }

      core.state.filename = nil
      test_wrapper(mocks, function()
         local error = core._get_error_detail(error_message, 1)

         assert.is.equal(15, error.line)
         assert.is.equal(
            'AssertionError: False is not true : Template "apps/users/profiles/profiles.html" was not a template used to render the response. Actual template(s) used: errors/404.html, base/base_public.html, base/head.html, base/bottom_sources.html, base/bottom_sources.html',
            error.error)
      end)
   end)

   it('Execution error message with two outputs', function()
      local error_message = {
         '============================= test session starts ==============================',
         'platform linux -- Python 3.12.4, pytest-8.3.4, pluggy-1.5.0 -- /usr/local/bin/python',
         'cachedir: .pytest_cache',
         'django: version: 5.0.6, settings: dirtystroke.settings (from env)',
         'rootdir: /usr/src/app',
         'configfile: pyproject.toml',
         'plugins: django-4.9.0',
         'collecting ... collected 1 item',
         '',
         'apps/users/tests/test_profile_views.py::TestProfileViews::test_get_profiles_sorting_with_filter_mixed FAILED',
         '',
         '=================================== FAILURES ===================================',
         '_________ TestProfileViews.test_get_profiles_sorting_with_filter_mixed _________',
         '',
         'self = <apps.users.tests.test_profile_views.TestProfileViews testMethod=test_get_profiles_sorting_with_filter_mixed>',
         'mock_get_online_profiles_ids = <MagicMock name="get_online_profiles_ids" id="133463546688432">',
         '',
         '    @patch("users.views.profile_viewing.Profile.get_online_profiles_ids")',
         '    def test_get_profiles_sorting_with_filter_mixed(self, mock_get_online_profiles_ids: MagicMock):',
         '        """',
         '        Test the order and filtering of profiles, including valid values and next page detection',
         '    ',
         '        Consider the following behaviors:',
         '    ',
         '        - The order of profiles should follow the preset order in get_profiles_display_group_settings',
         '        - The filtering of profiles should adhere to the filters in get_profiles_display_group_settings',
         '        - The profile list should contain only Profile instances, excluding None',
         '        - The has_more_profiles should be True as there are more profiles to display in this test',
         '        - The next_page should be an integer as there are more profiles to display in this test',
         '        """',
         '        # Mock for testing online profiles',
         '        mock_get_online_profiles_ids.return_value = [103, 90, 125, 71, 100]',
         '    ',
         '        page = 1',
         '        has_more_profiles = True',
         '        request = MagicMock()',
         '        request.session = self.client.session',
         '        profiles_view = profile_viewing.ProfilesView()',
         '    ',
         '        matches = Profile.matches.find_matches_for_profile(',
         '            profile=self.profile,',
         '            is_guest_user=False',
         '        ).annotate(',
         '            distance=Distance("location", self.profile.location)',
         '        ).order_by("distance")',
         '    ',
         '        excluded_profiles = []',
         '        while page is not None:',
         '            profiles_list, has_more_profiles, page = profiles_view.get_profiles_sorting_with_filter_mixed(',
         '                request, matches, page',
         '            )',
         '    ',
         '            # Verify each groups positions contain correct profiles',
         '            for profiles_display_group_key, settings in (profiles_view.get_profiles_display_group_settings(matches)).items():',
         '                filters = settings["filters"]',
         '                order_by_fields = settings["order_by_fields"]',
         '    ',
         '                filtered_profiles = (',
         '                     matches',
         '                    .filter(**filters)',
         '                    .exclude(id__in=excluded_profiles)',
         '                    .order_by(*order_by_fields)',
         '                    .distinct()',
         '                )',
         '    ',
         '                filtered_profiles_list = list(filtered_profiles)',
         '                total_positions_out_of_range = len([position for position in settings["positions"] if position >= len(profiles_list)])',
         '                total_positions_to_extract = min(len(settings["positions"]) - total_positions_out_of_range, len(filtered_profiles_list), len(profiles_list))',
         '    ',
         '                filtered_profiles_ids = [profile.id for profile in filtered_profiles_list]',
         '    ',
         '                for position, filtered_profile in zip(',
         '                    settings["positions"][:total_positions_to_extract],',
         '                    filtered_profiles_list[:total_positions_to_extract],',
         '                    strict=True',
         '                ):',
         '    ',
         '                    self.assertIn(',
         '                        profiles_list[position],',
         '                        filtered_profiles_list,',
         '                        f"Profile at position {position} should belong to group {profiles_display_group_key}"',
         '                    )',
         '    ',
         '>                   self.assertEqual(',
         '                        profiles_list[position], filtered_profile,',
         '                        f"Profile at position {position} should be the same to than filtered profiles in group {profiles_display_group_key}"',
         '                    )',
         'E                   AssertionError: <Profile: Profile_366> != <Profile: Profile_438> : Profile at position 0 should be the same to than filtered profiles in group profiles_view_new_with_photo',
         '',
         'apps/users/tests/test_profile_views.py:103: AssertionError',
         '=========================== short test summary info ============================',
         'FAILED apps/users/tests/test_profile_views.py::TestProfileViews::test_get_profiles_sorting_with_filter_mixed - AssertionError: <Profile: Profile_366> != <Profile: Profile_438> : Profile at position 0 should be the same to than filtered profiles in group profiles_view_new_with_photo',
         '============================== 1 failed in 1.61s ===============================',

      }

      local mocks = {
         {
            func = 'vim.fn.expand',
            calls = {},
            return_values = { 'test_profile_views.py' }
         },
      }

      core.state.filename = nil
      test_wrapper(mocks, function()
         local error = core._get_error_detail(error_message, 1)

         assert.is.equal(102, error.line)
         assert.is.equal(
            'AssertionError: <Profile: Profile_366> != <Profile: Profile_438> : Profile at position 0 should be the same to than filtered profiles in group profiles_view_new_with_photo',
            error.error)
      end)
   end)

   it("Pytest without docker and Django", function()
      local error_message = {
         '============================= test session starts ==============================',
         'platform darwin -- Python 3.12.4, pytest-8.3.5, pluggy-1.5.0 -- /Users/richard/proj/antof_traffic/client/.venv/bin/python',
         'cachedir: .pytest_cache',
         'rootdir: /Users/richard/proj/antof_traffic/client',
         'configfile: pyproject.toml',
         'plugins: dash-2.18.2',
         'collecting ... collected 7 items',
         '',
         'tests/test_utils.py::test_get_data PASSED                                [ 14%]',
         'tests/test_utils.py::test_get_data_multiple FAILED                       [ 28%]',
         'tests/test_utils.py::test_update_timezone PASSED                         [ 42%]',
         'tests/test_utils.py::test_separate_coords PASSED                         [ 57%]',
         'tests/test_utils.py::test_freq_nearby PASSED                             [ 71%]',
         'tests/test_utils.py::test_hourly_group SKIPPED (unconditional skip)      [ 85%]',
         'tests/test_utils.py::test_daily_group SKIPPED (unconditional skip)       [100%]',
         '',
         '=================================== FAILURES ===================================',
         '____________________________ test_get_data_multiple ____________________________',
         '',
         'mock_alerts = <MagicMock name="Alerts" id="4573593680">',
         '',
         '    @patch("utils.utils.Alerts")',
         '    def test_get_data_multiple(mock_alerts: MagicMock):',
         '        """',
         '        Test multiple requests for data in a short period of time',
         '    ',
         '        Simulate behavior in the graph when multiple requests are made',
         '        """',
         '        now = datetime.datetime.now(pytz.UTC)',
         '        since = int((now - datetime.timedelta(days=30)).timestamp()) * 1000',
         '        until = int((now - datetime.timedelta(minutes=MINUTES_BETWEEN_UPDATES_FROM_API)).timestamp()) * 1000',
         '    ',
         '        mock_alerts.return_value = Alerts(generate_alerts_data())',
         '    ',
         '        calls_when_retrieve_last_instance = 1',
         '    ',
         '        for i in range(4):',
         '            alerts = utils.get_data(since, until)',
         '            assert isinstance(alerts, Alerts)',
         '            assert not alerts.is_empty',
         '            assert alerts.data.shape[0] > 0',
         '            if i > 0:',
         '>               assert mock_alerts.call_count == calls_when_retrieve_last_instance',
         'E               AssertionError: assert 2 == 1',
         'E                +  where 2 = <MagicMock name="Alerts" id="4573593680">.call_count',
         '',
         'tests/test_utils.py:125: AssertionError',
         '=========================== short test summary info ============================',
         'FAILED tests/test_utils.py::test_get_data_multiple - AssertionError: assert 2 == 1',
         ' +  where 2 = <MagicMock name="Alerts" id="4573593680">.call_count',
         '==================== 1 failed, 4 passed, 2 skipped in 1.40s ====================',

      }

      local mocks = {
         {
            func = 'vim.fn.expand',
            calls = {},
            return_values = { 'test_utils.py' }
         },
      }

      core.state.filename = nil
      test_wrapper(mocks, function()
         local error = core._get_error_detail(error_message, 1)

         assert.is.equal(124, error.line)
         assert.is.equal(
            'AssertionError: assert 2 == 1',
            error.error)
      end)
   end)

   vim.fn.expand = expand
   -- tests/my_plugin_spec.lua
   -- async.tests.describe("Test function", function()
   --    local calls = {}
   --
   --    async.tests.it("should call the function", function()
   --       test_wrapper({
   --          {
   --             func = 'vim.notify',
   --             calls = calls,
   --             return_values = {}
   --          }
   --       }, function()
   --          core.test_file()
   --       end)
   --       assert.are.same({ { 'Test passed' } }, calls)
   --    end)
   -- end)
end)
