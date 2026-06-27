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
Type "cd "
Type "$(git rev-parse --show-toplevel)"
Enter
Type "nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 2s
Show

# ── Scene 1: f_repeat — user searches 'f' twice on the same line ─────────────
# Navigate to the line with 'first' and 'family'
Type "/first"
Enter
Sleep 600ms
Escape
Sleep 300ms

# Jump to 'f' in 'first' — tobira increments f count
Type "ff"
Sleep 500ms

# Same line, search 'f' again for 'family' — tobira detects f_repeat!
Type "ff"
Sleep 300ms

# tobira debounces for idle_delay (800ms), then shows the float
Sleep 1300ms

# ── Float is now visible: "Learn ; — repeat f/F without retyping" ────────────
Sleep 2500ms

# Dismiss and continue editing to show adoption detection
Type "q"
Sleep 600ms

# ── Scene 2: x_repeat — deleting chars one by one ───────────────────────────
Type "G"
Sleep 400ms
Type "0"
Sleep 300ms
Type "xxxxx"
Sleep 1300ms

# Float appears: "Learn {n}x — delete N chars at once (e.g. 5x)"
Sleep 2500ms

Type "q"
Sleep 400ms
