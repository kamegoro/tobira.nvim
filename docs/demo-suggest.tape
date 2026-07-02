Output docs/demo-suggest.gif

Set Shell "zsh"
Set FontSize 18
Set Width 1600
Set Height 720
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 40ms
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
# Pacing is intentionally tight — this is a README hero GIF, viewers bounce
# if nothing happens in the first second. Get to the payoff fast.
Sleep 150ms
Type "jjj"
Sleep 200ms

# ── Repeat f-search on the same line (the inefficient pattern) ───────────────
Type "fo"
Sleep 250ms
Type "fo"

# ── Idle (demo-init.lua sets idle_delay=800ms) → suggestion fires ────────────
# Must stay above idle_delay + render/capture buffer, but no more.
Sleep 1000ms

# ── Read the notification. GIFs loop, so this only needs to cover one read,
# not linger — interested viewers get more reps for free from the loop. ──────
Sleep 2800ms
