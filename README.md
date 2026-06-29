# tobira.nvim

<p align="center">
  <a href="https://github.com/kamegoro/tobira.nvim/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/kamegoro/tobira.nvim/ci.yml?branch=main&label=CI&logo=github&style=flat"></a>
  <a href="https://github.com/kamegoro/tobira.nvim/actions/workflows/ci.yml"><img alt="Coverage" src="https://img.shields.io/badge/coverage-100%25%20(core%2F)-brightgreen?logo=lua&logoColor=white&style=flat"></a>
  <a href="https://github.com/neovim/neovim/releases/tag/v0.9.0"><img alt="Neovim" src="https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white&style=flat"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/kamegoro/tobira.nvim?color=blue&style=flat"></a>
</p>

<p align="center"><b>Open the next door in your Vim journey.</b></p>

<p align="center">
  tobira watches how you actually edit.<br>
  When it spots a pattern you could do better, it quietly shows you the one command that would have helped — right now, not someday.
</p>

<p align="center">
  <img src="docs/demo-suggest.gif" alt="tobira detects a repeated f-search and suggests ;" width="720" />
</p>

No quizzes. No interruptions. Just your habits, and the better path.

---

## ✨ How it works

- **Watches your keystrokes passively** — no config required, zero impact on your mappings
- **Detects inefficient patterns** — repeated `f`, hammering `j`, `dw`→`i` instead of `cw`, and more
- **Suggests the one better command** — shown once after a natural pause, up to 3 times per session
- **Tracks mastery by watching your behavior** — start using the suggestion and tobira notices, never shows it again
- **Filters to your level** — beginner commands first, advanced ones once you're ready

---

## 📺 Guide panel

<p align="center">
  <img src="docs/demo-guide.gif" alt=":TobiraGuide cheatsheet panel" width="720" />
</p>

`:TobiraGuide` opens a cheatsheet on the right side of the screen. Commands you've mastered show **✓** and reveal the next step with **→**. Shown automatically on first launch; adapts to context (shows file-tree shortcuts when neo-tree is active).

---

## 📊 Skill progress

<p align="center">
  <img src="docs/demo-progress.gif" alt=":TobiraProgress skill tree" width="720" />
</p>

`:TobiraProgress` shows your current level and the full learning graph. Press `x` on any row to permanently silence a suggestion you don't want.

---

## 🎯 Detected patterns

| You do this | tobira suggests |
|---|---|
| `fa` → `fa` on the same line | `;` — repeat the last f |
| `dw` → `i` (delete then retype) | `cw` / `ciw` |
| `x` × 3 in a row | `{n}x` — count prefix |
| `u` × 3 in a row | `<C-r>` — redo |
| `dd` → `p` | `ddp` — swap lines in one motion |
| `j` × 5 in a row | `{n}j` / `<C-d>` |
| `k` × 5 in a row | `{n}k` — count prefix |
| `0` → `w` | `^` — first non-blank character |
| `n` × 4 after a search | `cgn` — change next match |

---

## ⚡️ Installation

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

---

## ⚙️ Configuration

All options are optional — the defaults work out of the box.

```lua
require("tobira").setup({
  lang             = 'en',       -- 'en' | 'ja'
  idle_delay       = 1500,       -- ms to wait after a pattern before showing
  max_shown        = 3,          -- max times to suggest the same command
  max_per_session  = 3,          -- max auto-suggestions per Neovim session
  min_interval_ms  = 1800000,    -- min ms between auto-suggestions (default: 30 min)
})
```

---

## 🔧 Commands

| Command | Description |
|---|---|
| `:Tobira` | Show the next suggestion now (doesn't count toward the session limit) |
| `:TobiraGuide` | Toggle the cheatsheet panel |
| `:TobiraProgress` | Show skill tree with level and mastered commands |
| `:TobiraStats` | Show your command usage statistics |
| `:TobiraReset` | Clear all usage data |
| `:checkhealth tobira` | Verify the plugin is working correctly |

---

## 🔍 Requirements

- Neovim 0.9+
- [nvim-notify](https://github.com/rcarriga/nvim-notify) _(optional — suggestions fall back to `vim.notify` without it)_

---

## 🆚 Similar plugins

| Plugin | What it does | vs tobira |
|---|---|---|
| [hardtime.nvim](https://github.com/m4xshen/hardtime.nvim) | Blocks repeated keys, hints better motions | _Punishes_ bad habits — tobira teaches without ever blocking input |
| [precognition.nvim](https://github.com/tris203/precognition.nvim) | Shows available motions as virtual text | Always-on overlay — tobira appears only when _you_ would have benefited |
| [spamguard.nvim](https://github.com/timseriakov/spamguard.nvim) | Detects key spamming | Spam detection only — tobira covers the full command graph and tracks mastery |
| [pathfinder.vim](https://github.com/AlphaMycelium/pathfinder.vim) | Suggests more efficient cursor movement | Cursor movement only — tobira covers motion, edit, and search |
| [vim-be-good](https://github.com/ThePrimeagen/vim-be-good) | Game-based practice | Generic drills — tobira personalizes to your actual usage |

tobira is the only plugin that learns from **your actual usage** and shows you the specific commands _you_ are missing.

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). This project follows strict TDD — tests before implementation, always.

## License

MIT
