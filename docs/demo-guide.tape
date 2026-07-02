Output docs/demo-guide.gif

Set Shell "zsh"
Set FontSize 18
Set Width 1920
Set Height 720
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 60ms
Set CursorBlink false

# The Guide panel is what we're showcasing — disable ambient suggestions so
# they don't pop over the panel during the recording.
Env TOBIRA_DEMO_IDLE "off"

# ── Boot ──────────────────────────────────────────────────────────────────────
Hide
Type "cd ~/kame/tobira.nvim && nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 3s
Show

# ── Open guide panel ─────────────────────────────────────────────────────────
Sleep 400ms
Type ":TobiraGuide"
Enter
Sleep 5000ms
