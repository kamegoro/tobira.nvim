# tests/ — CLAUDE.md

## TDD cycle (mandatory)

1. **Red** — Write a failing test first. Run it and confirm it fails before writing any implementation.
2. **Green** — Write the minimum code to make it pass. Run all tests.
3. **Refactor** — Clean up with tests still green.

## What to test per change

| Change | Required tests |
|---|---|
| New normal-mode pattern in `patterns.lua` | `patterns_spec.lua`: unit test for the pure function |
| New insert-mode pattern in `patterns_insert.lua` | `patterns_insert_spec.lua`: unit test for the pure function |
| New cmdline (Ex-command) pattern in `patterns_cmdline.lua` | `patterns_cmdline_spec.lua`: unit test for the pure function (#57) |
| New terminal-mode pattern in `patterns_terminal.lua` | `patterns_terminal_spec.lua`: unit test for the pure function (#110) |
| New entry in `graph.suggestions` | `graph_spec.lua`: scoring + field validation |
| Data management change in `logger.lua` | `logger_spec.lua`: mark / get / reset behavior |
| Suppression or cooldown change in `suggest.lua` | `suggest_spec.lua`: show / suppress boundary conditions |
| Bug fix | Write a test that reproduces the bug before fixing it |

## Running tests locally (all four steps required before every push)

```bash
# 1. format check
stylua --check lua/ plugin/

# 2. lint
selene --display-style=quiet lua/ plugin/

# 3. test suite
# sequential = true is required — parallel execution makes logger_spec flaky
# minimal_init = ... is required — without it stdpath('data') override does not apply
#   and tests would read/write the real ~/.local/share/nvim/tobira/usage.json
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua', sequential = true}" 2>&1

# 4. coverage — every module must reach 100%
rm -f luacov.stats.out luacov.report.out
COVERAGE=1 nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua', sequential = true}" 2>&1
~/.luarocks/bin/luacov
grep 'Total' luacov.report.out   # must be 100.00%
```

## Realistic-scale regression suite (`tests/regression/`)

A separate suite, sibling to `tests/spec/`, that runs `graph.find_best()` /
`graph.efficiency_gaps()` / `graph.guide_commands()` / `graph.is_forgotten()` /
`graph.is_mastered()` against a deterministic, seeded, realistic-scale
generated `usage.json` fixture (`tests/regression/fixture.lua`) and asserts
product-level invariants — see #317 / the #315 umbrella for why: several real
bugs (#290–#292, #307) only manifested at realistic accumulated scale or
duration (10+ simulated session boundaries), which the thin hand-picked
fixtures above (`graph_spec.lua` etc.) structurally cannot reproduce.

**Deliberately not wired into `.github/workflows/ci.yml`** — CI wiring for
all of #315's sub-issues is a separate follow-up. Run it manually:

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/regression/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

Unlike `tests/spec/*_spec.lua`, some `it()` blocks in this suite are
**expected to currently fail** — they are regression trackers for real,
already-filed, still-open bugs, clearly marked `KNOWN FAILING` with the issue
number they track. Do not `pending()`/skip/delete a `KNOWN FAILING` test:
plenary's `pending()` never even executes the test body (see
`plenary/busted.lua`'s `mod.pending`), which would silently stop exercising
the real code path this suite exists to guard. Each should start passing
with no changes needed once its referenced issue is fixed.

**Coverage below 100% means one of two things — fix whichever applies:**
- Lines are reachable but have no test → write the test
- Lines are unreachable (dead code) → delete the code

Using `-- luacov: disable` is prohibited.

## Differential testing for patterns.lua's seq state machine (`tests/differential/`)

A separate suite, sibling to `tests/spec/`, that runs randomized-but-realistic
keystroke sequences through both the real `patterns.lua` dispatch and a
deliberately simple, independently-written reference model
(`tests/differential/reference_model.lua`), asserting the two agree on every
keystroke — see #316 / the #315 umbrella for the technique and rationale.
`tests/differential/generator.lua` is the seedable keystroke generator;
`tests/differential/real_model.lua` replays the real dispatch;
`tests/differential/patterns_seq_differential_spec.lua` is the test itself.

**Deliberately not wired into `.github/workflows/ci.yml`** — same reason and
same shape as the realistic-scale regression suite above: CI wiring for all
of #315's sub-issues is a separate follow-up. Run it manually:

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

Known-expected divergences (currently #312 and #313) are classified and
asserted as such rather than failing the suite — see the spec file's own
header comment.

**Do not run this suite with `COVERAGE=1`.** luacov's per-line instrumentation
slows this suite by roughly two orders of magnitude (measured: ~0.5s normally,
50+ seconds instrumented), which exceeds plenary.nvim's own default 50-second
per-spec-file job timeout and kills the child process before it reports
anything — this is what broke this suite's introducing PR's Coverage CI job
before the suite was moved out of `tests/spec/`. `tests/` is excluded from
the coverage gate by `.luacov` anyway, so there is nothing to measure here.

## Smoke test for `track = true` commands

Every command with `track = true` in `commands.lua` must have a smoke test in `logger_spec.lua`:

```lua
it('increments the usage count for <CMD>', function()
  pcall(vim.fn.feedkeys, '<CMD>', 'xt')
  pcall(vim.api.nvim_feedkeys, '', 'x', false)
  assert.is_true(logger.get('<CMD>').count > 0)
end)
```

Use `'xt'` flags, not `'x'`. The `t` flag makes the key appear as user-typed (`typed ~= ''`).
Without it the logger's typed filter drops it and the count never increments.

## Patterns unit test template

```lua
it('fires X_pattern when ...', function()
  local seq = patterns.new_seq()
  patterns.feed(seq, 'setup_key', 1)
  local result = patterns.feed(seq, 'trigger_key', 1)
  assert.equals('X_pattern', result.pattern)
  assert.equals('XY', result.cmd)
end)
```

Assert both `result.pattern` and `result.cmd`. Asserting only `cmd` won't catch a broken
connection between pattern detection and the suggestion engine.

This template alone is not sufficient proof of correctness for every pattern — see
"Real-keystroke tests for state/timing-sensitive patterns" below.

## Real-keystroke tests for state/timing-sensitive patterns

A `patterns.feed()` direct-call test only proves the pure state machine handles the exact
sequence you hand it. It cannot catch bugs in how `logger.lua` assembles that call from
real Neovim state — cursor position, buffer content, window state, or the order/timing of
`vim.on_key()` versus when Neovim actually applies the keystroke.

**Rule:** if a pattern's correctness depends on any of the above (not just the sequence of
key names), it must have at least one test that drives real keystrokes through
`vim.fn.feedkeys()`/`nvim_feedkeys()` and the real `vim.on_key()` pipeline, in
`tests/spec/integration/`. A direct-call test alone does not satisfy this — but direct-call
tests stay the default and stay required for the pure sequence logic itself; this rule adds
to that, it doesn't replace it.

**Concrete example — the `gj`/`gk` landing-line bug (PR #289's independent QA):**
`logger.lua`'s `current_line_is_wrapped()` originally read `vim.fn.getline('.')` — the
cursor's line at the moment `vim.on_key()` fired. But `vim.on_key()` fires *before* Neovim
applies the keystroke, so at call time the cursor was still on the line the streak was
leaving, not the line the 5th `j`/`k` was about to land it on:

```lua
-- ❌ shipped: reads the departure line (cursor hasn't moved yet when vim.on_key fires)
local display_width = vim.fn.strdisplaywidth(vim.fn.getline('.'))

-- ✅ fixed: reads the landing line the keystroke is about to move the cursor to
local target = key == 'j' and math.min(cur + 1, last) or math.max(cur - 1, 1)
local display_width = vim.fn.strdisplaywidth(vim.fn.getline(target))
```

The two shipped unit tests used a single-line buffer, so the departure line and the
landing line were always identical — the bug was invisible to them. It only surfaced when
QA built a multi-line buffer and drove `vim.fn.feedkeys('jjjjj', 'xt')` through the real
`vim.on_key()` pipeline.

Other bugs this rule would have caught earlier, also found only by driving real keystrokes
through the real dispatch path rather than calling `patterns.feed()` directly: the
register/mark/f-F-t-T dispatch-ordering collisions (#257 and siblings), and the
`key_consumed` gaps (#253/#277).

## patterns.lua handler ordering

In `inner_feed`, the `pending_g` / `pending_z` handlers must appear **before** the `f/F/t/T`
handlers. If they come after, `gf` and `zt` are incorrectly captured as f/t searches.
The same rule applies to `pending_register` / `pending_mark` / `pending_bracket` (#257),
`pending_text_obj` (#254 follow-up, for `cit`/`dit`'s `t`), `pending_r` (independent QA
finding on PR #277, for `rt`/`rf`'s replacement character), and the visual text-object
tracking block (`pending_visual`/`visual_inner`/`visual_obj` — independent QA finding on
PR #277, for `vit`/`vat`'s `t`). Apply the same rule to any new two-or-more-key command
prefix. Write a test that types the colliding character mid-prefix (e.g. `"tyy`, `cit`,
`rt`, or `vit`) and asserts the prefix's own state won, not the f/t handler's.

Every such consumer must also set `seq.key_consumed = true` on the call that resolves it
(independent QA finding on PR #277) — `pending_text_obj` was missing this even after
#253/#254 shipped, so its completing key kept double-counting as a bare keystroke on top
of the correct compound/variant increment (`usage['w'].count` still inflating on every
`ciw`/`diw`/`yiw`, the exact defect #253 reports). Write a test asserting `s.key_consumed`
is true after the prefix resolves, not just that the right pattern/state fired.

## Testing non-normal mode in headless Neovim

`vim.fn.mode()` always returns `'n'` in headless Neovim — you cannot enter insert mode via
feedkeys. To cover a branch that only fires in non-normal mode, stub `vim.fn.mode`:

```lua
local real_mode = vim.fn.mode
vim.fn.mode = function() return 'i' end
vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })  -- updates logger's mode cache
vim.fn.mode = real_mode
-- feed a key here — logger now sees mode = 'i'
```

## Test quality standards

**Before writing a test, ask:**

1. Does this test describe observable behavior, not an internal implementation detail?
2. Can the test name be read as `describe("when X") / it("Y happens")`?
3. Is there exactly one concept per `it()` block?
4. Would passing this test require adding test-only hooks to production code? (If yes, redesign.)

**describe / it naming:**

```lua
-- ✅ describes behavior
describe('when the user has already adopted a suggestion', function()
  it('never shows it again', function() ... end)
end)

-- ❌ describes implementation
describe('logger.mark_adopted', function()
  it('sets adopted to true', function() ... end)
end)
```

**Mock / spy cleanup — always restore, even on exception:**

```lua
-- ✅ pcall ensures cleanup runs even if the test throws
local function with_float_spy(fn)
  local called = false
  package.loaded['tobira.ui.float'] = { show = function() called = true end }
  local ok, err = pcall(fn)
  package.loaded['tobira.ui.float'] = nil
  assert.is_true(ok, err)
  return called
end

-- ❌ leaked on exception
local orig = vim.notify
vim.notify = function(...) end
some_function()    -- if this throws, vim.notify stays replaced forever
vim.notify = orig
```

**No I/O in tests:**

```lua
-- ✅ reset() restores in-memory state only
logger.reset()

-- ❌ every before_each writes to disk
function M.reset()
  usage = {}
  save()  -- never call save() inside reset()
end
```

**No test-only hooks in production code:**

```lua
-- ✅ expose a pure function and call it directly from the test
-- patterns.lua: patterns.feed(seq, key, line) -> result
-- patterns_spec.lua: local result = patterns.feed(seq, 'x', 1)

-- ❌ adds a test-only entry point to production code
function M.simulate_keys(keys)
  for _, k in ipairs(keys) do handle_key(k) end
end
```

## Commit checklist

- [ ] `describe` / `it` names describe behavior in English
- [ ] `before_each` blocks are inside a `describe` block, not at the top level
- [ ] every mock / patch is restored via `pcall` or `after_each`
- [ ] `reset()` and other helpers do not trigger I/O
- [ ] no test-only functions or flags in production code
- [ ] each `it()` has exactly one concept
- [ ] assertions are specific (`assert.equals(1, #list)` not `assert.is_true(#list > 0)`)
- [ ] no lines hidden with `-- luacov: disable`
- [ ] `pairs()` iteration order is never asserted (non-deterministic across platforms)
- [ ] patterns depending on cursor/buffer/window state or `vim.on_key()` timing have a
      real-feedkeys test, not only a direct `patterns.feed()` test (see "Real-keystroke
      tests for state/timing-sensitive patterns" above)
