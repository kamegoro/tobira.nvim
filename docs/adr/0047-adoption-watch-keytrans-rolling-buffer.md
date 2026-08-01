# Multi-char suggestion adoption detection via keytrans + rolling buffer

## Context

`vim.on_key()` fires once per raw keystroke, so a multi-char suggested command
(`cw`, `ddp`, `<C-r>`, `{n}j`) can't be detected with a simple `k == cmd` check on
any single callback invocation — by the time the last matching key arrives, there's
no record of the keys before it. Suggestions also need to detect three different
shapes of "the user did what was suggested": literal multi-char sequences (`cw`,
`ddp`), special keys sent as raw bytes (`<C-r>` arrives as `\x12`), and
count-prefixed motions (`{n}j` should match `3j`, `10j`, ... but not bare `j`).

## Decision

`watch_adoption(cmd)` registers a per-command `vim.on_key` watcher with its own
closure-local rolling buffer (`buf`, capped at `KEY_BUF_MAX` = 20 chars),
independent of every other watcher's buffer. Each keystroke is normalised with
`vim.fn.keytrans()` (which always uppercases the letter in `<C-x>`-style codes) via
`normalize_cmd`, appended to `buf`, and checked with `buf_matches`:

- Literal commands: `buf` must end with the literal `cmd` string.
- Count-prefix meta-commands (`cmd` matches `{n}<base>`): `buf` must end with
  `[1-9]%d*<base>` — a leading `0` doesn't count as a count prefix in Vim, so `0j`
  deliberately does not match `{n}j`.

The rolling-buffer approach is inspired by hardtime.nvim's technique (MIT
licensed) for reconstructing multi-key sequences from raw keystrokes.

## Consequences

- Each watcher owning its own buffer means adopting one suggested command can
  never interfere with detection of another suggested command shown around the
  same time.
- The 20-character cap bounds memory per watcher regardless of how many unrelated
  keys the user types before finally using (or not using) the suggested command.
- Any new suggestible command shape (beyond literal / special-key / count-prefix)
  needs a new case in `buf_matches`, not just a new registry entry.
