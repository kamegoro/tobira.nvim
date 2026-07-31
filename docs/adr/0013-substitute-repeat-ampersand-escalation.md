# Repeated `:substitute` escalates from `&` to `g&` (#115)

## Context

`patterns_cmdline.lua`'s `track_substitute()` detects the user manually re-running
an identical `:s/{pattern}/{replacement}/` body on a second, distinct line — the
"doing search-and-replace one line at a time by hand" signal that `&` (repeat last
substitute on this line) and `g&` (repeat it across the whole file) exist to
shortcut. A single repeat isn't yet worth escalating past `&`; a *third* distinct
line manually re-running the same substitution is a stronger signal that the user
wants the file-wide version, so that case fires `g&` instead of `&` again. See
`patterns_cmdline.lua`'s own header for the exact parsing scope and count logic —
this ADR covers only the two registry entries this feeds.

## Decision

- `requires = 'n'` for `'&'`: mirrors `'cgn'` in spirit — repeated search-match
  navigation without editing is the same "doing this by hand" precursor that
  search-and-replace features build on. `track = true`: `&` is a single literal
  keystroke with a real Vim meaning of its own, so the generic TRACK table must
  count it like any other single-char command.
- `requires = '&'` for `'g&'`: `g&` is the natural next step once `&` is known.
  `track = false`: a 2-char literal sequence with no `pending_g` dispatch entry
  recording it (same shape as `gu`/`g~`/`gg`).
- `'g&'` is **not** marked `ambient = false` the way `<C-\><C-n>` is (see
  `docs/adr/0007-reactive-only-ambient-exclusion.md`): its body is a generic,
  standalone "did you know" tip (same shape as `cgn`/`ex:g`) that reads sensibly
  even surfaced ambiently from `&` usage alone. It doesn't presuppose a
  just-happened event the way `<C-\><C-n>`'s body does, and `&`'s count is a real,
  incrementable signal rather than structurally stuck at 0.

## Consequences

- Don't copy the `ambient = false` flag onto `g&` by analogy with `<C-\><C-n>` —
  the two only look similar (both are "next step after a reactively-detected
  pattern"); the ambient-exclusion criteria in ADR 0007 don't actually apply here.
- A future 3-tier escalation pattern (like this one) should default to **not**
  needing `ambient = false` on its final tier unless that tier's body specifically
  presupposes the triggering event, per ADR 0007's two-part test.
