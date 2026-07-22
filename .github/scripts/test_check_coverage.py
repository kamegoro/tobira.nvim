"""Unit tests for check_coverage.py"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_coverage import check, find_lua_files, parse_report


SAMPLE_REPORT = """\
File                                    Hits Missed    Coverage
--------------------------------------------------
lua/tobira/core/config.lua              22      0      100.00%
lua/tobira/core/graph.lua               91      0      100.00%
lua/tobira/core/suggest.lua             47      3       94.00%
lua/tobira/init.lua                     18      1       94.44%
"""


class TestParseReport(unittest.TestCase):
    def test_parses_core_entries(self):
        entries = parse_report(SAMPLE_REPORT.splitlines())
        paths = [e[0] for e in entries]
        self.assertIn('tobira/core/config.lua', paths)
        self.assertIn('tobira/core/graph.lua', paths)
        self.assertIn('tobira/core/suggest.lua', paths)

    def test_includes_non_core_tobira_entries(self):
        entries = parse_report(SAMPLE_REPORT.splitlines())
        paths = [e[0] for e in entries]
        self.assertIn('tobira/init.lua', paths)

    def test_extracts_missed_and_pct(self):
        entries = parse_report(SAMPLE_REPORT.splitlines())
        suggest = next(e for e in entries if 'suggest' in e[0])
        self.assertEqual(suggest[1], 3)
        self.assertAlmostEqual(suggest[2], 94.0)

    def test_returns_empty_for_blank_input(self):
        self.assertEqual(parse_report([]), [])


class TestCheck(unittest.TestCase):
    def test_returns_true_when_all_pass(self):
        entries = [
            ('tobira/core/config.lua', 0, 100.0),
            ('tobira/core/graph.lua', 0, 100.0),
        ]
        self.assertTrue(check(entries))

    def test_returns_false_when_any_fails(self):
        entries = [
            ('tobira/core/config.lua', 0, 100.0),
            ('tobira/core/suggest.lua', 3, 94.0),
        ]
        self.assertFalse(check(entries))

    def test_returns_false_for_empty_entries(self):
        self.assertFalse(check([]))

    def test_prints_ok_for_passing_modules(self, ):
        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            check([('tobira/core/config.lua', 0, 100.0)])
        self.assertIn('[OK  ]', buf.getvalue())

    def test_prints_fail_for_failing_modules(self):
        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            check([('tobira/core/suggest.lua', 3, 94.0)])
        self.assertIn('[FAIL]', buf.getvalue())

    def test_fails_when_a_real_file_is_missing_from_the_report(self):
        # A file that exists on disk (e.g. because it was never require()'d by
        # any test) must not be silently treated as "100% covered" just
        # because luacov never emitted a report entry for it.
        entries = [
            ('tobira/core/config.lua', 0, 100.0),
            ('tobira/core/graph.lua', 0, 100.0),
        ]
        all_files = {
            'tobira/core/config.lua',
            'tobira/core/graph.lua',
            'tobira/ui/guide.lua',  # never appears in the luacov report
        }
        self.assertFalse(check(entries, all_files))

    def test_passes_when_all_real_files_are_in_the_report(self):
        entries = [
            ('tobira/core/config.lua', 0, 100.0),
            ('tobira/core/graph.lua', 0, 100.0),
        ]
        all_files = {'tobira/core/config.lua', 'tobira/core/graph.lua'}
        self.assertTrue(check(entries, all_files))

    def test_prints_untested_file_as_failing(self):
        import io
        from contextlib import redirect_stdout
        entries = [('tobira/core/config.lua', 0, 100.0)]
        all_files = {'tobira/core/config.lua', 'tobira/ui/guide.lua'}
        buf = io.StringIO()
        with redirect_stdout(buf):
            check(entries, all_files)
        self.assertIn('tobira/ui/guide.lua', buf.getvalue())
        self.assertIn('[FAIL]', buf.getvalue())

    def test_without_all_files_argument_behavior_is_unchanged(self):
        # Backwards-compatible default: callers that don't pass a real file
        # list get the old entries-only behavior.
        entries = [('tobira/core/config.lua', 0, 100.0)]
        self.assertTrue(check(entries))


class TestFindLuaFiles(unittest.TestCase):
    def test_finds_lua_files_under_tobira_dir_recursively(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / 'lua' / 'tobira'
            (base / 'core').mkdir(parents=True)
            (base / 'ui').mkdir()
            (base / 'init.lua').write_text('return {}')
            (base / 'core' / 'config.lua').write_text('return {}')
            (base / 'ui' / 'guide.lua').write_text('return {}')

            found = find_lua_files(base)

            self.assertEqual(
                found,
                {
                    'tobira/init.lua',
                    'tobira/core/config.lua',
                    'tobira/ui/guide.lua',
                },
            )

    def test_ignores_non_lua_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / 'lua' / 'tobira'
            base.mkdir(parents=True)
            (base / 'init.lua').write_text('return {}')
            (base / 'README.md').write_text('# not lua')

            found = find_lua_files(base)

            self.assertEqual(found, {'tobira/init.lua'})


if __name__ == '__main__':
    unittest.main()
