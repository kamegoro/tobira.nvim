# find_best's best_score sentinel must be -math.huge, not -1 (#121)

## Context

`find_best()` picks the highest-scoring candidate by comparing each
candidate's score against a running `best_score`, initialized before the
loop starts. The original sentinel value was `-1`. A real candidate's score
(`trigger_count - cmd_count`) can legitimately equal exactly `-1` — for
example, a trigger used 5 times and the suggested command already used 6
times. When that happened, the candidate failed the `score > best_score`
check (tied, not greater) and fell into the `score == best_score` tie-break
branch, which compares `cmd < best_cmd` — while `best_cmd` was still `nil`,
because no candidate had won the primary comparison yet. Comparing a string
to `nil` raises a Lua runtime error (#121).

## Decision

Initialize `best_score = -math.huge` instead of `-1`. No real score can ever
equal `-math.huge`, so the first offered candidate encountered always wins
the primary `score > best_score` comparison and sets `best_cmd`, before any
code path can reach the `cmd < best_cmd` tie-break with `best_cmd` still
`nil` — regardless of which candidate `pairs()` happens to visit first.

## Consequences

- Any future "no best yet" sentinel in a comparison loop over a score that
  can be negative or zero must use an unreachable extreme value
  (`-math.huge` / `math.huge`, as appropriate), not an arbitrary small
  integer that happens to look "clearly below any real score" — real scores
  in this codebase are not bounded below by anything but the trigger/command
  counts users actually accumulate.
