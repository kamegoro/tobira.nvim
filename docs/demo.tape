Output docs/demo.gif

Set Shell "bash"
Set FontSize 15
Set Width 1200
Set Height 680
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 40ms
Set CursorBlink false

# ── Boot nvim ────────────────────────────────────────────────────────────────
Hide
Type "cd $(git -C ~/kame/tobira.nvim rev-parse --show-toplevel) && nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 3s
Show

# ── User navigates the file with f (repeated search = inefficient pattern) ───
Sleep 400ms
Type "jjjj"
Sleep 200ms
Type "fo"
Sleep 350ms
Type "fo"
Sleep 350ms
Type "fo"
Sleep 400ms

# ── :Tobira surfaces the suggestion as a toast ────────────────────────────────
Type ":Tobira"
Enter
Sleep 5000ms

# ── Guide panel: shows ✓ for mastered commands and → for next-level hints ────
Type ":TobiraGuide"
Enter
Sleep 4500ms

# ── Progress tree: skill overview with level and next recommendation ──────────
Type ":TobiraProgress"
Enter
Sleep 4500ms
