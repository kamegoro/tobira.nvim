Output docs/demo-stats.gif

Set Shell "zsh"
Set FontSize 18
Set Width 1920
Set Height 720
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 60ms
Set CursorBlink false

# Stats panel is the focus — mute ambient suggestions to avoid overlap.
Env TOBIRA_DEMO_IDLE "off"

# ── Boot ──────────────────────────────────────────────────────────────────────
Hide
Type "cd ~/kame/tobira.nvim && nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 3s
Show

# ── Open stats panel ──────────────────────────────────────────────────────────
Sleep 400ms
Type ":TobiraStats"
Enter
Sleep 6000ms

# ── Close ─────────────────────────────────────────────────────────────────────
Type "q"
Sleep 400ms
