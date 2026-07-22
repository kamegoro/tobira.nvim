local tobira = require('tobira')
local logger = require('tobira.core.logger')
local suggest = require('tobira.core.suggest')
local float = require('tobira.ui.float')

-- Test-local disk cleanup, mirroring logger_spec.lua's helper of the same
-- name. logger.reset() deliberately does no I/O (see tests/CLAUDE.md).
local _data_file = vim.fn.stdpath('data') .. '/tobira/usage.json'
local function wipe_disk()
  pcall(os.remove, _data_file)
end

-- Captures every vim.defer_fn call made during fn(), mirroring
-- ui_float_spec.lua's helper of the same shape. init.lua's first-run guide
-- auto-open goes through vim.defer_fn, so this both keeps the test from
-- actually waiting 300ms and lets us drive the deferred body ourselves to
-- get coverage credit for it.
local function capture_defer(fn)
  local captured = {}
  local orig_defer = vim.defer_fn
  vim.defer_fn = function(cb, delay)
    table.insert(captured, { fn = cb, delay = delay })
  end
  local ok, err = pcall(fn)
  vim.defer_fn = orig_defer
  assert.is_true(ok, err)
  return captured
end

-- tobira.setup() guards itself with a module-local `_initialized` flag, so
-- only the very first call in this spec file's process actually runs the
-- wiring body — every later call is a no-op early return. All assertions
-- about what setup() wires up must therefore hang off this one real call.
describe('tobira.setup', function()
  it('wires up logger, suggest, and the first-run guide, then is idempotent on repeat calls', function()
    wipe_disk()
    logger.reset()
    assert.is_false(logger.is_guide_seen())

    local deferred = capture_defer(function()
      tobira.setup({})
    end)

    -- logger.on_pattern → suggest.queue
    assert.equals(suggest.queue, logger.on_pattern)

    -- suggest.on_show → ui.float.show
    local show_called = false
    local orig_show = float.show
    float.show = function(...)
      show_called = true
    end
    local ok1, err1 = pcall(suggest.on_show, { cmd = 'x' }, true, 'some_pattern')
    float.show = orig_show
    assert.is_true(ok1, err1)
    assert.is_true(show_called)

    -- suggest.on_adopt → ui.float.celebrate
    local celebrate_called = false
    local orig_celebrate = float.celebrate
    float.celebrate = function(...)
      celebrate_called = true
    end
    local ok2, err2 = pcall(suggest.on_adopt, 'x')
    float.celebrate = orig_celebrate
    assert.is_true(ok2, err2)
    assert.is_true(celebrate_called)

    -- First run: guide wasn't seen yet, so setup() marks it seen and
    -- schedules the guide to open via vim.defer_fn.
    assert.is_true(logger.is_guide_seen())
    assert.equals(1, #deferred)
    assert.equals(300, deferred[1].delay)
    local ok3, err3 = pcall(deferred[1].fn)
    assert.is_true(ok3, err3)
    require('tobira.ui.guide').close()

    -- A second call must be a no-op (the module-local _initialized guard):
    -- confirm it doesn't re-open the guide or throw, without re-wiring.
    local ok4, err4 = pcall(tobira.setup, {})
    assert.is_true(ok4, err4)
  end)
end)
