Output docs/demo-suggest.gif

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

# ── Navigate to a line with two 'o' characters ───────────────────────────────
# Line 4: "local function find_user(id, fallback)"
#   fo → 'o' in "local"
#   fo → 'o' in "function"  ← same char, same line = f_repeat fires
Sleep 400ms
Type "jjj"
Sleep 500ms

# ── Repeat f-search on the same line (the inefficient pattern) ───────────────
Type "fo"
Sleep 700ms
Type "fo"

# ── Idle for 800ms → tobira detects the pattern and shows the suggestion ─────
Sleep 1500ms

# ── Read the notification ─────────────────────────────────────────────────────
Sleep 4000ms
