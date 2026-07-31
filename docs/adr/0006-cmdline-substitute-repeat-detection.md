# Repeated-substitute detection (#115, `patterns_cmdline.lua`)

## Context

Manually retyping the same `:s/{pattern}/{replacement}/` on a new line, instead of using
`&` (repeat on this line) or `g&` (repeat file-wide), is a direct signal for those two
commands. `tokenize()` only extracts the command name and discards everything after it,
so this needed its own parser for the pattern/replacement body, plus a scope decision for
how much of Ex's substitute syntax to support and how strict "identical" should be.

The same false-positive risk as ping-pong detection (#114) applies here too: `logger.lua`
runs its `vim.on_key` callback for the `<CR>` **before** Neovim validates or executes the
command, so the typed `:s///` text alone can't tell whether the substitution actually
matched anything — `E486 "Pattern not found"` lets Neovim run the command and still
change nothing. `v:errmsg` was tried and rejected: every way the test suite drives
keystrokes goes through the API/RPC dispatch layer, which converts errors straight into
Lua exceptions without ever touching `v:errmsg` — a signal this fix's own regression test
could never observe.

## Decision

- **Stateful across calls** (unlike `tokenize()`), via `new_substitute_state()`, living
  for the whole session — same lifetime as `logger.lua`'s other persistent `seq` state.
- **Only a bare (no explicit range) `:s` is tracked.** The targeted workflow is "move to
  another line, retype the same `:s///` there" — the target line is then unambiguously
  the cursor line at `<CR>` time. An explicit range (`:5s`, `:%s`) is a different,
  already one-shot workflow, out of scope.
- **Command-word recognition accepts any prefix of "substitute"** (`s`, `su`, `sub`, ...)
  — unlike `tokenize()`'s general refusal to canonicalize abbreviations, this is a safe
  special case: every prefix of "substitute" diverges from other `s`-commands (`:sort`,
  `:set`, `:split`) well before Vim's own ambiguity resolution would need to kick in.
- **The delimiter is whatever character immediately follows the command word** (Vim
  allows anything except alphanumerics, `\`, `"`, `|`), with `\`-escaped delimiters
  honored the same way `strip_range()` handles search addresses.
- **Trailing delimiter after the replacement is optional**, and anything after a present
  one (flags, count) is ignored for equality — the criterion is "identical pattern AND
  replacement", not "identical flags too".
- **Unparseable as a matter of policy, not just implementation limits:** a missing
  closing delimiter for the pattern (`:s/foo`) and an empty explicit pattern
  (`:s//bar/`, which reuses the last search pattern) are both treated as untracked —
  comparing "the same pattern" needs literal text, and neither case provides it without
  guessing at implicit state this pure module can't access.
- **Threshold: the same (pattern, replacement) pair reaching a 2nd distinct line fires
  `&`; a 3rd distinct line upgrades to `g&`** instead of firing `&` again, then stays
  silent — same exact-count-not-threshold precedent as `patterns.lua`'s
  `x_repeat`/`j_repeat`. Distinct *line count* (not line-number distance) is the signal
  because this module has no access to the buffer's total line count to judge relative
  distance.
- **Verify-before-credit, same problem class as #114's fix, different signal:**
  `logger.lua` snapshots the target buffer's `changedtick` before scheduling, and only
  calls `track_substitute()` inside `vim.schedule()` if the tick increased. `changedtick`
  was chosen over a text diff because it also gets the edge cases right that a diff
  wouldn't: `:s/foo/foo/` (text unchanged, but a real substitution) still increments it,
  while `:s///n` (report-only) and a `:s///c` where every confirm is declined correctly
  leave it flat.

## Consequences

- The scope limits above (bare-`:s`-only, abbreviation-prefix matching, delimiter
  handling, flags-ignored, unparseable cases) are all load-bearing test-pinned behavior —
  see the inline pointer comment on `track_substitute()` and the corresponding tests in
  `patterns_cmdline_spec.lua`.
- `track_substitute()` itself has no notion of "did the substitution really change
  anything" — like `feed_pingpong()` (#114), that verification is entirely the caller's
  responsibility. Any new caller must reason about whether it needs the same
  defer-and-verify treatment `logger.lua` gives it via `changedtick`.
- The threshold does not distinguish "3 adjacent lines" from "3 lines scattered across
  the file" — accepted cost of staying self-contained (no buffer access).
