"""Unit tests for diff_index.py"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from diff_index import compute_diff, format_report, parse_commands, parse_file


class TestParseCommands(unittest.TestCase):
    def test_parses_normal_command_line(self):
        lines = ['|n_dd|	dd		delete [count] lines\n']
        result = parse_commands(lines)
        self.assertEqual(result, {'n_dd': ('dd', 'delete [count] lines')})

    def test_ignores_header_and_blank_lines(self):
        lines = [
            '\n',
            'Tag\t\tChar\t\tNormal-mode action\n',
            '----\n',
            '|n_x|\tx\t\tdelete character\n',
        ]
        result = parse_commands(lines)
        self.assertEqual(list(result.keys()), ['n_x'])

    def test_strips_trailing_whitespace_from_description(self):
        lines = ['|n_p|\tp\t\tput text   \n']
        result = parse_commands(lines)
        self.assertEqual(result['n_p'][1], 'put text')

    def test_returns_empty_dict_for_empty_input(self):
        self.assertEqual(parse_commands([]), {})

    def test_parse_file_returns_empty_for_missing_file(self):
        self.assertEqual(parse_file('/nonexistent/path.txt'), {})


class TestComputeDiff(unittest.TestCase):
    def _cmds(self, *pairs):
        """Build Commands dict from (tag, key, desc) triples."""
        return {tag: (key, desc) for tag, key, desc in pairs}

    def test_detects_added_commands(self):
        old = self._cmds(('n_x', 'x', 'delete char'))
        new = self._cmds(('n_x', 'x', 'delete char'), ('n_X', 'X', 'delete char before'))
        added, removed, changed = compute_diff(old, new)
        self.assertEqual(list(added.keys()), ['n_X'])
        self.assertEqual(removed, {})
        self.assertEqual(changed, {})

    def test_detects_removed_commands(self):
        old = self._cmds(('n_x', 'x', 'delete char'), ('n_X', 'X', 'delete char before'))
        new = self._cmds(('n_x', 'x', 'delete char'))
        added, removed, changed = compute_diff(old, new)
        self.assertEqual(added, {})
        self.assertEqual(list(removed.keys()), ['n_X'])
        self.assertEqual(changed, {})

    def test_detects_changed_description(self):
        old = self._cmds(('n_gt', 'gt', 'go to next tab page'))
        new = self._cmds(('n_gt', 'gt', 'go to next tabpage'))
        added, removed, changed = compute_diff(old, new)
        self.assertEqual(added, {})
        self.assertEqual(removed, {})
        self.assertIn('n_gt', changed)
        self.assertEqual(changed['n_gt'], (('gt', 'go to next tab page'), ('gt', 'go to next tabpage')))

    def test_detects_changed_key(self):
        old = self._cmds(('n_bufdo', ':bufdo', 'execute in each buffer'))
        new = self._cmds(('n_bufdo', ':bufd[o]', 'execute in each buffer'))
        added, removed, changed = compute_diff(old, new)
        self.assertIn('n_bufdo', changed)

    def test_no_diff_when_identical(self):
        cmds = self._cmds(('n_x', 'x', 'delete char'), ('n_p', 'p', 'put text'))
        added, removed, changed = compute_diff(cmds, cmds)
        self.assertEqual(added, {})
        self.assertEqual(removed, {})
        self.assertEqual(changed, {})


class TestFormatReport(unittest.TestCase):
    def test_returns_empty_string_when_no_changes(self):
        self.assertEqual(format_report('v1', 'v2', {}, {}, {}), '')

    def test_report_includes_version_header(self):
        added = {'n_X': ('X', 'delete char before cursor')}
        report = format_report('v0.10.0', 'v0.11.0', added, {}, {})
        self.assertIn('v0.10.0', report)
        self.assertIn('v0.11.0', report)

    def test_added_section_lists_commands(self):
        added = {'n_X': ('X', 'delete char before cursor')}
        report = format_report('v1', 'v2', added, {}, {})
        self.assertIn('### 追加されたコマンド (1)', report)
        self.assertIn('`X` — delete char before cursor', report)

    def test_removed_section_lists_commands(self):
        removed = {'n_old': ('Q', 'old command')}
        report = format_report('v1', 'v2', {}, removed, {})
        self.assertIn('### 削除されたコマンド (1)', report)
        self.assertIn('`Q` — old command', report)

    def test_changed_section_shows_desc_diff(self):
        changed = {'n_gt': (('gt', 'go to next tab page'), ('gt', 'go to next tabpage'))}
        report = format_report('v1', 'v2', {}, {}, changed)
        self.assertIn('### 変更されたコマンド (1)', report)
        self.assertIn('旧: go to next tab page', report)
        self.assertIn('新: go to next tabpage', report)

    def test_changed_section_shows_key_diff(self):
        changed = {'n_buf': ((':bufdo', 'exec'), (':bufd[o]', 'exec'))}
        report = format_report('v1', 'v2', {}, {}, changed)
        self.assertIn('キー: `:bufdo` → `:bufd[o]`', report)

    def test_omits_unchanged_sections(self):
        added = {'n_X': ('X', 'desc')}
        report = format_report('v1', 'v2', added, {}, {})
        self.assertNotIn('削除されたコマンド', report)
        self.assertNotIn('変更されたコマンド', report)

    def test_multiple_added_commands_are_sorted(self):
        added = {'z_cmd': ('z', 'z desc'), ('a_cmd'): ('a', 'a desc')}
        report = format_report('v1', 'v2', added, {}, {})
        a_pos = report.index('`a`')
        z_pos = report.index('`z`')
        self.assertLess(a_pos, z_pos)


if __name__ == '__main__':
    unittest.main()
