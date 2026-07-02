Output docs/demo-suggest.gif

Set Shell "zsh"
Set FontSize 18
Set Width 1600
Set Height 720
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 60ms
Set CursorBlink false

# This demo wants the reactive f_repeat -> ; suggestion specifically, not
# whatever the ambient idle picker scores highest across the seed data (the
# seed's j -> } efficiency gap easily outscores f -> ; and would otherwise
# win the race). Disable only the ambient picker; leave pattern reactions on.
Env TOBIRA_DEMO_IDLE "off"

# ── Boot: seed data and open nvim (hidden) ────────────────────────────────────
Hide
Type "cd ~/kame/tobira.nvim && nvim -u docs/demo-init.lua docs/demo.lua"
Enter
Sleep 3s
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

# ── Read the notification (now has a "why now" reason line + mute hint,
# so give it a bit more time on screen than before) ──────────────────────────
Sleep 5500ms
