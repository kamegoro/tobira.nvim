# `command_arg()`: one shared argument extractor for two detectors, not three (`patterns_cmdline.lua`)

## Context

`tokenize()` deliberately discards everything after the command word (#57's scope never
needed it). Two later detectors both need the argument text back: the tabnew
one-tab-per-file streak (#113) needs to tell a bare `:tabnew` apart from
`:tabnew foo.txt`, and the `:e`/`:b` ping-pong detector (#114) needs the filename
argument to tell `:e A` apart from `:e B`. Writing this parsing twice would duplicate the
same `strip_range()`-then-split-off-the-word logic.

A third place, `track_substitute()` (#115), also parses "the rest of the line after the
command word" — but it needs the delimiter-bounded PATTERN and REPLACEMENT fields inside
that remainder (`:s/foo/bar/`), a shape `command_arg()`'s contract has no concept of.
Routing it through `command_arg()` first would mean immediately re-parsing that
function's `arg` return value with the same delimiter logic anyway.

## Decision

- **`command_arg()` is one shared implementation**, used by both the tabnew streak and
  the ping-pong detector, reusing `strip_range()` so a leading range prefix never leaks
  into the returned argument (same as `tokenize()`).
- Returns `word, arg`: `word` is the lowercased command word, or `nil` if there wasn't
  one (empty / unparseable / range-only / symbolic input — unlike `tokenize()`,
  `command_arg()` only ever needs to recognize letter-word commands like `:tabnew`/`:e`/
  `:b`, so it has no punctuation fallback). `arg` is the trimmed remainder, or `nil` for
  "no argument" (a bare `:e`/`:b`/`:tabnew`). A leading force-bang (`:e!`) is stripped
  before the argument is extracted, so it never glues onto the filename.
- Callers that want `''` instead of `nil` for "no argument" (`feed_tabnew`, whose
  contract predates this shared function) convert that themselves at the call site — see
  `logger.lua`.
- **`track_substitute()` deliberately does NOT reuse `command_arg()`** — it parses the
  post-word text itself instead of layering delimiter parsing on top of an already-parsed
  opaque string.

## Consequences

- Adding a third `command_arg()`-shaped consumer is free; adding a consumer that needs
  delimiter-bounded sub-fields (like `track_substitute()`) is not — it should parse the
  raw post-word text itself, not extend `command_arg()`'s return shape.
- `command_arg()`'s "letter-word commands only" contract means it is not a drop-in
  replacement for `tokenize()` for symbolic commands (`:!`, `:&`, ...); callers needing
  those must still use `tokenize()`.
