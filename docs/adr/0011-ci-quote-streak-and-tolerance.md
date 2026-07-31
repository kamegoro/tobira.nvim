# `ci"`/`ci'` streak detection and its motion tolerance (`patterns.lua`)

## Context

Feature #53: `ci"`/`ci'` repeated 3× as a direct (non-visual,
operator-pending) sequence suggests `ya"`/`ya'` — a composable alternative
that doesn't require re-entering `ci"` each time.

A live-QA follow-up found the naive "any intervening key resets the streak"
rule — the one `dd_streak`/`cc_streak` correctly use, since repeating `dd`
literally means the same key twice in a row — is wrong here specifically:
reaching the NEXT quoted string to `ci"` it again necessarily requires some
motion in between. A hard reset made the streak nearly impossible to observe
in realistic usage.

## Decision

- `ci_dquote_streak`/`ci_squote_streak` are tracked separately per quote
  character (mirrors `dd_streak`/`cc_streak`'s per-operator split, #118).
  Only a direct `c` + `i` + quote completion counts; `ca"`/`da'`/`ciw`/`ci(`/
  etc. all reset both counters — the same "a mismatched completion resets
  the streak" shape `dd_streak`/`cc_streak` use for a linewise mismatch.
- Distinct from the general `visual_textobj` tracking: this only fires from
  a direct operator-pending `ci"`/`ci'`, never from `v i " c` (the visual
  path is a separate `pending_visual`/`visual_obj` state machine that never
  touches these counters).
- `CI_QUOTE_NAV_KEYS` tolerance table (`w`/`b`/`e`/`h`/`l`/`j`/`k`/`0`/`^`/
  `$`) is tolerated between completions without resetting the streak —
  mirrors `r_streak`'s `h`/`l` tolerance and `ca_streak`'s `j`/`k` tolerance
  (see `docs/adr/0018-tolerated-motion-streaks-r-and-ctrl-a.md`), just over a
  wider set matching realistic usage: `ci"..<Esc>`, move to the next string,
  `ci"` again. Anything NOT in this set (an unrelated edit, another
  operator, an `f"`/`F"`-style search, etc.) still resets both streaks.
- This tolerance check is deliberately its OWN check in `inner_feed`, not
  folded into the generic reset block further down that hard-resets
  `dd_streak`/`cc_streak`/etc. unconditionally.
- `pending_text_obj_inner` (a `new_seq()` field) exists purely so this
  streak can tell a direct `ci"` apart from `ca"`/`di"`/`da'` at the point
  `pending_text_obj` resolves — it remembers whether the `i`/`a` prefix just
  consumed was `i`, not `a`.

## Consequences

- Widening or narrowing `CI_QUOTE_NAV_KEYS` is a real behavior change (it
  changes exactly which real usage keeps the streak alive vs. resets it),
  not a cosmetic one — treat edits to that table as a live-usage decision.
- Any future streak that needs to "survive across a necessary motion" rather
  than hard-reset on any key should follow this same
  own-tolerance-table-plus-own-reset-check shape.
