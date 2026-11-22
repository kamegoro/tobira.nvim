# `_then_insert` suggestions fire only for the follow-up insert key that makes them equivalent (`patterns.lua`)

## Context

The reactive "delete, then enter insert mode" patterns (`dd_then_insert` → `cc`,
`dw_then_insert` → `cw`, `diw_then_insert` → `ciw`, `x_then_insert` → `s`,
`D_then_insert` → `C`) all accepted any member of `INSERT_KEYS`
(`i I a A o O s S`) as the follow-up key. That made them suggest a command that
does a *different* edit from what the user just did:

- `dwA` deletes a word and appends at the end of the line. `cw` would leave the
  cursor where the word was.
- `ddo` deletes a line and opens a new line *below the next one*. `cc` would
  empty the line in place.
- `xa` deletes a character and appends after the next one; `s` inserts where the
  character was.
- `Di` inserts before the last remaining character; `C` appends at end of line.

The `'dw'` bucket made it worse: every charwise `d` completion (`db`, `dh`, `dl`,
`dW`, `d0`, `d}`, `daw`, `di"`, …) normalizes to `last_op = 'dw'`, so `dbi` or
`di"i` also suggested `cw`, which deletes something else entirely.

A suggestion that performs a different edit is wrong, not just low-value: a user
who follows it gets a different result and learns the wrong lesson.

## Decision

- Each pattern has a small table of follow-up keys that make delete + insert the
  same edit as the suggested command, and fires only for those:
  - `dd` + `O` → `cc` (the deleted line is reopened in place).
  - `dw`/`de`/`d3w` + `i` → `cw` (`cw` behaves like `ce`, so `de` is covered too).
  - `diw` + `i` → `ciw`.
  - `x` + `i` → `s`.
  - `D` + `a`/`A` → `C` (after `D` the cursor is on the last character, so both
    resume at end of line).
- `dw_then_insert` additionally requires the `'dw'` value to come from a bare or
  counted `w`/`e` motion. A new persistent flag `seq.last_op_wordish` is set at
  the charwise-motion resolution (`true` for `w`/`e`, `false` otherwise) and
  cleared at text-object resolution — the same two call sites as
  `last_op_diw` (docs/adr/0119). Other motions and text objects (`daw`, `di"`, …)
  no longer suggest anything here; suggesting `caw`/`ci"` would be the equivalent
  answer, but that is a new suggestion, not a correction, and was left out.
- A non-equivalent insert key still **consumes** `last_op` (and `dd_streak`).
  Otherwise `dwA<Esc>` would leave `last_op = 'dw'` behind and a later, unrelated
  `i` would fire a stale `cw`.

Not done: detecting the edge cases that need buffer state (`ddO` on the last line,
`diwi`/`xi` at the end of a line, where the cursor moves left). `patterns.lua` is
keystroke-only; these are rare and remain known false positives.

## Consequences

- These patterns fire less often, but every remaining fire is a suggestion the user
  can follow and get the same result.
- A new `_then_insert`-style pattern should declare its equivalent follow-up keys
  explicitly rather than reusing `INSERT_KEYS` wholesale.
- `tests/differential/reference_model.lua` mirrors the same tables and the
  `last_op_wordish` flag; the generator emits the equivalent key half the time so
  the fuzzer still exercises both the firing and the non-firing shapes.
