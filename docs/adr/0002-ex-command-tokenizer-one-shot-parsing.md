# Ex-command tokenizer: one-shot string at `<CR>`, not incremental parsing (`patterns_cmdline.lua`)

## Context

Ex-command tracking (#57) needs to turn whatever the user typed on the command line
into a stable bucket name (`ex:s`, `ex:g`, `ex:norm`, ...) for usage counting. `vim.on_key`
already sees every cmdline keystroke, and `patterns.lua` already has a per-keystroke
`seq`/`feed` state machine for normal mode — the obvious-looking option was to extend
that same incremental style to the command line.

That doesn't fit here. `<Up>`/`<Down>` cmdline history recall replaces the whole buffer
non-incrementally (not one key at a time), so a manual per-keystroke accumulator cannot
represent it — only `vim.fn.getcmdline()`, read at the terminating keystroke, always can.
`strip_range()` also needs the full range address up front (`%`, `N,M`, `'<,'>`,
`/pat/,/pat2/`) to find where the command word actually starts, which isn't knowable
keystroke-by-keystroke either.

Two further scope questions came up while writing `strip_range()`/`tokenize()`: how much
of Ex's range-address grammar to support, and whether to canonicalize Vim's command
abbreviations (`:s` / `:su` / `:sub` / `:substitute` all mean the same command).

## Decision

- **New sibling module (`patterns_cmdline.lua`), not folded into `patterns.lua`.** It
  shares no state with the normal-mode `seq`/`feed` machine and is never on the same
  call path (`logger.lua` only calls it from `handle_cmdline_key`, gated on
  `getcmdtype() == ':'`) — same "shares nothing → new sibling file" rule as
  `patterns_insert.lua` (#99, see `lua/tobira/CLAUDE.md`'s "Module splitting policy").
- **`tokenize()` takes one already-complete string, handed to it once at `<CR>` time**,
  not a per-keystroke incremental state machine. The `getcmdtype()`/`getcmdline()`
  orchestration deciding *when* to call it lives in `logger.lua`, which already does
  `vim.*` work; this module stays pure.
- **`strip_range()` only covers the range forms actually seen in practice** (`%`, `N`,
  `N,M`, `'<,'>`, `'a,'b`, `/pat/,/pat2/`) — deliberately not a full Vim range-grammar
  parser.
- **Deliberately does NOT canonicalize command abbreviations.** Keying by the literal
  typed word (`:s` and `:sub` become two distinct buckets) avoids silently guessing wrong
  on ambiguous short forms, which would require knowing every Vim command name — this
  feature doesn't need that.

## Consequences

- Touching `patterns.lua` or `patterns_insert.lua` never requires reading
  `patterns_cmdline.lua`, and vice versa.
- Usage counts for abbreviation variants of the same command (`:s` vs `:sub`) are split
  across buckets. This is accepted, not a bug — revisit only if real usage data shows it
  hurts suggestion quality.
- A cmdline range form outside the list above (e.g. some obscure Ex address syntax)
  falls through `strip_range()` unstripped, which can make `tokenize()` return `nil` or a
  wrong word for that input. Extend `strip_range()`'s character set if that's ever
  observed in practice, rather than reaching for a general parser.
