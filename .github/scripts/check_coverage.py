#!/usr/bin/env python3
"""Enforce 100% luacov coverage on all tobira/ modules."""

import re
import sys
from pathlib import Path
from typing import Iterable, Optional, Set

_ENTRY_PATTERN = re.compile(r'(tobira/[\w/]+\.lua)\s+(\d+)\s+(\d+)\s+([\d.]+)%')


def parse_report(lines: Iterable[str]) -> list[tuple[str, int, float]]:
    """Return [(path, missed_lines, pct), ...] for every tobira/ entry."""
    results = []
    for line in lines:
        m = _ENTRY_PATTERN.search(line)
        if m:
            results.append((m.group(1), int(m.group(3)), float(m.group(4))))
    return results


def find_lua_files(base_dir: Path) -> Set[str]:
    """Return {'tobira/...', ...} for every *.lua file under base_dir (lua/tobira).

    This is the ground truth of what actually exists on disk, independent of
    whether luacov ever loaded/executed the file. A file that is never
    require()'d by any test never gets a report entry at all — comparing the
    report against this list is how we catch that silent gap.
    """
    return {f'tobira/{p.relative_to(base_dir).as_posix()}' for p in base_dir.rglob('*.lua')}


def check(
    entries: list[tuple[str, int, float]],
    all_files: Optional[Set[str]] = None,
) -> bool:
    """Print per-module status and return True if all pass.

    If `all_files` is given, any file present on disk but absent from
    `entries` (i.e. luacov never produced a report entry for it, typically
    because no test ever require()'d it) is treated as an untested failure
    rather than being silently ignored.
    """
    if not entries:
        print('ERROR: No tobira/ entries found — check .luacov include patterns')
        return False

    passed = True
    reported_paths = {path for path, _, _ in entries}
    for path, missed, pct in entries:
        mark = 'OK  ' if pct >= 100.0 else 'FAIL'
        print(f'[{mark}] {path}: {pct:.2f}% ({missed} line(s) missed)')
        if pct < 100.0:
            passed = False

    missing = sorted((all_files or set()) - reported_paths)
    for path in missing:
        print(f'[FAIL] {path}: never required by any test (0.00%, no coverage data)')
        passed = False

    total = len(entries) + len(missing)
    if passed:
        print(f'\nAll {total} module(s): 100% ✓')
    else:
        print('\nCoverage gate FAILED. Add tests for the missed lines above.')
    return passed


def main() -> None:
    report_path = sys.argv[1] if len(sys.argv) > 1 else 'luacov.report.out'
    try:
        with open(report_path, encoding='utf-8') as f:
            entries = parse_report(f)
    except FileNotFoundError:
        print(f'ERROR: {report_path} not found — was coverage collected?')
        sys.exit(1)

    repo_root = Path(__file__).resolve().parent.parent.parent
    all_files = find_lua_files(repo_root / 'lua' / 'tobira')

    sys.exit(0 if check(entries, all_files) else 1)


if __name__ == '__main__':
    main()
