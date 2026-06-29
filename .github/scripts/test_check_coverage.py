"""Unit tests for check_coverage.py"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_coverage import check, parse_report


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

    def test_ignores_non_core_entries(self):
        entries = parse_report(SAMPLE_REPORT.splitlines())
        paths = [e[0] for e in entries]
        self.assertNotIn('tobira/init.lua', paths)

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


if __name__ == '__main__':
    unittest.main()
