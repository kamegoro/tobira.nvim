Output docs/demo-progress.gif

Set Shell "zsh"
Set FontSize 14
Set Width 1000
Set Height 540
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 60ms
Set CursorBlink false

# ── Boot: seed data and open nvim with real config (hidden) ───────────────────
Hide
Type "cd ~/kame/tobira.nvim && bash docs/demo-seed.sh && nvim -u ~/.config/nvim/init.lua docs/demo.lua"
Enter
Sleep 6s
Show

# ── Open progress tree ────────────────────────────────────────────────────────
Sleep 400ms
Type ":TobiraProgress"
Enter
Sleep 5000ms
