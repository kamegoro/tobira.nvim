# Operator streak tracking: `dd`/`cc` per-operator split, indent/dedent (`patterns.lua`)

## Context

`dd`/`cc` (linewise delete/change, repeated) and `>>`/`<<` (indent/dedent,
repeated) track "same operator N times in a row" the same way `x_repeat`/
`j_repeat`/etc. do for bare motions — just for two-key compounds instead of
single keys.

## Decision

- `dd_streak` and `cc_streak` are tracked as SEPARATE counters per operator
  (#118). A prior version used one shared/hardcoded `'dd'` counter that
  misattributed every `cc` completion to `dd`'s counter.
- `indent_streak`/`dedent_streak`: `>>` repeated 3× fires `indent_run`
  (`{n}>>`), `<<` repeated 3× fires `dedent_run` (`{n}<<`); a non-matching
  key resets both.
- `dj`/`dk` and `cj`/`ck` are treated identically to `dd`/`cc` (linewise),
  since `j`/`k` as the second key of a `d`/`c`-pending sequence is also a
  line-range motion.

## Consequences

- Any new operator that gains its own linewise-repeat suggestion must get
  its own dedicated streak counter, not share `dd_streak`/`cc_streak` —
  reusing either would reintroduce the #118 misattribution bug.
