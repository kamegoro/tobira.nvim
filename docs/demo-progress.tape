Output docs/demo-progress.gif

Set Shell "zsh"
Set FontSize 18
Set Width 1920
Set Height 720
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 60ms
Set CursorBlink false

# Progress is the focus here — mute ambient suggestions so they don't overlap.
Env TOBIRA_DEMO_IDLE "off"
Env TOBIRA_DEMO_PATTERNS "off"

# ── Boot ──────────────────────────────────────────────────────────────────────
Hide
Type "cd ~/kame/tobira.nvim && nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 3s
Show

# ── Open progress tree ────────────────────────────────────────────────────────
Sleep 400ms
Type ":TobiraProgress"
Enter
Sleep 2s

# ── Navigate to a skill row (motion auto-items: $, %, (, )) ──────────────────
# Row layout: blank / Level / blank / Motion / composite(hjkl w/b gg/G f/t) / auto-row1 / auto-row2
# j×5 puts cursor on the first auto-row ($  %  (  ))
Type "jjjjj"
Sleep 600ms

# Move into the first cell (col 2+ = cell 1)
Type "0ll"
Sleep 400ms

# ── Press x to suppress the command under cursor ──────────────────────────────
Type "x"
Sleep 1800ms

# ── Press x again to restore ─────────────────────────────────────────────────
Type "x"
Sleep 1200ms

# ── Move right to pin another command ─────────────────────────────────────────
Type "llllllllllllll"
Sleep 400ms
Type "p"
Sleep 1800ms

# ── Close ─────────────────────────────────────────────────────────────────────
Type "q"
Sleep 400ms
