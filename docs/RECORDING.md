# Recording demo GIFs

`docs/demo-*.gif` are generated from `docs/demo-*.tape` scripts via [VHS](https://github.com/charmbracelet/vhs)
(`bash docs/make-demo.sh`). That still works for `progress`, `stats`, and the combined `demo.gif`.

**`demo-suggest.gif` and `demo-guide.gif` are the exceptions.** On at least one contributor machine (Apple
Silicon macOS), VHS reliably produces GIFs with corrupted colors for these two. If you hit this, read on
before spending hours re-discovering the same thing — use the asciinema-based recipe at the bottom instead.
`demo-guide.gif` started hitting this on 2026-07-16 (previously only `demo-suggest.gif` was affected on this
machine) — this is consistent with the bug being about display/alt-screen state at recording time, not a
property of any specific tape, so any tape can start tripping it without a config change on our side.

## The VHS color-corruption bug

Symptom: the Catppuccin Mocha background `#1e1e2e` (rgb 30,30,46) renders as `#1e2e00` (rgb 30,46,0) — the
blue channel is lost and the whole recording looks yellow-green instead of navy.

We spent a full investigation session ruling things out one at a time. In order, all of these were tested
and **did not** fix it:

- Claude Code's Bash sandbox on/off (`dangerouslyDisableSandbox`)
- ttyd's `canvas` vs `dom` renderer (patched VHS per [djdarcy/vhs#fix/windows-ttyd-rendering](https://github.com/djdarcy/vhs/tree/fix/windows-ttyd-rendering), which itself fixes a *different* headless-Chrome bug — worth trying first if you hit a blank/missing-frame issue instead of a color issue)
- `--disable-gpu` (confirmed present in the live Chrome process args — no effect)
- Disconnecting an external HDR monitor entirely (confirmed via `system_profiler SPDisplaysDataType` before/after — no effect)
- Using go-rod's own managed Chromium download (`~/.cache/rod/browser/...`) instead of system Google Chrome — a
  **completely different browser binary**, same corruption
- Running non-headless (`Headless(false)` on the go-rod launcher) so the browser window is actually visible —
  the corruption is visible to the naked eye in the live window, not just in the screenshot encoding, and starts
  the exact instant Neovim enters the alternate screen buffer and clears it to the new background color
  (confirmed frame-by-frame: the frame before is correct, the frame after alt-screen entry is corrupted, with
  zero content drawn yet — so it's not about *what* is drawn, just the alt-screen background clear itself)

This matches a class of long-standing, acknowledged-unfixable upstream reports, not something specific to this
repo's config:

- [puppeteer#7196](https://github.com/puppeteer/puppeteer/issues/7196) — "Screenshot colors look wrong in
  headless, but ok in non-headless"; `--force-color-profile=srgb` (already applied by default) does not help
- [puppeteer#8009](https://github.com/puppeteer/puppeteer/issues/8009) / [playwright#14460](https://github.com/microsoft/playwright/issues/14460) —
  screenshot colors change depending on external-monitor configuration; a Playwright maintainer's conclusion:
  *"we are aware that browsers / operating systems render things differently depending on the monitors
  attached. And unfortunately, we can't help with this: this is how things work!"*
- [tsl0922/ttyd#1061](https://github.com/tsl0922/ttyd/issues/1061) — a Chrome-version-specific ttyd rendering
  bug that came and went across Chrome auto-updates, with no code fix
- A prior recording session on this same repo hit this exact bug, "fixed" it by re-recording until a clean
  take came through, and closed the investigation as "transient." It is not transient — it reproduced 100% of
  the time (8+ identical attempts) in the session that wrote this doc. The earlier session just got lucky
  within its retry budget. **Do not rely on "just retry a few times."**

Bottom line: this is a real, filed, unresolved bug in how headless Chromium composites/encodes color on macOS
depending on system display state, not something fixable by changing VHS flags, ttyd renderer, or the browser
binary.

## The fix: don't use a browser at all

[asciinema](https://asciinema.org/) + [agg](https://github.com/asciinema/agg) record and render terminal
sessions without ever launching a browser — `agg` rasterizes the recorded ANSI/truecolor stream directly with
its own terminal emulator (the `avt` crate) and font renderer. There is no Chromium in the pipeline, so the
color bug cannot occur.

```bash
brew install asciinema agg tmux
```

**Do not drive the keystrokes with `expect`.** Its `log_user 1` diagnostic output (`spawn ...`, `send: sent
...`) gets woven into the same recorded stream and confuses `agg`'s terminal-state parser badly enough that
Neovim's content never renders in the output GIF at all (you'll get 2-3 near-blank frames). Use `tmux
send-keys` instead — it never echoes anything about what it's doing, so the recorded stream contains only the
real terminal output.

**`demo-*.tape` files set `Env TOBIRA_DEMO_IDLE "off"` — that only applies when VHS actually executes the
tape.** Bypassing VHS means nvim never sees that env var, so the ambient idle picker stays on and can race
the reactive pattern suggestion you're trying to demo (e.g. showing `<C-d>` instead of the intended `;`).
Export it yourself on the `tmux new-session` command (`-e TOBIRA_DEMO_IDLE=off`) for any tape that sets it.

Keep the pacing tight — this is a README hero asset, viewers bounce if nothing happens in the first second.
Match whatever `Sleep`/`Type` values are currently in the `.tape` file (they get tuned over time; the file is
the source of truth, not the numbers below).

### Recipe (worked example: demo-suggest.gif)

```bash
cd ~/kame/tobira.nvim

# 1. Start a tmux session running the demo, sized to roughly match the old
#    VHS "Width 1600 Height 720 / FontSize 18" look. Status bar off — we
#    don't want tmux's own status line burned into the recording. Export
#    any TOBIRA_DEMO_* env vars the target .tape file sets (see above).
tmux kill-session -t demo 2>/dev/null
tmux new-session -d -s demo -x 150 -y 24 -e TOBIRA_DEMO_IDLE=off \
  "nvim -u docs/demo-init.lua docs/demo.lua"
tmux set-option -t demo status off
sleep 2   # let nvim finish booting

# 2. Start the recording, attached to that tmux session, headless (no
#    controlling terminal needed — this also works fine over SSH/CI).
asciinema rec --headless --window-size 150x24 \
  --command "tmux attach -t demo" --overwrite docs/demo-suggest.cast &
sleep 1

# 3. Drive the same keystroke timing docs/demo-suggest.tape uses — check
#    that file for the current values, these are just what it had as of
#    this writing.
sleep 0.15
tmux send-keys -t demo "jjj"
sleep 0.2
tmux send-keys -t demo "fo"
sleep 0.25
tmux send-keys -t demo "fo"
sleep 1.0   # idle_delay (800ms) + buffer
sleep 2.8   # GIFs loop — this only needs to cover one read, not linger

# 4. End the recording while the notification is still showing (killing the
#    tmux session ends the attached asciinema recording too).
tmux kill-session -t demo

# 5. Render to GIF. --idle-time-limit caps how long any single frame's gap
#    is stretched; agg's own frame-selection otherwise leaves long gaps as
#    one frame, which is fine here since we want the notification to linger.
agg --idle-time-limit 2 --cols 150 --rows 24 --font-size 18 \
  docs/demo-suggest.cast docs/demo-suggest.gif

rm docs/demo-suggest.cast
```

The very last frame `agg` produces after `tmux kill-session` is often a one-line `[exited]` message from the
now-dead pane — trim it before committing:

```python
from PIL import Image
im = Image.open("docs/demo-suggest.gif")
im.load()
frames, durations = [], []
for i in range(im.n_frames - 1):  # drop the trailing [exited] frame
    im.seek(i)
    frames.append(im.convert("RGB").copy())
    durations.append(im.info.get("duration", 500))
durations[-1] = 3000  # let the last real frame linger
frames[0].save("docs/demo-suggest.gif", save_all=True, append_images=frames[1:],
                duration=durations, loop=0)
```

### Verifying the color came out right before committing

Don't eyeball a thumbnail — check pixels directly. Catppuccin Mocha's base color is `#1e1e2e` = `rgb(30, 30,
46)`:

```python
from PIL import Image
im = Image.open("docs/demo-suggest.gif")
im.load()
for i in range(im.n_frames):
    im.seek(i)
    print(i, im.convert("RGB").getpixel((30, 30)))
# Expect (30, 30, 46) on every frame that shows the editor background.
# (30, 46, 0) means you've hit the VHS/Chromium bug above.
```

## If VHS starts corrupting `progress` / `stats` / the combined demo too

Same recipe applies — swap the `tmux send-keys` sequence for whatever keys that tape's `Type`/`Sleep` lines
send (see `docs/demo-guide.tape` etc. for the reference sequence and timing), and the `nvim -u ...` command
for whichever file that tape opens.

### Worked example: `demo-guide.gif` (2026-07-16)

`docs/demo-guide.tape` only opens Neovim and runs `:TobiraGuide`, so the whole sequence collapses to one
`send-keys` call. Run from the repo root, on the branch you actually want rendered — the tape's own `Type
"cd ~/kame/tobira.nvim && ..."` line means VHS (and this manual recipe alike) always launches Neovim against
whatever is checked out at that fixed path, not wherever the recording command itself was invoked from. If
you're recording from a worktree, check out the branch in `~/kame/tobira.nvim` itself first, or the GIF will
silently show the wrong code.

```bash
cd ~/kame/tobira.nvim

tmux kill-session -t demo 2>/dev/null
tmux new-session -d -s demo -x 150 -y 24 -e TOBIRA_DEMO_IDLE=off -e TOBIRA_DEMO_PATTERNS=off \
  "nvim -u docs/demo-init.lua docs/demo.lua"
tmux set-option -t demo status off
sleep 3   # matches the tape's boot Sleep 3s

rm -f docs/demo-guide.cast
asciinema rec --headless --window-size 150x24 \
  --command "tmux attach -t demo" --overwrite docs/demo-guide.cast &
sleep 1

sleep 0.4                                  # tape: Sleep 400ms
tmux send-keys -t demo ":TobiraGuide" Enter
sleep 6                                    # tape: Sleep 5000ms + a little viewing buffer

tmux kill-session -t demo

agg --idle-time-limit 2 --cols 150 --rows 24 --font-size 18 \
  docs/demo-guide.cast docs/demo-guide.gif
rm docs/demo-guide.cast
```

Then trim the trailing `[exited]` frame with the same Python snippet used for `demo-suggest.gif` above, and
verify pixel colors before committing.
