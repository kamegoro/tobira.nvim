#!/usr/bin/env python3
"""Fail CI if two docs/adr/*.md files share the same NNNN number prefix.

This is the automated version of the audit that caught #284: two PRs
(#274, #277) independently picked the same next-free ADR number (0102) and
both merged, because nothing checked for the collision before merge. See
docs/adr/README.md for the "always compute the next number from the actual
directory" convention this check backstops.
"""

import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List

_NUMBER_PATTERN = re.compile(r'^(\d+)-')
_EXCLUDED_NAMES = {'README.md', '0000-template.md'}


def extract_number(filename: str) -> str:
    """Return the leading NNNN numeric prefix of an ADR filename, or '' if absent."""
    m = _NUMBER_PATTERN.match(filename)
    return m.group(1) if m else ''


def find_adr_files(adr_dir: Path) -> List[str]:
    """Return sorted ADR filenames under adr_dir, excluding README/template."""
    return sorted(
        p.name for p in adr_dir.glob('*.md') if p.name not in _EXCLUDED_NAMES
    )


def group_by_number(filenames: Iterable[str]) -> Dict[str, List[str]]:
    """Group filenames by their leading NNNN prefix.

    Filenames with no numeric prefix are grouped under the empty-string key so
    callers can flag them too, rather than silently dropping them.
    """
    groups: Dict[str, List[str]] = defaultdict(list)
    for name in filenames:
        groups[extract_number(name)].append(name)
    return groups


def check(filenames: Iterable[str]) -> bool:
    """Print collision report and return True if every ADR number is unique."""
    groups = group_by_number(filenames)

    passed = True

    missing_number = sorted(groups.get('', []))
    if missing_number:
        passed = False
        print('ERROR: file(s) with no leading NNNN number prefix:')
        for name in missing_number:
            print(f'  - {name}')

    collisions = {
        number: sorted(names)
        for number, names in groups.items()
        if number != '' and len(names) > 1
    }
    if collisions:
        passed = False
        print('ERROR: duplicate ADR number(s) found:')
        for number in sorted(collisions):
            print(f'  {number}:')
            for name in collisions[number]:
                print(f'    - {name}')
        print(
            '\nRenumber one of each colliding pair to the next free number '
            '(see docs/adr/README.md).'
        )

    if passed:
        total = sum(len(names) for names in groups.values())
        print(f'OK: {total} ADR(s), no numbering collisions')

    return passed


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent.parent
    adr_dir = repo_root / 'docs' / 'adr'
    filenames = find_adr_files(adr_dir)
    sys.exit(0 if check(filenames) else 1)


if __name__ == '__main__':
    main()
