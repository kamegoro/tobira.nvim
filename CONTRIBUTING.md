# Contributing to tobira.nvim

Thank you for your interest in contributing!

## Getting started

### Prerequisites

- [Neovim](https://neovim.io/) 0.8+
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
  -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua'}"
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

### Formatting and linting

```bash
# Format
stylua lua/ plugin/

# Check format (what CI runs)
stylua --check lua/ plugin/

# Lint
selene lua/ plugin/
```

## Submitting a PR

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `stylua --check lua/ plugin/` and `selene lua/ plugin/` — both must pass
4. Write a PR title following [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat: add detection for x pattern`
   - `fix: handle edge case in logger`
   - `docs: update README`
5. Open the PR — a checklist will be posted automatically if this is your first contribution

## Adding a new detection pattern

Patterns live in two places:

**1. `lua/tobira/core/logger.lua`** — `handle_key()` detects the sequence and calls `suggest.queue()`

**2. `lua/tobira/core/graph.lua`** — `M.suggestions` defines the display text shown to the user

Both must be updated together. See the existing `f_repeat` and `dw_then_insert` patterns as reference.

## Commit message convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/).
Releases and the CHANGELOG are generated automatically from commit history.

```
feat: add detection for x → x → cgn pattern
fix: prevent duplicate suggestion in same session
docs: add CONTRIBUTING.md
chore: update ci workflow
```
