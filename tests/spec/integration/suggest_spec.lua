local suggest = require('tobira.core.suggest')
local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

-- Assign a spy directly to the display sink. Restored (nil) after the block
-- so subsequent tests start clean. Mirrors init.lua's wiring point.
local function with_float_spy(fn)
  local called = false
  local prev = suggest.on_show
  suggest.on_show = function()
    called = true
  end
  local ok, err = pcall(fn)
  suggest.on_show = prev
  assert.is_true(ok, err)
  return called
end

-- Spy that also records the focused flag passed to on_show.
local function with_focused_spy(fn)
  local result = { called = false, focused = nil }
  local prev = suggest.on_show
  suggest.on_show = function(_, focused)
    result.called = true
    result.focused = focused
  end
  local ok, err = pcall(fn)
  suggest.on_show = prev
  assert.is_true(ok, err)
  return result
end

describe('when a command has reached mastery level (count >= 100)', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('never shows it again', function()
    local usage = logger.get_all()
    usage[';'] = { count = 100, sessions = {}, shown = 0, suppressed = false, pinned = false }

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

describe('when the suggestion cooldown is active', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does not show a second auto suggestion before the cooldown has passed', function()
    config.setup({ suggestion_cooldown = 3600 })
    with_float_spy(function()
      suggest.show(';')
    end)
    local shown = with_float_spy(function()
      suggest.show(',')
    end)
    assert.is_false(shown)
  end)

  it('allows multiple auto suggestions when cooldown is zero', function()
    config.setup({ suggestion_cooldown = 0 })
    local shown1 = with_float_spy(function()
      suggest.show(';')
    end)
    local shown2 = with_float_spy(function()
      suggest.show(',')
    end)
    assert.is_true(shown1)
    assert.is_true(shown2)
  end)
end)

describe('when manual is called while the auto suggestion cooldown is active', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('still shows a suggestion', function()
    config.setup({ suggestion_cooldown = 3600 })
    with_float_spy(function()
      suggest.show(';')
    end)
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    local shown = with_float_spy(function()
      suggest.manual()
    end)
    assert.is_true(shown)
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
    vim.fn.feedkeys(';', 'xt')
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
    local usage = logger.get_all()
    usage[';'] = { count = 100, sessions = {}, shown = 0, suppressed = false, pinned = false }
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
    local shown = with_float_spy(function()
      suggest.show(';')
    end)
    assert.is_false(shown)
  end)

  it('can be auto-suggested again once un-suppressed', function()
    logger.set_suppressed(';', true)
    logger.set_suppressed(';', false)
    local shown = with_float_spy(function()
      suggest.show(';')
    end)
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
    suggest.on_show = function()
      shown = true
    end
    suggest.queue('f_repeat', ';')
    vim.wait(500, function()
      return shown
    end, 10)
    suggest.on_show = nil
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
    local commands = require('tobira.commands')
    -- Only x is used → novice level → max_level = beginner
    -- x has multiple beginner-level downstreams (D, r, s, …); all intermediate/advanced excluded
    local usage = logger.get_all()
    usage['x'] = { count = 10, sessions = {}, shown = 0, suppressed = false }
    assert.equals('novice', level_mod.get())
    local shown_cmd = nil
    suggest.on_show = function(sug)
      shown_cmd = sug.cmd
    end
    local ok, err = pcall(suggest.manual)
    suggest.on_show = nil
    assert.is_true(ok, err)
    assert.is_not_nil(shown_cmd, 'expected a suggestion to be shown')
    assert.equals('beginner', commands.registry[shown_cmd].level)
  end)
end)

-- ── Ambient idle timer (setup_idle / teardown_idle / fire_ambient) ─────────

describe('when setup_idle is called with idle_suggestions disabled', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does not register the idle watcher', function()
    config.setup({ idle_suggestions = false })
    assert.has_no_error(function()
      suggest.setup_idle()
      suggest.teardown_idle()
    end)
  end)
end)

describe('when setup_idle is called multiple times', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)
  after_each(function()
    suggest.teardown_idle()
  end)

  it('registers only once without error', function()
    config.setup({ idle_suggestions = true, idle_delay = 60000 })
    assert.has_no_error(function()
      suggest.setup_idle()
      suggest.setup_idle()
    end)
  end)
end)

describe('when teardown_idle is called without prior setup', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('does nothing without error', function()
    assert.has_no_error(function()
      suggest.teardown_idle()
    end)
  end)
end)

describe('when teardown_idle is called after setup_idle', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('cleans up without error', function()
    config.setup({ idle_suggestions = true, idle_delay = 60000 })
    assert.has_no_error(function()
      suggest.setup_idle()
      suggest.teardown_idle()
    end)
  end)
end)

describe('when the idle timer fires in normal mode with a suggestion available', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)
  after_each(function()
    suggest.teardown_idle()
  end)

  it('shows the best suggestion', function()
    config.setup({ idle_suggestions = true, idle_delay = 10, suggestion_cooldown = 0 })
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    local shown = false
    suggest.on_show = function()
      shown = true
    end
    suggest.setup_idle()
    vim.fn.feedkeys('j', 'xt')
    vim.wait(500, function()
      return shown
    end, 10)
    suggest.on_show = nil
    assert.is_true(shown)
  end)
end)

describe('when the idle timer fires but the cooldown is still active', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)
  after_each(function()
    suggest.teardown_idle()
  end)

  it('does not show another suggestion', function()
    config.setup({ idle_suggestions = true, idle_delay = 10, suggestion_cooldown = 3600 })
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    -- First suggestion triggers the cooldown clock.
    with_float_spy(function()
      suggest.show(';')
    end)
    local shown = false
    suggest.on_show = function()
      shown = true
    end
    suggest.setup_idle()
    vim.fn.feedkeys('j', 'xt')
    vim.wait(300, function()
      return shown
    end, 10)
    suggest.on_show = nil
    assert.is_false(shown)
  end)
end)

describe('when the focused flag is passed to on_show', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)

  it('passes focused=false for automatic suggestions', function()
    config.setup({})
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    local result = with_focused_spy(function()
      suggest.show(';')
    end)
    assert.is_true(result.called)
    assert.is_false(result.focused)
  end)

  it('passes focused=true for manual :Tobira invocations', function()
    config.setup({})
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    local result = with_focused_spy(function()
      suggest.manual()
    end)
    assert.is_true(result.called)
    assert.is_true(result.focused)
  end)
end)

describe('when the idle timer fires with no suggestion available', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)
  after_each(function()
    suggest.teardown_idle()
  end)

  it('does not show anything', function()
    config.setup({ idle_suggestions = true, idle_delay = 10, suggestion_cooldown = 0 })
    local shown = false
    suggest.on_show = function()
      shown = true
    end
    suggest.setup_idle()
    vim.fn.feedkeys('j', 'xt')
    vim.wait(300, function()
      return shown
    end, 10)
    suggest.on_show = nil
    assert.is_false(shown)
  end)
end)

describe('when the idle timer fires while not in normal mode', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
  end)
  after_each(function()
    suggest.teardown_idle()
  end)

  it('does not show a suggestion', function()
    config.setup({ idle_suggestions = true, idle_delay = 10, suggestion_cooldown = 0 })
    local usage = logger.get_all()
    usage['f'] = { count = 5, shown = 0, sessions = {}, suppressed = false }
    -- Patch vim.fn.mode so fire_ambient sees a non-normal mode when the timer fires.
    local orig_mode = vim.fn.mode
    local ok, err = pcall(function()
      vim.fn.mode = function()
        return 'i'
      end
      local shown = false
      suggest.on_show = function()
        shown = true
      end
      suggest.setup_idle()
      vim.fn.feedkeys('j', 'xt')
      vim.wait(300, function()
        return shown
      end, 10)
      suggest.on_show = nil
      assert.is_false(shown)
    end)
    vim.fn.mode = orig_mode
    assert.is_true(ok, err)
  end)
end)

-- ── Multi-char adoption detection (#25) ────────────────────────────────────

local ESC = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

local function with_content(lines)
  vim.cmd('enew')
  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    lines or { 'hello world', 'second line', 'third line', 'fourth line', 'fifth line' }
  )
  vim.cmd('normal! gg0')
end

describe('when a multi-char command is suggested and then typed (literal sequence)', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
    with_content()
  end)
  after_each(function()
    vim.fn.feedkeys(ESC, 'xt')
  end)

  it('marks cw as adopted when the user types cw', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('cw')
    end)
    vim.fn.feedkeys('cw', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('cw')))
  end)

  it('marks ddp as adopted when the user types ddp', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('ddp')
    end)
    vim.fn.feedkeys('ddp', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('ddp')))
  end)

  it('marks gn as adopted when the user types gn', function()
    local graph = require('tobira.core.graph')
    vim.fn.setreg('/', 'hello')
    with_float_spy(function()
      suggest.show('gn')
    end)
    vim.fn.feedkeys('gn', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('gn')))
  end)
end)

describe('when a special-key command is suggested and then typed', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
    with_content()
  end)

  it('marks <C-r> as adopted when the user presses Ctrl-R', function()
    local graph = require('tobira.core.graph')
    local cr = vim.api.nvim_replace_termcodes('<C-r>', true, false, true)
    with_float_spy(function()
      suggest.show('<C-r>')
    end)
    vim.fn.feedkeys(cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('<C-r>')))
  end)

  it('marks <C-d> as adopted when the user presses Ctrl-D', function()
    local graph = require('tobira.core.graph')
    local cd = vim.api.nvim_replace_termcodes('<C-d>', true, false, true)
    with_float_spy(function()
      suggest.show('<C-d>')
    end)
    vim.fn.feedkeys(cd, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('<C-d>')))
  end)
end)

describe('when a count-prefix command ({n}) is suggested', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
    with_content()
  end)

  it('marks {n}j as adopted when the user types 3j', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('{n}j')
    end)
    vim.fn.feedkeys('3j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('{n}j')))
  end)

  it('marks {n}j as adopted when the user types 10j', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('{n}j')
    end)
    vim.fn.feedkeys('10j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('{n}j')))
  end)

  it('marks {n}j as adopted when the user types 1j', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('{n}j')
    end)
    vim.fn.feedkeys('1j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('{n}j')))
  end)

  it('marks {n}x as adopted when the user types 4x', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('{n}x')
    end)
    vim.fn.feedkeys('4x', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('{n}x')))
  end)

  it('does NOT mark {n}j adopted when the user types just j', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('{n}j')
    end)
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get('{n}j')))
  end)

  it('does NOT mark {n}j adopted when the user types 0j (0 is a motion, not a count)', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('{n}j')
    end)
    vim.fn.feedkeys('0j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get('{n}j')))
  end)
end)

describe('adoption detection — nasty / adversarial cases', function()
  before_each(function()
    logger.reset()
    config.reset()
    suggest.reset_session()
    with_content()
  end)
  after_each(function()
    vim.fn.feedkeys(ESC, 'xt')
  end)

  it('does NOT adopt cw when the user types cb (wrong suffix)', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('cw')
    end)
    vim.fn.feedkeys('cb', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get('cw')))
  end)

  it('does NOT adopt gn when the user types gb', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('gn')
    end)
    vim.fn.feedkeys('gb', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get('gn')))
  end)

  it('does NOT adopt cw when the user types only c and stops', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('cw')
    end)
    -- send c then immediately escape (operator cancelled — never completes to cw)
    vim.fn.feedkeys('c', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get('cw')))
  end)

  it('still adopts cw after many intervening keystrokes', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('cw')
    end)
    -- type lots of other keys first, then finally cw
    vim.fn.feedkeys('jjjjkk', 'xt')
    vim.fn.feedkeys('cw', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('cw')))
  end)

  it('does NOT fire the adoption watcher after reset_session', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('cw')
    end)
    -- reset clears all watchers
    suggest.reset_session()
    vim.fn.feedkeys('cw', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get('cw')))
  end)

  it('handles 40 rapid keystrokes without error after suggestion', function()
    with_float_spy(function()
      suggest.show('cw')
    end)
    assert.has_no_error(function()
      vim.fn.feedkeys('jkjkjkjkjkjkjkjkjkjkjkjkjkjkjkjkjkjkjkjk', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end)
  end)

  it('adopting one command does not prevent adoption of another', function()
    local graph = require('tobira.core.graph')
    -- two back-to-back shows would be blocked by cooldown; disable it
    config.setup({ suggestion_cooldown = 0 })
    with_float_spy(function()
      suggest.show(';')
    end)
    with_float_spy(function()
      suggest.show('cw')
    end)
    -- adopt ; first
    vim.fn.feedkeys(';', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get(';')))
    -- then adopt cw
    vim.fn.feedkeys('cw', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(graph.is_adopted(logger.get('cw')))
  end)

  it('does not advance the adoption buffer for keys with typed="" (internal keys)', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show(';')
    end)
    -- feedkeys without 't' flag → typed='' → filtered before the buffer is updated
    vim.fn.feedkeys(';', 'x')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(graph.is_adopted(logger.get(';')))
  end)

  it('does not double-adopt: watcher is removed after first match', function()
    local graph = require('tobira.core.graph')
    with_float_spy(function()
      suggest.show('cw')
    end)
    vim.fn.feedkeys('cw', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    local sessions_after_first = vim.deepcopy(logger.get('cw').sessions)
    -- type cw again — watcher is already gone, sessions should not grow
    vim.fn.feedkeys('cw', 'xt')
    vim.fn.feedkeys(ESC, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(#sessions_after_first, #logger.get('cw').sessions)
  end)
end)
