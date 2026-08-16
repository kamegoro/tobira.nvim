# Ex-command tracking and the stricter "never tried" gate (#57)

## Context

`:g` (global command) and `:norm` (run a normal-mode command per line) are Ex
commands, not keystrokes — there's no `vim.on_key` byte to watch for them.
`patterns_cmdline.lua` tokenizes the completed command line (at `<CR>` time) to
detect them, and `logger.lua`'s cmdline handler records usage through that path,
not the generic keystroke TRACK table.

These two commands also don't fit the generic mastery-level promotion gate that
every other suggestion uses (keep nudging until the underlying habit's count
crosses a threshold). A single successful `:g/pattern/cmd` already replaces dozens
of manual repeat-keystrokes in one shot — continuing to suggest it after the user
has already tried it once would read as the plugin ignoring feedback it already
has, unlike e.g. `cw`, where repeating the nudge up to a count of 100 is fine
because each individual use is cheap and the underlying habit takes longer to
displace.

## Decision

- `track = false` on both entries: `build_track_table()` must not also treat the
  literal strings `'ex:g'` / `'ex:norm'` as keys to watch for on the keystroke path.
- `ex_command = true` on both: `graph.find_best()` reads this flag to apply a
  stricter "never tried" gate instead of the generic mastery-level gate — once
  tried, stop suggesting, rather than continuing until a count threshold.
- `requires = 'n'` for `:g`: repeated manual search-repeat (`n`) is already doing by
  hand what `:g/pattern/cmd` does over every match at once, so heavy `n` usage is
  the "doing this the slow way" signal. `requires = 'q'` for `:norm`: recording a
  macro is the same "already doing this manually" relationship to running a
  normal-mode command over a range.

## Consequences

- Any future Ex-command entry should default to `ex_command = true` unless there's
  a specific reason a single use doesn't fully replace the underlying habit (in
  which case the generic mastery gate is probably the better fit after all).
- The `requires` field on an `ex_command = true` entry documents "what manual
  workaround this replaces", not a literal keystroke-count promotion path — don't
  read it as implying the generic threshold applies.
- See `core/patterns_cmdline.lua`'s own header for the full Ex-command parsing
  scope; this ADR covers only the registry-level `commands.lua` decisions.

### Addendum: `requires` chaining one `ex_command = true` entry off another

`ex:v` (`:vglobal`, `:help :vglobal`) is `:g`'s documented inverse, so it's
registered as `requires = 'ex:g'` — the first `ex_command = true` entry whose
`requires` points at another `ex_command = true` entry rather than at a
manual-keystroke workaround key. This still works end to end with no code
changes: `graph.lua`'s trigger resolution is a generic string-keyed lookup
into `commands.lua`, indifferent to whether the key it resolves is a
keystroke or another Ex command, and `logger.lua`'s cmdline tokenizer
increments usage for any submitted Ex command regardless of its registry
`track` value.

The "what manual workaround this replaces" framing in this ADR's Decision
section above was accurate for `:g`/`:norm` but was never the actual
constraint — the real semantics of `requires` on an `ex_command = true` entry
is simply "the user must have tried the more fundamental command first,"
which generalizes cleanly to a prerequisite that is itself an Ex command.
Future Ex-command entries should pick whichever prerequisite shape fits
(manual keystroke or another Ex command) rather than treating the former as
the only valid option.
