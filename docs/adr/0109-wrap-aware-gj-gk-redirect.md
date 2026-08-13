# Wrap-aware gj/gk reuses existing j/k thresholds (#236)

## Context

`gj`/`gk` (move by displayed screen line, not buffer line) are already registered in
`commands.lua`, but only as targets `pending_g` resolves once the user has already typed
them — there was no reactive pattern suggesting them in the first place.

Suggesting `gj`/`gk` only makes sense when `vim.wo.wrap` is enabled for the current window
**and** the cursor is genuinely on a line that spans more than one screen row. Neither
condition alone is sufficient: `wrap` is a very common default, so most `wrap`-on windows
still show most lines on a single screen row, and suggesting `gj`/`gk` there would behave
identically to `{n}j`/`{n}k` — a no-op the user can't observe, which would read as a broken
suggestion rather than a useful one.

This is the same class of problem #111 already solved for diff mode: `vim.wo.diff` is a
read-only window-local option, read once in `logger.lua`'s `handle_key` and threaded into
`patterns.feed()` as a plain boolean (`is_diff`), because `patterns.lua` stays free of
`vim.*` calls by design (see `lua/tobira/CLAUDE.md`'s module dependency rules). See
`docs/adr/0011-diff-mode-reuses-existing-thresholds.md` for that precedent in full — this
ADR mirrors its shape as closely as possible rather than inventing a new mechanism.

## Decision

**No new threshold or counter.** `j_repeat`/`k_repeat` already fire once `j`/`k` is pressed
5 times in a row (`count == 5` in `inner_feed`). This redirects what those two branches
return, exactly the way `is_diff` redirects `j_many`/`k_many` (`count == 10`) from `}`/`{`
to `]c`/`[c`:

```lua
elseif key == 'j' and count == 5 then
  if is_wrapped then
    return { pattern = 'j_repeat_wrapped', cmd = 'gj' }
  end
  return { pattern = 'j_repeat', cmd = '{n}j' }
```

`j_repeat_wrapped`/`k_repeat_wrapped` are new `pattern` values (not a new detection
mechanism) for the same reason `j_many_diff`/`k_many_diff` are: the reason text shown in the
suggestion float differs from the unqualified case, so the locale lookup needs a distinct
key. The counting logic — the streak, the threshold, the `== 5` firing-once check — is
identical to `j_repeat`/`k_repeat`; only the returned pattern/cmd pair depends on
`is_wrapped`, decided once, at the moment the 5th press resolves.

**`is_wrapped` is threaded as a 6th parameter, appended after `now`, not inserted before
it.** `is_diff` sits before `now` in `M.feed(seq, key, line, is_diff, now)`, but by the time
this change landed, that signature had well over a thousand call sites across
`patterns_spec.lua`, the overwhelming majority passing 3 or 4 positional arguments and
relying on Lua's `nil`-for-omitted-args behavior. Inserting a new parameter before `now`
would have meant updating every 5-argument call site (the smaller set, but still real) to
keep passing the right value in the right slot; appending after `now` means every existing
call site keeps working unchanged, and the ~10 call sites that do pass `now` don't shift.
The trade-off is that `is_diff` and `is_wrapped` no longer sit next to each other in the
signature, which a reader unfamiliar with the file's growth history might find odd — this
paragraph is that context.

**Detection technique: compare rendered line width to the window's usable text width.**
`patterns.lua` exports a pure function:

```lua
function M.is_wrapped_line(display_width, text_width)
  return text_width > 0 and display_width > text_width
end
```

`logger.lua` supplies the two widths from real Neovim state, gated behind `vim.wo.wrap`
first (cheap) so the more expensive width computation only runs when wrap is even possible:

- `text_width`: `getwininfo(win)[1].width - getwininfo(win)[1].textoff` — the window's total
  width minus whatever the number/sign/fold columns are currently consuming. `textoff` is
  Neovim's own answer to "how much of this window's width is not text," so this avoids
  re-deriving it from `'number'`/`'signcolumn'`/`'foldcolumn'` by hand.
- `display_width`: `vim.fn.strdisplaywidth(vim.fn.getline(target))` — the rendered width of
  the line this j/k is about to land the cursor on, accounting for tabs and multi-cell
  characters the way the screen actually renders them (unlike `#line`, which counts bytes).
  `target` is `cursor line ± 1` (clamped to the buffer's line range; `+1` for `j`, `-1` for
  `k`), not the cursor's line at call time. `vim.on_key()` fires before Neovim applies the
  keystroke, so at call time the cursor is still one line short of where this j/k is about to
  land it; checking the destination instead of the departure line is what makes the check
  match what the user is actually looking at once the suggestion float appears (independent
  QA finding on PR #289 — the shipped version checked `vim.fn.getline('.')`, the departure
  line, which a same-line-only test buffer never exercised against a destination that
  differs from the departure).

This was verified empirically before implementation, not just derived on paper: in a
headless Neovim session with a controlled window width, `wrap` off + a long line, `wrap` on
+ a short line, and `wrap` on + a long line all produced the expected `is_wrapped_line`
result, and narrowing the window further via `number`/`signcolumn` correctly shrank
`text_width` and flipped a borderline line from "fits" to "wraps." A `winline()` check
before/after issuing `gj` on the same buffer line independently confirmed the line actually
occupied two distinct screen rows when the formula said it should.

The issue also floated comparing `vim.fn.winline()` or `vim.fn.screenpos()` deltas. Width
comparison was chosen instead because it answers the actual question directly ("would this
line's rendered content fit in one screen row?") without needing to move the cursor or
diff two screen positions across a keystroke — `winline()`-based approaches only tell you
where the cursor already is, not whether the specific line it's on would wrap regardless of
current scroll position.

## Consequences

- Catches the case the issue was filed for: a user mashing `j`/`k` on a wrapped paragraph
  gets pointed at `gj`/`gk`, while the same streak on code with `wrap` on (where most lines
  are short) still gets the ordinary `{n}j`/`{n}k` suggestion.
- **Known limitation**: `strdisplaywidth()` measures the raw buffer line's text, not what is
  actually painted on screen. A line that is heavily `conceal`ed, or sits inside a closed
  fold, can measure as "wide" by this formula while rendering far narrower (or as a single
  fold-text line) on screen — a false positive toward suggesting `gj`/`gk` in that specific
  case. This is a known, accepted gap rather than a silently-ignored one: fixing it would
  require reading `conceal`/fold state per line on every 5th `j`/`k` press, which is more
  hot-path cost than this suggestion is worth. A future fix, if this proves to matter in
  practice, should look at `vim.fn.foldclosed()` and the `'conceallevel'` option before
  reaching for anything heavier.
- Like `is_diff`, `is_wrapped` is not computed in the Visual-mode `patterns.feed()` call site
  in `logger.lua` — that branch hardcodes `is_diff = false` and simply omits `is_wrapped`
  (defaulting to falsy), so a `j`/`k` streak in Visual mode never redirects to `gj`/`gk`
  either. Extending both to Visual mode is future work, not a regression introduced here.
