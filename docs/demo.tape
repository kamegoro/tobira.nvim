Output docs/demo.gif

Set Shell "zsh"
Set FontSize 15
Set Width 1200
Set Height 680
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 40ms
Set CursorBlink false

# The combined demo drives every panel manually via :Tobira / :TobiraGuide /
# :TobiraProgress. Mute ambient suggestions so they don't pop during panels.
Env TOBIRA_DEMO_IDLE "off"
Env TOBIRA_DEMO_PATTERNS "off"

# ── Seed demo data and boot nvim with full personal config ────────────────────
Hide
Type "bash ~/kame/tobira.nvim/docs/demo-seed.sh"
Enter
Sleep 500ms
Type "cd ~/kame/tobira.nvim && nvim docs/demo.lua"
Enter
Sleep 6s
# Override lang to English after lazy.nvim finishes loading
Type ":lua require('tobira.core.config').values.lang = 'en'"
Enter
Sleep 200ms
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
Sleep 6500ms

# ── Guide panel: ✓ for mastered commands, → for next-level hints ─────────────
Type ":TobiraGuide"
Enter
Sleep 4500ms

# ── Close guide, then show the skill progress tree alone ─────────────────────
Type ":TobiraGuide"
Enter
Sleep 500ms
Type ":TobiraProgress"
Enter
Sleep 4500ms
