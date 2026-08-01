# Tolerated-motion streak patterns: `r_streak`, `ca_streak` (`patterns.lua`)

## Context

Two streak patterns follow the same "same key N times in a row → suggest a
batching alternative" shape: `r{char}` repeated 3× suggests `R` (Replace
mode), and `<C-a>` repeated 3× suggests `g<C-a>` (sequential increment down a
visual block of lines). Both need to tolerate the ordinary connecting motion
a user presses between repetitions without treating it as "doing something
unrelated".

## Decision

- `r_streak` increments on every `r{char}` completion, fires at 3, and
  resets on any key except `h`/`l` — the natural sideways motion between
  same-line replacements.
- `ca_streak` increments on every `<C-a>`, fires at 3, and resets on any key
  except `j`/`k` — the natural motion between per-line increments (since
  `g<C-a>` operates down a range of lines).
- Both follow the same increment/fire-at-3/reset-with-tolerance shape as
  `ci_dquote_streak`/`ci_squote_streak` (see
  `docs/adr/0020-ci-quote-streak-and-tolerance.md`), just with a narrower,
  feature-specific tolerance set.

## Consequences

- The tolerated-key set is what makes each streak observable in realistic
  usage instead of resetting on nearly every keystroke between repetitions —
  widening or narrowing it is a real behavior change, not a cosmetic one.
