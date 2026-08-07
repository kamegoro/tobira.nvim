# Distinguishing Neovim's own default mappings from user overrides via keymap sid (#255)

## Context

`integrations.lua`'s `M.refresh()` treats any entry `nvim_get_keymap('n')` returns for a
watched key as a user override — the only exception is the small curated `EQUIVALENT_REMAPS`
table (`Y`, `%`), which decides whether an override is close enough to still teach, not
whether it's an override at all.

This conflates two very different things. `nvim_get_keymap()` also returns mappings Neovim
ships as its own factory defaults: `$VIMRUNTIME/lua/vim/_defaults.lua` registers `gx`
(open file/URL under cursor), `]q`/`[q`/`]l`/`[l` (quickfix/location-list navigation), `&`
(repeat last `:substitute`), and — on Neovim 0.10+ — even `Y` (`y$`, not the Vi-compatible
`yy`). None of these were touched by the user; they're just what a fresh install already
does. Before this fix, every one of them read as "overridden, not equivalent" on a
completely vanilla `nvim -u NONE`, which silently killed their suggestions on
`find_best()`, `efficiency_gaps()`, and `:TobiraGuide`'s auto section for every user, on
every modern Neovim — see #255's repro.

Two fixes were on the table:

- **(a) Structural**: distinguish "Neovim's own untouched default" from "something has
  touched this key" at the data-source level, so the fix covers every current *and future*
  default-mapped entry automatically.
- **(b) Curated**: extend `EQUIVALENT_REMAPS`-style hardcoding to the specific keys named in
  #255 (`gx`, `&`, `]q`, `[q`, `]l`, `[l`).

The issue itself flagged two candidate shapes for (a) — and flagged both as risking
fragility:

- Spawn a clean `nvim -u NONE --cmd 'set rtp^=...'` subprocess once and diff its keymap
  snapshot against the live one. Rejected: real subprocess-spawn latency on every session
  (or a cache-invalidation problem to avoid it), and a new failure mode in sandboxed/CI
  environments where spawning a second Neovim process may not be permitted at all.
- Parse `:verbose nmap`'s "Last set from ..." text to identify Neovim's own runtime files.
  Rejected outright by the issue itself: this output's format is not a stable contract
  across Neovim versions/locales, exactly the kind of fragility this codebase's ADRs
  consistently avoid (see e.g. the reasoning against text-parsing approaches elsewhere in
  `docs/adr/`).

## Decision

Use structural fix (a), but via a third mechanism neither candidate above considered:
`nvim_get_keymap()`'s own `sid` field (script ID — a long-standing, publicly-returned part
of the `maparg()`/`nvim_get_keymap()` dict, not something scraped from text output).

Empirically verified against a vanilla `nvim -u NONE` (Neovim 0.12.4, and re-verified live
with default runtime plugins loaded per this PR's regression pass):

- Every one of Neovim's own `_defaults.lua`-registered mappings (`gx`, `&`, `]q`, `[q`,
  `]l`, `[l`, `Y`) reports `sid == -8`, regardless of whether its current implementation is
  a literal rhs string (`&` → `:&&<CR>`) or a Lua callback (`gx`). `-8` is Vim/Neovim's
  long-standing internal sentinel for "registered directly via the Lua/C API with no
  attached sourced script" — the same mechanism Neovim's own boot-time default
  registration uses, as opposed to `:source`-ing a real file.
- Any mapping set from a genuinely sourced script — the user's own `init.lua`, a
  lazy-loaded plugin file, or even a Neovim-*shipped-but-separately-sourced* runtime
  plugin like `matchit.vim` (auto-loaded via `packadd`) — gets a normal positive `sid`
  instead (that script's own id). Verified directly: matchit's `%` mapping shows a real
  positive `sid`, not `-8`, so the existing `EQUIVALENT_REMAPS` handling for `%` is
  untouched and still necessary.
- A mapping set interactively (e.g. typed at the command line with no script context) gets
  its own distinct negative sentinel (`-3`, observed), never `-8` — so this doesn't
  accidentally lump "no script" together with "Neovim's own defaults."

`M.refresh()` now skips recording an override entirely (does not add it to `_overrides` at
all) when `map.sid == NVIM_BUILTIN_DEFAULT_SID` (`-8`). This is structurally different from
`EQUIVALENT_REMAPS`: that table answers "is this *user's own* remap close enough to still
teach"; this check answers "did the user (or any script) do anything here at all." A key
whose current mapping matches this sentinel isn't merely equivalent — it was never
overridden in the first place, so it falls outside `docs/adr/0030-keymap-override-exclusion-contract.md`'s
"any candidate whose key appears in `overrides`" exclusion rule entirely, the same as a key
with no mapping at all.

`EQUIVALENT_REMAPS` is kept as-is (not extended, not removed). It remains necessary for: a
user who *explicitly* re-establishes `nnoremap Y y$` themselves (redundant with the modern
default, but sourced from their own script, so it gets a real positive `sid`); Neovim
versions older than 0.10, where `Y` isn't a factory default yet; and matchit's `%`, a real
sourced runtime plugin. None of these are "untouched defaults," so none are affected by the
new check.

A mapping with no `sid` field at all (older Neovim, or a test fixture that doesn't set one)
safely falls through to "not the sentinel" — i.e. exactly the pre-fix, conservative "assume
override" behavior. This is a deliberate fail-safe: the worst case if this signal ever
becomes unavailable or wrong is under-suggesting (today's behavior), never suggesting a key
that's actually been remapped.

## Consequences

- `Y` is no longer permanently excluded from `find_best()`/`efficiency_gaps()` on modern
  Neovim just because Neovim itself now defaults it to `y$` — it can be proactively
  suggested again on an untouched install, closing the gap #255 called out explicitly
  ("Even `Y` ... can never be proactively suggested on any modern Neovim, for any user").
- This fix generalizes: any *future* key Neovim adds to `_defaults.lua` gets this same
  correct treatment automatically, with no new curated-table entry required — the
  motivating reason to prefer (a) over (b) here.
- The `-8` sentinel value itself is an implementation detail of Neovim's script-ID scheme,
  not a documented public contract with a compatibility guarantee. It was verified against
  the locally available Neovim 0.12.4 and is expected to be stable (this negative-sid
  scheme — distinct sentinels for modeline/cmdarg/env/lua-api-etc. sources — has existed
  for many Vim/Neovim releases), and this repo's CI matrix runs both Neovim stable and
  nightly on every change, so a future value change would surface as a real, visible CI
  regression (default-mapped keys wrongly excluded again) rather than silently — the same
  bounded, verify-if-it-breaks posture `docs/adr/0052-equivalent-remap-distinction.md`
  already accepts for its own hand-curated table.
- If a future Neovim version ever repurposes `sid == -8` for something else entirely (not
  just adds more sources), the fallback behavior described above means this degrades to
  today's pre-fix state, not to a false "not overridden" for a real user remap — i.e. it
  cannot make override detection *less* safe, only less helpful in the worst case.
