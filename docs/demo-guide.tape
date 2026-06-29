Output docs/demo-guide.gif

Set Shell "zsh"
Set FontSize 14
Set Width 900
Set Height 500
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

# ── Open guide panel ─────────────────────────────────────────────────────────
Sleep 400ms
Type ":TobiraGuide"
Enter
Sleep 5000ms
