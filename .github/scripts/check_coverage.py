#!/usr/bin/env python3
"""Enforce 100% luacov coverage on tobira/core/ modules."""

import re
import sys
from typing import Iterable

_ENTRY_PATTERN = re.compile(r'(tobira/core/\w+\.lua)\s+(\d+)\s+(\d+)\s+([\d.]+)%')


def parse_report(lines: Iterable[str]) -> list[tuple[str, int, float]]:
    """Return [(path, missed_lines, pct), ...] for every core/ entry."""
    results = []
    for line in lines:
        m = _ENTRY_PATTERN.search(line)
        if m:
            results.append((m.group(1), int(m.group(3)), float(m.group(4))))
    return results


def check(entries: list[tuple[str, int, float]]) -> bool:
    """Print per-module status and return True if all pass."""
    if not entries:
        print('ERROR: No tobira/core/ entries found — check .luacov include patterns')
        return False

    passed = True
    for path, missed, pct in entries:
        mark = 'OK  ' if pct >= 100.0 else 'FAIL'
        print(f'[{mark}] {path}: {pct:.2f}% ({missed} line(s) missed)')
        if pct < 100.0:
            passed = False

    if passed:
        print(f'\nAll {len(entries)} core module(s): 100% ✓')
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

    sys.exit(0 if check(entries) else 1)


if __name__ == '__main__':
    main()
