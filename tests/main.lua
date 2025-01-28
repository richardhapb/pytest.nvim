local core = require 'pytest.core'


local fake_expand = function(return_value)
   ---@diagnostic disable-next-line: duplicate-set-field
   vim.fn.expand = function()
      return return_value
   end
end


describe("Get failed details", function()
   local expand = vim.fn.expand

   it("should return the failed details", function()
      core.status.filename = nil
      fake_expand('test_views.py')

      local error = core._get_error_detail({
         'E   AssertionError: assert 1 == 2',
         '',
         'apps/core/tests/test_views.py:10: AssertionError'
      }
      , 1)

      assert.is.equal(9, error.line)
      assert.is.equal('AssertionError: assert 1 == 2', error.error)
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

      core.status.filename = nil
      fake_expand('test_middlewares.py')

      local error = core._get_error_detail(error_message, 1)
      assert.is.equal(73, error.line)
      assert.is.equal('ZeroDivisionError: division by zero', error.error)
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

      core.status.filename = nil
      fake_expand('test_memory_profiler.py')

      local error = core._get_error_detail(error_message, 1)

      assert.is.equal(0, error.line)
      assert.is.equal('ModuleNotFoundError: No module named "psutil"', error.error)
   end
   )

   vim.fn.expand = expand
end)

