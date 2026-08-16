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

## Regression suites (`tests/regression/`)

A directory sibling to `tests/spec/`, excluded from `tests/spec/`'s own scan
path because some of its `it()` blocks intentionally fail (tracking real,
still-open bugs — see below).

**Wired into `.github/workflows/ci.yml` as a non-blocking job** (`continue-on-error: true`):
it runs and reports on every PR, but doesn't block merges on bugs unrelated to
that PR. Once every `KNOWN FAILING` block below is fixed and passes for real,
remove `continue-on-error` from the `regression` job so this suite becomes a
real gate like `tests/spec/`. Run manually the same way CI does:

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/regression/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

Unlike `tests/spec/*_spec.lua`, some `it()` blocks in these suites are
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

### Realistic-scale fixture suite (`realistic_scale_spec.lua`)

Runs `graph.find_best()` / `graph.efficiency_gaps()` / `graph.guide_commands()`
/ `graph.is_forgotten()` / `graph.is_mastered()` against a deterministic,
seeded, realistic-scale generated `usage.json` fixture (`fixture.lua`) and
asserts product-level invariants — see #317 / the #315 umbrella for why:
several real bugs (#290–#292, #307) only manifested at realistic accumulated
scale or duration (10+ simulated session boundaries), which the thin
hand-picked fixtures above (`graph_spec.lua` etc.) structurally cannot
reproduce.

### Long-session resource-bound suite (`long_session_resource_spec.lua`)

Drives a single ~2200-real-keystroke scripted session through the real
`vim.on_key()` dispatch path (`vim.fn.feedkeys()`/`nvim_feedkeys()`, never a
direct call into `suggest.lua`'s or `logger.lua`'s internals) and asserts
bounded resource usage at the end versus a session-start baseline — see #318
/ the #315 umbrella for why: leaks that only manifest over a sustained
session (unbounded `vim.on_key` namespace growth, unbounded per-session state
tables) can't be caught by short, thin fixtures either. All four `it()`
blocks now pass for real. Two formerly tracked issues that are now both
fixed: #310 (`suggest.lua`'s `watch_adoption()` leaking a `vim.on_key`
namespace per shown, un-adopted suggestion — see
docs/adr/0112-unified-suggestion-scheduling.md) and #314
(`patterns_cmdline.lua`'s substitute/history-recall tracking tables growing
without eviction — see docs/adr/0110-cmdline-state-lru-eviction.md). The
remaining two lock in `patterns_insert.lua`'s already-correct
completion-ring cap as a regression guard. All four are kept as permanent
regression guards going forward.

## Differential testing for patterns.lua's seq state machine (`tests/differential/`)

A separate suite, sibling to `tests/spec/`, that runs randomized-but-realistic
keystroke sequences through both the real `patterns.lua` dispatch and a
deliberately simple, independently-written reference model
(`tests/differential/reference_model.lua`), asserting the two agree on every
keystroke — see #316 / the #315 umbrella for the technique and rationale.
`tests/differential/generator.lua` is the seedable keystroke generator;
`tests/differential/real_model.lua` replays the real dispatch;
`tests/differential/patterns_seq_differential_spec.lua` is the test itself.

**Wired into `.github/workflows/ci.yml`'s `test` job as a real, blocking gate**
— every `it()` block here passes for real (unlike `tests/regression/`), so
this suite runs alongside `tests/spec/` on every PR with no `continue-on-error`.
Run it manually the same way CI does:

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

Two classes of divergence against the deliberately-simpler reference model
are classified rather than failing the suite outright — a macro_opportunity/
visual_block_opportunity dispatch-priority collision, and an already-tracked
pattern firing on a different keystroke than this model expects (broader
than any one bug — see the spec file's own header comment for the two
originating issues, #312 and #313, both now fixed).

**Do not run this suite with `COVERAGE=1`.** luacov's per-line instrumentation
slows this suite by roughly two orders of magnitude (measured: ~0.5s normally,
50+ seconds instrumented), which exceeds plenary.nvim's own default 50-second
per-spec-file job timeout and kills the child process before it reports
anything — this is what broke this suite's introducing PR's Coverage CI job
before the suite was moved out of `tests/spec/`. `tests/` is excluded from
the coverage gate by `.luacov` anyway, so there is nothing to measure here.

### Two scaling tiers: PR-blocking default vs. opt-in high-scale (#343)

Every spec file under `tests/differential/` (seq, insert, cmdline, terminal)
reads its seed count the same way:

```lua
local SEED_COUNT = tonumber(os.getenv('TOBIRA_DIFFERENTIAL_SEEDS')) or 150
```

`BASE_SEED` is left untouched per file — it anchors the pinned,
deterministic repro scenarios documented in each spec's own header/comments,
which are independent of `SEED_COUNT` and must never be disturbed by a seed
count or seed offset change.

- **Tier 1 — committed default (150 seeds), blocking every PR.** This is
  what runs with no environment variable set, including the `test` job
  command above. Chosen to stay well under plenary's 50s per-spec-file
  timeout (~12s for the heaviest file alone, ~15-20s for the whole
  directory) while giving meaningfully more coverage than the old
  `SEED_COUNT = 60`.
- **Tier 2 — opt-in high-scale run, `TOBIRA_DIFFERENTIAL_SEEDS`.** Set this
  env var before invoking the same command to run at any scale, e.g.
  `TOBIRA_DIFFERENTIAL_SEEDS=20000`. This is what the `differential-stress`
  job in `.github/workflows/ci.yml` does — it is **not** part of the
  `push`/`pull_request`-triggered gate; it only runs on a nightly `schedule`
  cron and on manual `workflow_dispatch`, with a correspondingly increased
  plenary `timeout` opt (60 minutes) so a run at this scale doesn't get
  killed mid-way. The scale (tens of thousands of seeds) is informed by what
  QA agents on this project have actually run ad hoc during PR review and
  found real bugs at (see #343) — this tier commits that stress-testing
  practice to a recurring, permanent job instead of leaving it as one-off,
  uncommitted QA passes.

Run tier 2 locally the same way, e.g. at a smaller multiple to sanity-check
before trusting the nightly run:

```bash
TOBIRA_DIFFERENTIAL_SEEDS=2000 nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true, timeout = 300000}"
```

Raise the `timeout` opt above 150's when running higher seed counts locally
— plenary's default 50s per-file timeout only comfortably covers tier 1.

#### Ceiling on `TOBIRA_DIFFERENTIAL_SEEDS`: seed-offset band collisions (#346)

Several spec files under `tests/differential/` don't use a single seed loop — they run more
than one, each with its own additive offset off `BASE_SEED` (e.g.
`patterns_seq_differential_spec.lua` uses `BASE_SEED+i`, `+100000+i`, `+200000+i`,
`+300000+i`), to keep each loop's generator state independent of the others. A loop that
runs `SEED_COUNT` times starting at `offset` covers the seed range `[offset+1,
offset+SEED_COUNT]` — so if `TOBIRA_DIFFERENTIAL_SEEDS` is ever raised enough that
`SEED_COUNT` reaches the gap between two of a file's own offsets, one band's range grows
into the next band's territory and both loops start silently re-running (part of) the same
seeds instead of covering new ones. This would NOT show up as a test failure — just reduced
effective coverage with no visible error.

Every `*_differential_spec.lua` file that uses more than one band therefore calls
`tests/differential/seed_bands.lua`'s `assert_no_band_collision(SEED_COUNT, offsets)` right
after computing `SEED_COUNT`, which raises a real Lua `error()` (not a silent clamp) if
`SEED_COUNT` would make its own bands collide. The threshold is per file, derived from that
file's own offsets, not a single hardcoded number:

| File | Bands (offsets) | Fails at `TOBIRA_DIFFERENTIAL_SEEDS >=` |
|---|---|---|
| `patterns_seq_differential_spec.lua` | 0, 100000, 200000, 300000 | 100000 |
| `patterns_insert_differential_spec.lua` | 0, 100000 | 100000 |
| `patterns_cmdline_differential_spec.lua` | 0, 100000 | 100000 |
| `patterns_terminal_differential_spec.lua` | 0 (single band) | never (nothing to collide with) |

Both the committed default (150) and the nightly stress job's value (20000, see above) are
far under every threshold. If you're about to raise `TOBIRA_DIFFERENTIAL_SEEDS` past 100000
for a manual `workflow_dispatch` run, either widen the affected file's offsets first or run
a smaller value — do not remove or weaken this guard to make a large run pass.
`assert_no_band_collision`'s own logic is unit-tested with fake seed counts in
`tests/spec/unit/seed_bands_spec.lua`, not by an actual large-scale differential run.

## Differential testing for patterns_cmdline.lua's cmdline state machine (`tests/differential/`)

A sibling suite to the one above, scoped to `patterns_cmdline.lua`'s four
independent cmdline detectors (`substitute_repeat`/`substitute_repeat_wide`,
`ex_file_pingpong`, `tabnew_run`, `cmdline_history_recall`) — see #330 / the
#327 umbrella for the technique and rationale. Its vocabulary is one complete
submitted command-line STRING per `<CR>` (plus `<Up>`/`<Down>`
history-navigation keystrokes and cancel/restart sessions), not raw
normal-mode keystrokes — a fundamentally different granularity from the seq
suite above, matching how `patterns_cmdline.lua` itself operates (see
`docs/adr/0002-ex-command-tokenizer-one-shot-parsing.md`).
`tests/differential/generator_cmdline.lua` is the seedable session generator;
`tests/differential/reference_model_cmdline.lua` is the independently-written
reference model; `tests/differential/real_model_cmdline.lua` replays the real
`tokenize()`/`command_arg()` and all four real detectors in `logger.lua`'s own
dispatch order; `tests/differential/patterns_cmdline_differential_spec.lua` is
the test itself.

Besides the usual "does the real dispatch agree with the reference model"
check, this suite also directly asserts the mutual-exclusivity-by-construction
claim in `docs/adr/0095-cmdline-history-recall-detection.md` — "for any given
submitted command line, at most one of the four cmdline detectors can ever
return non-nil" — against the real functions (`#fires <= 1` on every
submission), not just the reference model's own routing assumption.

**Wired into `.github/workflows/ci.yml`'s `test` job as a real, blocking gate**,
same as the seq suite above — it lives in the same `tests/differential/`
directory, so the same `PlenaryBustedDirectory tests/differential/` command
already runs both suites (and the insert and terminal differential suites)
together:

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/differential/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

Same `COVERAGE=1` prohibition, same committed-default-vs-opt-in-high-scale
tiering (`TOBIRA_DIFFERENTIAL_SEEDS`), and same `BASE_SEED`-is-never-touched
rule as the seq suite above apply here too — see "Two scaling tiers" above.

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
