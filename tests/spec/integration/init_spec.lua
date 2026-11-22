require('tests.isolate_data')

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
-- auto-open goes through vim.defer_fn, so this avoids waiting 300ms and lets
-- us drive the deferred body ourselves for coverage credit.
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

    -- An unparsable usage.json found during setup() itself must already reach
    -- the user, so on_corrupt has to be wired before logger.setup() runs.
    vim.fn.mkdir(vim.fn.fnamemodify(_data_file, ':h'), 'p')
    local cf = io.open(_data_file, 'w')
    cf:write('{"truncated": ')
    cf:close()
    local notified = {}
    local orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notified, { msg = msg, level = level })
    end
    local deferred
    local ok0, err0 = pcall(function()
      deferred = capture_defer(function()
        tobira.setup({})
      end)
    end)
    vim.notify = orig_notify
    assert.is_true(ok0, err0)
    local moved = vim.fn.glob(_data_file .. '.corrupt-*', false, true)
    assert.equals(1, #moved)
    local warnings = vim.tbl_filter(function(n)
      return n.level == vim.log.levels.WARN
    end, notified)
    assert.same({
      { msg = require('tobira.locales.en').notifications.usage_corrupt:format(moved[1]), level = vim.log.levels.WARN },
    }, warnings)
    os.remove(moved[1])

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

    -- integrations.setup() populates the override cache and registers
    -- its own VimEnter/SourcePost augroup.
    local integrations = require('tobira.core.integrations')
    assert.is_table(integrations.get_overrides())
    local autocmds = vim.api.nvim_get_autocmds({ group = 'tobira_integrations' })
    assert.is_true(#autocmds > 0)

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

describe('when the user runs :TobiraReset', function()
  local notified, confirm_answer, confirm_calls
  local orig_notify, orig_confirm
  local str = require('tobira.locales.en').notifications

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.mark_shown('j')
    notified = {}
    confirm_calls = 0
    orig_notify = vim.notify
    orig_confirm = vim.fn.confirm
    vim.notify = function(msg)
      table.insert(notified, msg)
    end
    vim.fn.confirm = function()
      confirm_calls = confirm_calls + 1
      return confirm_answer
    end
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.fn.confirm = orig_confirm
  end)

  local function disk_has_j()
    local f = io.open(_data_file, 'r')
    local disk = vim.json.decode(f:read('*a'))
    f:close()
    return disk.j ~= nil
  end

  it('asks for confirmation and erases the data when confirmed', function()
    confirm_answer = 1
    tobira.reset(false)
    assert.equals(1, confirm_calls)
    assert.same({}, logger.get_all())
    assert.is_false(disk_has_j())
    assert.same({ str.reset }, notified)
  end)

  it('keeps the data when the user declines', function()
    confirm_answer = 2
    tobira.reset(false)
    assert.equals(1, logger.get('j').shown)
    assert.is_true(disk_has_j())
    assert.same({ str.reset_cancelled }, notified)
  end)

  it('keeps the data when the prompt is dismissed with <Esc>', function()
    confirm_answer = 0
    tobira.reset(false)
    assert.is_true(disk_has_j())
  end)

  it('skips the confirmation with :TobiraReset!', function()
    tobira.reset(true)
    assert.equals(0, confirm_calls)
    assert.is_false(disk_has_j())
    assert.same({ str.reset }, notified)
  end)

  it('is wired to the :TobiraReset command', function()
    vim.cmd('runtime plugin/tobira.lua')
    vim.cmd('TobiraReset!')
    assert.is_false(disk_has_j())
    assert.equals(0, confirm_calls)
  end)
end)
