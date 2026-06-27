Output docs/demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 520
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 80ms
Set CursorBlink false

# ── Boot nvim ────────────────────────────────────────────────────────────────
Hide
Type "cd $(git -C ~/kame/tobira.nvim rev-parse --show-toplevel) && nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 3s
Show

# ── Scene 1: user navigates the file naturally ───────────────────────────────
Sleep 500ms
Type "jjjj"
Sleep 400ms
Type "fo"
Sleep 400ms
Type "fo"
Sleep 400ms
Type "fo"
Sleep 600ms

# ── Trigger :Tobira to show the suggestion float ─────────────────────────────
Type ":Tobira"
Enter
Sleep 2s

# ── Float is visible — show it for 4 seconds ─────────────────────────────────
Sleep 4s

# ── User presses q to dismiss ────────────────────────────────────────────────
Type "q"
Sleep 800ms

# ── Scene 2: x_repeat ────────────────────────────────────────────────────────
Type "G0"
Sleep 400ms
Type "xxxxx"
Sleep 1200ms

# Float auto-appears from pattern detection
Sleep 3500ms
Type "q"
Sleep 500ms
