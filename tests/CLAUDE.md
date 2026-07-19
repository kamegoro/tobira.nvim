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

**Coverage below 100% means one of two things — fix whichever applies:**
- Lines are reachable but have no test → write the test
- Lines are unreachable (dead code) → delete the code

Using `-- luacov: disable` is prohibited.

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

## patterns.lua handler ordering

In `inner_feed`, the `pending_g` / `pending_z` handlers must appear **before** the `f/F/t/T`
handlers. If they come after, `gf` and `zt` are incorrectly captured as f/t searches.
Apply the same rule to any new two-character command prefix.

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
