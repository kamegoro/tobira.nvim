# Contributing to tobira.nvim

Thank you for your interest in contributing!

## Getting started

### Prerequisites

- [Neovim](https://neovim.io/) 0.9+
- [stylua](https://github.com/JohnnyMorganz/StyLua) — Lua formatter
- [selene](https://github.com/Kampfkarren/selene) — Lua linter

Install via cargo:
```bash
cargo install stylua
cargo install selene
```

Or via Homebrew:
```bash
brew install stylua
brew install selene
```

### Running tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

### Coverage (100% required)

CI's `coverage` job enforces **100% statement coverage** on every `lua/tobira/` module via
luacov, gated by `.github/scripts/check_coverage.py`. A PR that drops coverage below 100%
will fail CI even if every test passes. Run it locally before opening a PR:

```bash
rm -f luacov.stats.out luacov.report.out
COVERAGE=1 nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
~/.luarocks/bin/luacov
grep 'Total' luacov.report.out           # must read 100.00%
python3 .github/scripts/check_coverage.py luacov.report.out
```

Coverage below 100% means one of two things — fix whichever applies:
- Lines are reachable but untested → write the test
- Lines are unreachable (dead code) → delete the code

Using `-- luacov: disable` to hide the gap is prohibited.

### CI helper script tests

`.github/scripts/check_coverage.py` and `.github/scripts/diff_index.py` are covered by their
own Python unit tests (`.github/scripts/test_check_coverage.py`, `test_diff_index.py`), run by
CI's `checks` job. If you touch either script, run this locally too:

```bash
python3 -m unittest discover -s .github/scripts -p "test_*.py" -v
```

### `git blame` and comment-cleanup commits

Commits that are purely comment/docs cleanup (see `docs/adr/README.md`) get their SHA
added to `.git-blame-ignore-revs` so they don't stand between you and the commit that
actually last changed a line's meaning. This isn't automatic — opt in once locally:

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

### Manual testing

Use `NVIM_APPNAME` to isolate from your personal config:

```bash
NVIM_APPNAME=tobira_test nvim
```

Then in that Neovim instance:
```lua
-- Add tobira.nvim to runtimepath
vim.opt.rtp:prepend("/path/to/tobira.nvim")
require("tobira").setup({})
```

### Regenerating demo GIFs

`bash docs/make-demo.sh` uses [VHS](https://github.com/charmbracelet/vhs). If you get a GIF with the wrong
colors (yellow-green instead of navy Catppuccin Mocha), **do not spend time debugging VHS/Chrome flags** —
see [`docs/RECORDING.md`](docs/RECORDING.md) for why, and for a working browser-free alternative.

### Formatting and linting

```bash
# Format
stylua lua/ plugin/

# Check format (what CI runs)
stylua --check lua/ plugin/

# Lint
selene lua/ plugin/
```

## Test-Driven Development (TDD) — mandatory

This project follows strict TDD. **No implementation code without a failing test first.**

### The cycle

```
1. Red   — write a test that fails
2. Green — write the minimum code to make it pass
3. Refactor — clean up, keeping tests green
```

### Rules

- **New detection pattern** → write the test first, in the unit spec matching the mode the
  pattern fires in (see the table below), before touching the corresponding `patterns*.lua`
  module. `graph_spec.lua` is a different concern — see "What requires a test" below.
- **Bug fix** → write a test that reproduces the bug first, then fix it
- **PRs without tests for new behavior will not be merged**
- Tests must pass on both Neovim stable and nightly before opening a PR

### Test structure

```
tests/
├── minimal_init.lua          # plenary bootstrap
├── CLAUDE.md                 # authoritative test-routing reference
└── spec/
    ├── unit/                 # pure Lua logic, no vim.* — fast
    │   ├── patterns_spec.lua          # normal-mode pattern detection
    │   ├── patterns_insert_spec.lua   # insert-mode pattern detection
    │   ├── patterns_cmdline_spec.lua  # cmdline pattern detection
    │   ├── patterns_terminal_spec.lua # terminal-mode pattern detection
    │   ├── graph_spec.lua             # graph.suggestions scoring/field validation
    │   └── ...
    └── integration/          # vim.* APIs, runs inside Neovim
        ├── logger_spec.lua   # usage tracking, mode dispatch
        └── suggest_spec.lua  # session state, module interaction
```

(Not exhaustive — see `tests/spec/` for the full current list, ~21 spec files.)

**Unit tests** (`tests/spec/unit/`): pure Lua, no `vim.*`. Test logic in isolation.

**Integration tests** (`tests/spec/integration/`): require Neovim. Test that modules interact correctly with the Neovim runtime.

### What requires a test

| Change | Required test |
|---|---|
| New normal-mode pattern in `patterns.lua` | `patterns_spec.lua`: unit test for the pure function |
| New insert-mode pattern in `patterns_insert.lua` | `patterns_insert_spec.lua`: unit test for the pure function |
| New cmdline (Ex-command) pattern in `patterns_cmdline.lua` | `patterns_cmdline_spec.lua`: unit test for the pure function |
| New terminal-mode pattern in `patterns_terminal.lua` | `patterns_terminal_spec.lua`: unit test for the pure function |
| New entry in `graph.suggestions` | `graph_spec.lua`: verify required fields, scoring |
| Data management change in `logger.lua` | `logger_spec.lua`: verify mark/get/reset behavior |
| Changes to suppression/cooldown logic in `suggest.lua` | `suggest_spec.lua`: verify show/suppress behavior |
| Bug fix | New test reproducing the bug |

See `tests/CLAUDE.md` for the authoritative, up-to-date version of this table.

## Submitting a PR

> **Every PR must be linked to an issue.** Open an issue first if one doesn't exist.

1. Fork the repo and create a branch from `main`
2. Make your changes
3. All of the following must pass locally before opening the PR — this mirrors every job
   in `.github/workflows/ci.yml` (`checks`, `test`, `coverage`):
   - `stylua --check lua/ plugin/`
   - `selene --display-style=quiet lua/ plugin/`
   - `python3 -m unittest discover -s .github/scripts -p "test_*.py" -v` (only if you touched `.github/scripts/`)
   - The full plenary test suite (see "Running tests" above)
   - 100% coverage (see "Coverage" above)
4. Write a PR title following [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat: add detection for x pattern`
   - `fix: handle edge case in logger`
   - `docs: update README`
5. Open the PR — a checklist will be posted automatically if this is your first contribution

## Adding a new detection pattern

Detection and display are two separate concerns, in separate files — don't conflate them.

**1. Detection** lives in one of four pure-Lua pattern modules, chosen by which mode the
pattern fires in:

- `lua/tobira/core/patterns.lua` — normal-mode operator grammar (most patterns live here)
- `lua/tobira/core/patterns_insert.lua` — insert-mode key streaks (#99)
- `lua/tobira/core/patterns_cmdline.lua` — cmdline / Ex-command patterns (#57)
- `lua/tobira/core/patterns_terminal.lua` — terminal-mode key patterns (#110)

`lua/tobira/core/logger.lua` does **not** do detection itself. It only dispatches each
keystroke to whichever pattern module matches the current mode (normal/insert/cmdline/terminal),
then relays whatever the pattern module returns via an `on_pattern` callback. See
`lua/tobira/CLAUDE.md`'s module dependency graph for the full picture.

**2. Display text** (title/body/example shown to the user) is **not** stored in `graph.lua`.
It lives in `lua/tobira/locales/*.lua` (all 6 locale files — en/ja/de/es/fr/zh), looked up at
display time by `lua/tobira/ui/float.lua` / `lua/tobira/ui/progress.lua`. `graph.lua`'s own
header comment states this explicitly.

Both must be updated together: add the detection to the matching `patterns*.lua` module (with
a unit test — see "What requires a test" above), then add its display strings to every locale
file. See the existing `f_repeat` (`patterns.lua`) and `insert_bs_repeat` (`patterns_insert.lua`)
patterns as reference.

## Architecture Decision Records (ADRs)

Non-obvious design decisions — the "why we chose this over the alternatives" history — live
as short files in `docs/adr/`, not as prose comments in the code. If you're making a design
choice that a future contributor would reasonably ask "why is it done this way?" about, add an
ADR rather than a long inline comment block. See `docs/adr/README.md` for the format (MADR-minimal:
Context / Decision / Consequences) and `lua/tobira/CLAUDE.md`'s "ADR pointer convention" section
for how modules link back to their ADRs with a one-line pointer comment.

## Commit message convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/).
Releases and the CHANGELOG are generated automatically from commit history.

```
feat: add detection for x → x → cgn pattern
fix: prevent duplicate suggestion in same session
docs: add CONTRIBUTING.md
chore: update ci workflow
```
