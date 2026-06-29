local suggest = require('tobira.core.suggest')
local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

local function with_float_spy(fn)
  local called = false
  package.loaded['tobira.ui.float'] = {
    show = function()
      called = true
    end,
  }
  local ok, err = pcall(fn)
  package.loaded['tobira.ui.float'] = nil
  assert.is_true(ok, err)
  return called
end

describe('when a command has been adopted by the user', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('never shows it again', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')

    local shown = with_float_spy(function()
      suggest.show(';')
    end)

    assert.is_false(shown)
  end)
end)

describe('when a command has been shown the maximum number of times without adoption', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('stops showing it', function()
    config.setup({ max_shown = 2 })
    logger.mark_shown(';')
    logger.mark_shown(';')

    local shown = with_float_spy(function()
      suggest.show(';')
    end)

    assert.is_false(shown)
  end)

  it('still shows it when shown count is below the limit', function()
    config.setup({ max_shown = 3 })
    logger.mark_shown(';')
    logger.mark_shown(';')

    local shown = with_float_spy(function()
      suggest.show(';')
    end)

    assert.is_true(shown)
  end)
end)

describe('when :Tobira is called but there is nothing new to suggest', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('notifies the user that they are up to date', function()
    local notified = false
    local orig = vim.notify
    vim.notify = function(msg, _)
      if msg:find('no new suggestions') then
        notified = true
      end
    end
    local ok, err = pcall(suggest.manual)
    vim.notify = orig
    assert.is_true(ok, err)
    assert.is_true(notified)
  end)
end)

describe('when show is called a second time in the same session', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does not show the suggestion again', function()
    with_float_spy(function()
      suggest.show(';')
    end)
    local shown = with_float_spy(function()
      suggest.show(';')
    end)
    assert.is_false(shown)
  end)
end)

describe('when the per-session auto suggestion limit is reached', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('stops showing after max_per_session auto suggestions', function()
    config.setup({ max_per_session = 2, min_interval_ms = 0 })
    local shown1 = with_float_spy(function() suggest.show(';') end)
    local shown2 = with_float_spy(function() suggest.show(',') end)
    local shown3 = with_float_spy(function() suggest.show('.') end)
    assert.is_true(shown1)
    assert.is_true(shown2)
    assert.is_false(shown3)
  end)
end)

describe('when manual is called after the auto session limit is reached', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('still shows a suggestion', function()
    config.setup({ max_per_session = 1, min_interval_ms = 0 })
    with_float_spy(function() suggest.show(';') end)
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    local shown = with_float_spy(function() suggest.manual() end)
    assert.is_true(shown)
  end)
end)

describe('when the minimum interval between auto suggestions has not elapsed', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does not show a second auto suggestion before the interval has passed', function()
    config.setup({ min_interval_ms = 3600000 })
    with_float_spy(function() suggest.show(';') end)
    local shown = with_float_spy(function() suggest.show(',') end)
    assert.is_false(shown)
  end)
end)

describe('after reset_session', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('allows showing a suggestion again', function()
    with_float_spy(function()
      suggest.show(';')
    end)
    suggest.reset_session()
    local shown = with_float_spy(function()
      suggest.show(';')
    end)
    assert.is_true(shown)
  end)
end)

describe('when a queued suggestion is cancelled before it fires', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('cleans up without error', function()
    -- Use a very long delay so the timer cannot fire during the test.
    config.setup({ idle_delay = 60000 })
    assert.has_no_error(function()
      suggest.queue('f_repeat', ';')
      suggest.reset_session()
    end)
  end)
end)

describe('when the user presses the suggested command after seeing it', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('makes the command detectable as adopted', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show(';')
    end)
    vim.fn.feedkeys(';', 'x')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get(';')))
  end)
end)

describe('when a suggestion is already on screen', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('queueing another one does nothing', function()
    config.setup({ idle_delay = 60000 })
    with_float_spy(function()
      suggest.show(';')
    end)
    -- session is now in the shown state; queue must bail out immediately.
    assert.has_no_error(function()
      suggest.queue('f_repeat', ',')
    end)
  end)
end)

describe('when queueing a command that should be suppressed', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does not schedule a suggestion', function()
    logger.mark_shown(';')
    logger.mark_adopted(';')
    assert.has_no_error(function()
      suggest.queue('f_repeat', ';')
    end)
  end)
end)

describe('when a command is explicitly suppressed via set_suppressed', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('is never auto-suggested even without adoption', function()
    logger.set_suppressed(';', true)
    local shown = with_float_spy(function() suggest.show(';') end)
    assert.is_false(shown)
  end)

  it('can be auto-suggested again once un-suppressed', function()
    logger.set_suppressed(';', true)
    logger.set_suppressed(';', false)
    local shown = with_float_spy(function() suggest.show(';') end)
    assert.is_true(shown)
  end)
end)

describe('when a queued suggestion reaches the end of the idle delay', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('shows the suggestion', function()
    config.setup({ idle_delay = 10 })
    local shown = false
    package.loaded['tobira.ui.float'] = {
      show = function()
        shown = true
      end,
    }
    suggest.queue('f_repeat', ';')
    vim.wait(500, function()
      return shown
    end, 10)
    package.loaded['tobira.ui.float'] = nil
    assert.is_true(shown)
  end)
end)

describe('when showing a command that has no suggestion entry', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does nothing', function()
    local shown = with_float_spy(function()
      suggest.show('this_command_does_not_exist')
    end)
    assert.is_false(shown)
  end)
end)

describe('when :Tobira is called and a suggestion is available', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('shows the best suggestion', function()
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }

    local shown = with_float_spy(function()
      suggest.manual()
    end)

    assert.is_true(shown)
  end)
end)

describe('when manual is called and the user level limits the suggestion pool', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('only suggests commands appropriate for novice level', function()
    local level_mod = require('tobira.core.level')
    -- Only x is used → novice level → max_level = beginner
    -- x triggers D (beginner) and {n}x (intermediate): only D is eligible
    local usage = logger.get_all()
    usage['x'] = { count = 10, sessions = {}, shown = 0, suppressed = false }
    assert.equals('novice', level_mod.get())
    local shown_cmd = nil
    package.loaded['tobira.ui.float'] = { show = function(sug) shown_cmd = sug.cmd end }
    local ok, err = pcall(suggest.manual)
    package.loaded['tobira.ui.float'] = nil
    assert.is_true(ok, err)
    assert.equals('D', shown_cmd)
  end)
end)
