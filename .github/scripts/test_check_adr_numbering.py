"""Unit tests for check_adr_numbering.py"""

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_adr_numbering import check, extract_number, find_adr_files, group_by_number


class TestExtractNumber(unittest.TestCase):
    def test_extracts_leading_number(self):
        self.assertEqual(extract_number('0001-terminal-mode-escape-streak.md'), '0001')

    def test_extracts_number_regardless_of_width(self):
        self.assertEqual(extract_number('12-some-slug.md'), '12')

    def test_returns_empty_string_when_no_leading_number(self):
        self.assertEqual(extract_number('README.md'), '')

    def test_returns_empty_string_for_number_not_at_start(self):
        self.assertEqual(extract_number('template-0000.md'), '')


class TestGroupByNumber(unittest.TestCase):
    def test_groups_unique_numbers_individually(self):
        groups = group_by_number(['0001-a.md', '0002-b.md'])
        self.assertEqual(groups['0001'], ['0001-a.md'])
        self.assertEqual(groups['0002'], ['0002-b.md'])

    def test_groups_colliding_numbers_together(self):
        groups = group_by_number(['0102-a.md', '0102-b.md'])
        self.assertCountEqual(groups['0102'], ['0102-a.md', '0102-b.md'])

    def test_files_without_a_number_land_in_empty_key(self):
        groups = group_by_number(['no-number-here.md'])
        self.assertEqual(groups[''], ['no-number-here.md'])


class TestCheck(unittest.TestCase):
    def test_returns_true_for_unique_numbers(self):
        self.assertTrue(check(['0001-a.md', '0002-b.md', '0003-c.md']))

    def test_returns_false_for_a_collision(self):
        self.assertFalse(check(['0001-a.md', '0102-b.md', '0102-c.md']))

    def test_returns_true_for_empty_input(self):
        self.assertTrue(check([]))

    def test_returns_false_when_a_file_has_no_leading_number(self):
        self.assertFalse(check(['0001-a.md', 'no-number-here.md']))

    def test_prints_ok_summary_when_all_pass(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            check(['0001-a.md', '0002-b.md'])
        self.assertIn('OK', buf.getvalue())
        self.assertIn('2 ADR', buf.getvalue())

    def test_prints_both_colliding_filenames_on_failure(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            check(['0102-builtin-default-mapping-sid-detection.md', '0102-text-object-variant-own-usage-tracking.md'])
        output = buf.getvalue()
        self.assertIn('0102-builtin-default-mapping-sid-detection.md', output)
        self.assertIn('0102-text-object-variant-own-usage-tracking.md', output)

    def test_reports_multiple_independent_collisions(self):
        self.assertFalse(
            check(['0001-a.md', '0001-b.md', '0002-c.md', '0002-d.md'])
        )

    def test_returns_false_for_same_number_with_mismatched_zero_padding(self):
        # '0009' and '9' are the same ADR number, just padded differently — the
        # "compute the next number" README snippet outputs an unpadded value,
        # so a filename typo'd without the leading zeros must still collide
        # with the padded original rather than silently coexisting.
        self.assertFalse(check(['0009-a.md', '9-b.md']))

    def test_prints_both_filenames_for_a_zero_padding_mismatch_collision(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            check(['0009-a.md', '9-b.md'])
        output = buf.getvalue()
        self.assertIn('0009-a.md', output)
        self.assertIn('9-b.md', output)

    def test_three_way_collision_lists_all_three(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            result = check(['0005-a.md', '0005-b.md', '0005-c.md'])
        self.assertFalse(result)
        output = buf.getvalue()
        for name in ('0005-a.md', '0005-b.md', '0005-c.md'):
            self.assertIn(name, output)


class TestFindAdrFiles(unittest.TestCase):
    def test_finds_numbered_adr_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            adr_dir = Path(tmp)
            (adr_dir / '0001-a.md').write_text('# a')
            (adr_dir / '0002-b.md').write_text('# b')

            found = find_adr_files(adr_dir)

            self.assertEqual(found, ['0001-a.md', '0002-b.md'])

    def test_excludes_readme_and_template(self):
        with tempfile.TemporaryDirectory() as tmp:
            adr_dir = Path(tmp)
            (adr_dir / '0001-a.md').write_text('# a')
            (adr_dir / 'README.md').write_text('# readme')
            (adr_dir / '0000-template.md').write_text('# template')

            found = find_adr_files(adr_dir)

            self.assertEqual(found, ['0001-a.md'])

    def test_ignores_non_markdown_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            adr_dir = Path(tmp)
            (adr_dir / '0001-a.md').write_text('# a')
            (adr_dir / 'notes.txt').write_text('scratch')

            found = find_adr_files(adr_dir)

            self.assertEqual(found, ['0001-a.md'])

    def test_returns_sorted_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            adr_dir = Path(tmp)
            (adr_dir / '0002-b.md').write_text('# b')
            (adr_dir / '0001-a.md').write_text('# a')

            found = find_adr_files(adr_dir)

            self.assertEqual(found, ['0001-a.md', '0002-b.md'])


if __name__ == '__main__':
    unittest.main()
