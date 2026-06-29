# tobira.nvim

> Open the next door in your Vim journey.

**tobira** (扉) means "door" in Japanese.

<p align="center">
  <img src="docs/demo.gif" alt="tobira.nvim demo" width="720" />
</p>

Once you're comfortable with Vim, you stop actively learning new commands — you just use the ones you already know. tobira watches how you actually work, and when it notices you're doing something the hard way, it quietly shows you the better path.

No generic tip lists. No quizzes. Just _your_ habits, and the one command that would've helped you just now.

---

## How it works

```
You press f  →  then f  again on the same line
                          ↓
              tobira notices the repeated search
                          ↓  (1.5 seconds later)

  ╭─ tobira / ; — repeat the last f ──────── ℹ ─╮
  │ After f{char}, press ; to jump to the next   │
  │ occurrence. , goes in the reverse direction. │
  │                                              │
  │ e.g. fx;;                                    │
  ╰──────────────────────────────────────────────╯
```

Suggestions appear as notifications (compatible with [nvim-notify](https://github.com/rcarriga/nvim-notify) — no dependency required).

- Waits for a natural pause before showing — never interrupts your flow
- Shows up to **3 times per session**, with at least 30 minutes between each
- `:Tobira` to get a suggestion on demand (doesn't count toward the session limit)
- If you start using the suggested command → **learned**, never shown again
- Open `:TobiraProgress` and press `x` to permanently silence any suggestion you don't want

---

## Guide panel

On first launch, tobira shows a cheatsheet on the right side of the screen for new users:

```
  ╭──────── ℹ tobira guide ────────────────────╮
  │                                            │
  │  Motion                                    │
  │  ✓ h j k l   move cursor                  │
  │     → <C-d> / <C-u>  scroll half page     │
  │  ✓ f{char}   jump to character             │
  │     → ;  repeat last f                     │
  │     w / b    next / prev word              │
  │     0 / $    line start / end              │
  │     gg / G   file top / bottom             │
  │                                            │
  │  Edit                                      │
  │  ✓ i         insert mode                   │
  │     → a / o / O  append / new line         │
  │     Esc       back to normal mode          │
  │     dd        delete line                  │
  │     yy / p    copy / paste line            │
  │     u / <C-r> undo / redo                  │
  │                                            │
  │  :TobiraGuide  toggle guide                │
  ╰────────────────────────────────────────────╯
```

- Shown automatically on first launch only
- Stays behind other windows — never interrupts your workflow
- As you use commands, mastered items show **✓** and the next-level command appears below with **→**
- `:TobiraGuide` to open / close at any time
- Adapts to context: shows file-tree shortcuts when neo-tree is active

---

## Skill progress

`:TobiraProgress` shows your current level and which commands you have learned:

```
╭──── ℹ  tobira — your vim journey ────╮
│                                       │
│  Level: intermediate                  │
│                                       │
│  Motion                               │
│  ✓ hjkl    ✓ w/b     ○ gg/G          │
│  ✓ f/t     ○ ;/,     ○ <C-d/u>       │
│                                       │
│  Edit                                 │
│  ✓ i/a/o   ✓ x/dd    ✓ yy/p          │
│  ✓ u/<C-r> ○ cw/ciw  ✗ ddp           │
│                                       │
│  Search                               │
│  ✓ /+n     ○ */#     ○ cgn           │
│                                       │
│  Next: ; — repeat the last f          │
│                                       │
│  [x]  suppress / unsuppress  [q / Esc]  close  │
╰───────────────────────────────────────╯
```

- `✓` learned  `○` not yet introduced  `✗` suppressed (press `x` to toggle)
- Level is detected automatically from your usage — no quizzes, no setup.
- `:Tobira` suggestions are filtered to your current level — no advanced commands until you're ready.

---

## Detected patterns

| You do this | tobira suggests |
|---|---|
| `fa` → `fa` on the same line | `;` (repeat last f) |
| `dw` → `i` (delete then insert) | `cw` / `ciw` |
| `x` × 3 in a row | `{n}x` (count prefix) |
| `u` × 3 in a row | `<C-r>` (redo) |
| `dd` → `p` | `ddp` (swap lines) |
| `j` × 5 in a row | `{n}j` / `<C-d>` |
| `0` → `w` | `^` (first non-blank) |
| `n` × 3 after search | `cgn` (change next match) |

---

## Installation

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

## Configuration

```lua
require("tobira").setup({
  lang             = 'en',      -- 'en' | 'ja' (default: 'en')
  idle_delay       = 1500,      -- ms to wait after a pattern before showing (default: 1500)
  max_shown        = 3,         -- max times to show a suggestion before moving on (default: 3)
  max_per_session  = 3,         -- max auto-suggestions per session (default: 3)
  min_interval_ms  = 1800000,   -- min ms between auto-suggestions, 30 min (default: 1800000)
})
```

---

## Commands

| Command | Description |
|---|---|
| `:Tobira` | Show the next suggestion now |
| `:TobiraGuide` | Toggle the cheatsheet panel (adapts to context + mastery) |
| `:TobiraProgress` | Show skill tree with level and learned commands |
| `:TobiraStats` | Show your command usage statistics |
| `:TobiraReset` | Clear all usage data |
| `:checkhealth tobira` | Verify the plugin is set up correctly |

---

## Requirements

- Neovim 0.9+
- [nvim-notify](https://github.com/rcarriga/nvim-notify) _(optional — suggestions fall back to `vim.notify` without it)_

---

## Similar plugins

| Plugin | What it does | vs tobira |
|---|---|---|
| [pathfinder.vim](https://github.com/AlphaMycelium/pathfinder.vim) | Suggests more efficient cursor movement | Cursor movement only |
| [vim-be-good](https://github.com/ThePrimeagen/vim-be-good) | Game-based practice | Generic drills, not personalized |

tobira is the only plugin that learns from **your actual usage** and surfaces the specific commands _you_ are missing — not a generic curriculum.

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). This project follows strict TDD — tests are written before implementation.

## License

MIT
