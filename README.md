<div align="center">

# 🚪 tobira.nvim

**Learn the next Vim command from your own editing habits — not a cheat sheet.**

tobira watches how you actually edit, and when it spots a pattern you could do better,
it quietly shows you the one command that would have helped. No quizzes. No interruptions.

<a href="https://github.com/kamegoro/tobira.nvim/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/kamegoro/tobira.nvim/ci.yml?branch=main&label=CI&logo=github&style=flat"></a>
<a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat"></a>
<a href="https://github.com/kamegoro/tobira.nvim/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/kamegoro/tobira.nvim?style=flat&logo=github&color=yellow"></a>
<a href="https://dotfyle.com/plugins/kamegoro/tobira.nvim"><img alt="Dotfyle" src="https://dotfyle.com/plugins/kamegoro/tobira.nvim/shield?style=flat"></a>

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Configuration](#-configuration) • [vs hardtime.nvim](#-similar-plugins)

<img src="docs/demo-suggest.gif" alt="tobira detects a repeated f-search and suggests ;" width="720" />

</div>

---

## ✨ Features

- 👀 **Fully passive** — reads keystrokes via `vim.on_key()`; no config required, zero impact on your existing mappings
- 🎯 **34 detected patterns** — repeated `f`, hammering `j`, `dw`→`i` instead of `cw`, and more across motion, edit, search, window, fold, mark, and macro
- 💬 **One suggestion at a time** — shown after a natural pause, capped per session, with a cooldown between auto-suggestions — never a popup quiz
- 📈 **Mastery-aware** — once you've used a command ~100 times, tobira stops suggesting it and moves on
- 🪜 **Level-aware** — beginner commands surface first, advanced ones once you're ready
- 🗺️ **148 commands** in the learning graph, covering the full Neovim command surface

## ⚡️ Requirements

- Neovim 0.9+
- [nvim-notify](https://github.com/rcarriga/nvim-notify) _(optional — suggestions fall back to `vim.notify` without it)_

## 📦 Installation

**lazy.nvim**
```lua
{
  "kamegoro/tobira.nvim",
  event = "VeryLazy",
  opts = {},
}
```

**packer.nvim**
```lua
use {
  "kamegoro/tobira.nvim",
  config = function()
    require("tobira").setup()
  end,
}
```

## 🚀 Usage

| Command | Description |
|---|---|
| `:Tobira` | Show the next suggestion now (ignores cooldown). Press `q` / `Esc` to dismiss. |
| `:TobiraGuide` | Toggle the cheatsheet panel |
| `:TobiraProgress` | Show skill tree with mastery glyphs. `x` = suppress, `p` = pin, `q`/`Esc` = close. |
| `:TobiraStats` | Show usage stats: command distribution (never/tried/familiar/mastered) and efficiency gap suggestions |
| `:TobiraReset` | Clear all usage data |

Full documentation is available in Neovim via `:help tobira`.

<details>
<summary><b>📸 Screenshots — Guide, Stats &amp; Progress panels</b></summary>

### Guide panel

<p align="center">
  <img src="docs/demo-guide.gif" alt=":TobiraGuide cheatsheet panel" width="720" />
</p>

`:TobiraGuide` opens a cheatsheet on the right side of the screen. Commands you've already mastered are automatically hidden, so only your next targets are shown. Pinned commands always appear at the top. Covers all 7 categories: motion, edit, search, window, fold, mark, and macro. Opens automatically on first launch.

### Usage stats

<p align="center">
  <img src="docs/demo-stats.gif" alt=":TobiraStats usage stats" width="720" />
</p>

`:TobiraStats` shows a snapshot of your editing habits: total keystrokes, how many commands you've discovered out of the full graph, a mastery bar, your top 8 most-used commands, and the top 5 efficiency gaps — commands you're using heavily whose neighbors you've never tried.

### Skill progress

<p align="center">
  <img src="docs/demo-progress.gif" alt=":TobiraProgress skill tree" width="720" />
</p>

`:TobiraProgress` shows your current level and the full command learning graph, with mastery glyphs on every command:

| Glyph | Meaning |
|---|---|
| _(blank)_ | Not yet tried |
| `☆` | Tried (1+ uses) |
| `★` | Familiar (100+ uses) |
| `★★` | Practiced (1000+ uses) |
| `★★★` | Mastered (5000+ uses) |
| `✗` | Suppressed — you don't want this suggested |
| `*` | Pinned — always shown at the top of `:TobiraGuide` |

**Keys inside `:TobiraProgress`:** `x` toggles suppress on the command under the cursor, `p` toggles pin, `q` / `Esc` closes.

</details>

## ⚙️ Configuration

All options are optional — the defaults work out of the box.

```lua
require("tobira").setup({
  lang                = 'en',    -- 'en' | 'ja'
  idle_delay          = 1500,    -- ms of inactivity before showing an ambient suggestion
  idle_suggestions    = true,    -- enable ambient idle suggestions
  suggestion_cooldown = 300,     -- s between automatic suggestions (default: 5 min)
  max_shown           = 2,       -- max times to suggest the same command per session
})
```

## 🎯 Detected patterns (examples)

| You do this | tobira suggests |
|---|---|
| `fa` → `fa` on the same line | `;` — repeat the last f/t |
| `dw` → `i` | `cw` — change word in one command |
| `v` `i` `w` `c` | `ciw` — text object, no visual needed |
| `j` × 10 in a row | `}` — jump by paragraph |
| `dd` × 3 in a row | `{n}dd` — delete N lines at once |
| `r{x}` × 3 in a row | `R` — enter replace mode |

34 patterns total — see `:help tobira-patterns` for the full list.

## 🆚 Similar plugins

| Plugin | What it does | vs tobira |
|---|---|---|
| [hardtime.nvim](https://github.com/m4xshen/hardtime.nvim) | Blocks repeated keys, hints better motions | _Punishes_ bad habits — tobira teaches without ever blocking input |
| [precognition.nvim](https://github.com/tris203/precognition.nvim) | Shows available motions as virtual text | Always-on overlay — tobira appears only when _you_ would have benefited |
| [spamguard.nvim](https://github.com/timseriakov/spamguard.nvim) | Detects key spamming | Spam detection only — tobira covers the full command graph and tracks mastery |
| [pathfinder.vim](https://github.com/AlphaMycelium/pathfinder.vim) | Suggests more efficient cursor movement | Cursor movement only — tobira covers motion, edit, and search |
| [vim-be-good](https://github.com/ThePrimeagen/vim-be-good) | Game-based practice | Generic drills — tobira personalizes to your actual usage |

tobira is the only plugin that learns from **your actual usage** and shows you the specific commands _you_ are missing.

## 🦾 Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). This project follows strict TDD — tests before implementation, always.

<a href="https://github.com/kamegoro/tobira.nvim/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=kamegoro/tobira.nvim" alt="Contributors to tobira.nvim" />
</a>

## License

MIT

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=kamegoro/tobira.nvim&type=Date)](https://star-history.com/#kamegoro/tobira.nvim&Date)
