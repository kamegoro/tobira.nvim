# `v`/`gv` repeat detection (`patterns.lua`)

## Context

Feature #55: detect `v <Esc> v <Esc> v` — three "clean" visual-mode taps with
no real selection use in between — and suggest `gv` (reselect the last visual
selection) instead of repeatedly re-invoking `v` and reselecting by hand.

## Decision

- `v_streak` counts consecutive "`v` then immediate `<Esc>`, nothing else"
  cycles. `v_clean_exit` remembers whether the cycle that JUST ended was one
  of those (as opposed to genuine visual usage, e.g. `viw`) — pressing `v`
  only extends the streak when the immediately preceding cycle was clean;
  otherwise it restarts the count at 1.
- Fires only once the `<Esc>` that ends the 3rd cycle confirms that cycle was
  ALSO clean — not the instant the 3rd `v` lands. At the moment the 3rd `v`
  arrives, the sequence could still turn into genuine usage (e.g.
  `v<Esc>v<Esc>viw`) — the disambiguating key hasn't happened yet. Waiting
  for the confirming `<Esc>` guarantees `v_streak >= 3` is only ever true
  once all 3 `v`'s are confirmed clean.
- Any completion other than `<Esc>` (a text object or anything else) breaks
  the streak — it means the user actually did something with the selection.

## Consequences

- The "fire on the confirming `<Esc>`, not on the `v` itself" ordering is
  load-bearing — moving the fire-and-return to the `v` keystroke would
  misfire on legitimate sequences like `v<Esc>v<Esc>viw`.
