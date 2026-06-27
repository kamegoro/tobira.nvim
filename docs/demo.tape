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

# ── User navigates the file with f ───────────────────────────────────────────
Sleep 300ms
Type "jjjj"
Sleep 200ms
Type "fo"
Sleep 250ms
Type "fo"
Sleep 250ms
Type "fo"
Sleep 300ms

# ── :Tobira surfaces the suggestion ──────────────────────────────────────────
Type ":Tobira"
Enter
Sleep 1200ms

# ── Float is visible: "; — repeat the last f" ────────────────────────────────
Sleep 5s

# ── Dismiss ──────────────────────────────────────────────────────────────────
Type "q"
Sleep 600ms
