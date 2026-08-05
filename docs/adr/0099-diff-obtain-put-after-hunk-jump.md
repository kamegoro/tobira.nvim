# Diff obtain/put after a hunk jump → `do`/`dp` (#237)

## Context

`do`/`dp` (diff obtain/put — copy a change from/to the other diff buffer) were not
registered in `commands.lua` at all. tobira already has diff-mode awareness: `is_diff`
(read from `vim.wo.diff` in `logger.lua`) is threaded into `patterns.feed()` as a plain
parameter, currently only consulted by the `j_many`/`k_many` → `]c`/`[c` gate (ADR 0011).
The target shape: a user jumps to a diff hunk with `]c`/`[c`, then manually retypes the
change by hand in insert mode instead of using `do`/`dp` to copy the whole hunk at once.

`]c`/`[c` themselves are consumed generically by `pending_bracket` — the existing
consumer never recorded *which* bracket pair was pressed, only that some `[`/`]` pair
was consumed (`seq.pending_bracket = true`, then discarded).

## Decision

- `pending_bracket` now stores the bracket character itself (`'['` or `']'`) instead of a
  plain `true`. This is a safe, backward-compatible change: every existing consumer only
  ever checked truthiness, and a non-nil string is just as truthy as `true`.
- When the bracket-pair's second key resolves to `'c'` (i.e. `]c`/`[c`), the consumer now
  arms `seq.diff_jump_dir` to the bracket character. Any other second key (`]]`, `[{`,
  etc.) clears it.
- A new check — placed alongside the other `last_op == X and INSERT_KEYS[key]` checks
  (`dd_then_insert`, `dw_then_insert`) — fires `diff_jump_then_insert_next`/`_prev` (cmd
  `do`/`dp`) when `is_diff` is true, `diff_jump_dir` is armed, and the very next key is an
  `INSERT_KEYS` member. `is_diff` is checked at fire time (not arm time), matching ADR
  0011's own convention of reading the diff flag where the suggestion actually fires.
- `diff_jump_dir` is cleared unconditionally by the general end-of-function reset block
  (the same block that clears `last_op`/`dd_streak`/etc. for any key that reaches it),
  enforcing "immediately following" — any intervening key before the insert-mode entry
  cancels the opportunity, exactly like `dd_then_insert`/`dw_then_insert` already behave
  via `last_op`.
- Direction mapping (`]c` → `do`, `[c` → `dp`) is a judgment call: patterns.lua has no
  buffer-diffing capability to know which side actually has the "right" version, so which
  bracket was pressed is the only available signal, and is used as a simple, deterministic
  proxy.
- `do`/`dp` registered in `commands.lua`, category `diff`, requiring `]c`/`[c`
  respectively — added to `commands_spec.lua`'s `KNOWN_DEFERRED` list alongside the
  existing bracket-pair entries (`[(`/`])`), since `pending_bracket`'s consume-and-discard
  design (now consume-and-record-direction, but still not a `last_op`/`op_completed`
  write) means `]c`/`[c` themselves have no tracking path other than reactive suggestion.
- **Bug caught by live tmux QA, not unit tests**: `logger.lua`'s `is_diff` computation
  (`local is_diff = (key == 'j' or key == 'k') and vim.wo.diff or false`) was a
  pre-existing hot-path optimization from ADR 0011, when `j`/`k` were the *only* keys any
  `is_diff` branch ever consulted. This pattern's insert-key check needs `is_diff` to be
  correctly computed for `i`/`I`/`a`/`A`/`o`/`O`/`s`/`S` too — with the old gate, `is_diff`
  was silently `false` for every one of those keys, so `diff_jump_then_insert_next`/`_prev`
  could never fire in real usage despite passing every unit test (which call
  `patterns.feed()` directly with `is_diff` supplied as a literal `true`, bypassing
  `logger.lua`'s gate entirely). Fixed by widening the gate to a `DIFF_GATE_KEYS` table
  (`j`/`k` plus the insert-entry keys) in `logger.lua`, with a regression test in
  `logger_spec.lua` that goes through the real `vim.on_key` wiring instead of calling
  `patterns.feed()` directly.

## Consequences

- `pending_bracket` now carries direction-specific meaning for one narrow case (`]c`/
  `[c`); any future bracket-pair-specific detection should extend the same field rather
  than adding a parallel one.
- The `do`/`dp` direction mapping is not semantically rigorous (real diff obtain/put
  direction depends on which side has the wanted content, not which arrow you jumped
  with) — a future revision with actual buffer-content awareness could refine this, but
  is out of scope for a keystroke-only detector.
- Any future pattern that adds a new `is_diff`-consulting branch to `patterns.lua` must
  also update `logger.lua`'s `DIFF_GATE_KEYS` table for whatever key(s) that branch reads
  `is_diff` on — the parameter silently defaults to `false` for any key not in that gate,
  and `patterns_spec.lua`'s unit tests cannot catch a missing entry since they supply
  `is_diff` directly. Prefer a `logger_spec.lua` integration test (through the real
  `vim.on_key` path) for any new `is_diff` consumer, not just a `patterns_spec.lua` one.
