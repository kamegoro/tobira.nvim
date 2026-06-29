#!/usr/bin/env python3
"""Diff two Neovim index.txt files and report command changes."""

import re
import sys
from typing import Iterable

_CMD_PATTERN = re.compile(r'^\|([^|]+)\|\s+(\S+)\s+(.*)')

Commands = dict[str, tuple[str, str]]
Diff = tuple[Commands, Commands, dict[str, tuple[tuple[str, str], tuple[str, str]]]]


def parse_commands(lines: Iterable[str]) -> Commands:
    """Return {tag: (key_seq, description)} for all command lines."""
    result: Commands = {}
    for line in lines:
        m = _CMD_PATTERN.match(line.rstrip())
        if m:
            tag = m.group(1)
            key = m.group(2)
            desc = m.group(3).strip()
            result[tag] = (key, desc)
    return result


def parse_file(path: str) -> Commands:
    try:
        with open(path, encoding='utf-8') as f:
            return parse_commands(f)
    except FileNotFoundError:
        return {}


def compute_diff(old: Commands, new: Commands) -> Diff:
    """Return (added, removed, changed)."""
    added = {t: new[t] for t in new if t not in old}
    removed = {t: old[t] for t in old if t not in new}
    changed = {
        t: (old[t], new[t])
        for t in old
        if t in new and old[t] != new[t]
    }
    return added, removed, changed


def format_report(old_ver: str, new_ver: str, added: Commands, removed: Commands, changed: dict) -> str:
    """Return a markdown report string, or empty string when there are no changes."""
    if not added and not removed and not changed:
        return ''

    out: list[str] = []
    out.append(f'Neovim `{old_ver}` → `{new_ver}` で `runtime/doc/index.txt` に変更がありました。')
    out.append('`lua/tobira/commands.lua` への追加・修正が必要なコマンドがあれば対応してください。')
    out.append('')

    if added:
        out.append(f'### 追加されたコマンド ({len(added)})')
        out.append('')
        for tag in sorted(added):
            key, desc = added[tag]
            out.append(f'- `{key}` — {desc}')
        out.append('')

    if changed:
        out.append(f'### 変更されたコマンド ({len(changed)})')
        out.append('')
        for tag in sorted(changed):
            (old_key, old_desc), (new_key, new_desc) = changed[tag]
            out.append(f'- `{new_key}`')
            if old_key != new_key:
                out.append(f'  - キー: `{old_key}` → `{new_key}`')
            if old_desc != new_desc:
                out.append(f'  - 旧: {old_desc}')
                out.append(f'  - 新: {new_desc}')
        out.append('')

    if removed:
        out.append(f'### 削除されたコマンド ({len(removed)})')
        out.append('')
        for tag in sorted(removed):
            key, desc = removed[tag]
            out.append(f'- `{key}` — {desc}')
        out.append('')

    return '\n'.join(out)


def main() -> None:
    if len(sys.argv) != 5:
        print('Usage: diff_index.py OLD_VER NEW_VER old.txt new.txt', file=sys.stderr)
        sys.exit(1)

    old_ver, new_ver, old_path, new_path = sys.argv[1:]
    old = parse_file(old_path)
    new = parse_file(new_path)
    added, removed, changed = compute_diff(old, new)
    report = format_report(old_ver, new_ver, added, removed, changed)
    if report:
        print(report)


if __name__ == '__main__':
    main()
