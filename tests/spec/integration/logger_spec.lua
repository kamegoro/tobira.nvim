local logger = require('tobira.core.logger')

-- ── default state ─────────────────────────────────────────────────────────────

describe('before any usage is recorded', function()
  before_each(function()
    logger.reset()
  end)

  it('reports zero counts for any command', function()
    local data = logger.get('unknown_cmd')
    assert.equals(0, data.count)
    assert.equals(0, data.shown)
    assert.same({}, data.sessions)
    assert.is_false(data.suppressed)
  end)

  it('returns an empty usage table', function()
    assert.same({}, logger.get_all())
  end)
end)

-- ── mark_shown ────────────────────────────────────────────────────────────────

describe('when a suggestion has been shown to the user', function()
  before_each(function()
    logger.reset()
  end)

  it('tracks that it was shown once', function()
    logger.mark_shown(';')
    assert.equals(1, logger.get(';').shown)
  end)

  it('tracks each additional showing', function()
    logger.mark_shown(';')
    logger.mark_shown(';')
    assert.equals(2, logger.get(';').shown)
  end)

  it('creates a new record even if the command was never used', function()
    logger.mark_shown('brand_new_cmd')
    local data = logger.get('brand_new_cmd')
    assert.equals(1, data.shown)
    assert.equals(0, data.count)
    assert.same({}, data.sessions)
  end)
end)

-- ── mark_adopted ──────────────────────────────────────────────────────────────

describe('when the user adopts a suggested command', function()
  before_each(function()
    logger.reset()
  end)

  it('immediately makes it detectable as adopted via sessions', function()
    local graph = require('tobira.core.graph')
    logger.mark_shown(';')
    logger.mark_adopted(';')
    -- mark_adopted flushes a strong session count so is_adopted is true immediately
    assert.is_true(graph.is_adopted(logger.get(';')))
  end)
end)

describe('when mark_adopted is called for an unknown command', function()
  before_each(function()
    logger.reset()
  end)

  it('does not error', function()
    assert.has_no_error(function()
      logger.mark_adopted('never_seen')
    end)
  end)
end)

describe('when mark_adopted is called after 10 sessions have already been stored', function()
  before_each(function()
    logger.reset()
  end)

  it('keeps the sessions array capped at 10', function()
    -- Build up 10 sessions directly via mark_shown (creates the entry) + get_all manipulation
    local all = logger.get_all()
    all['cw'] = { count = 5, sessions = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, shown = 1, suppressed = false }
    logger.mark_adopted('cw')
    assert.equals(10, #logger.get('cw').sessions)
  end)
end)

-- ── get_session_counts ────────────────────────────────────────────────────────

describe('get_session_counts', function()
  before_each(function()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
  end)

  it('returns the in-session keystroke counts before close_session is called', function()
    vim.fn.feedkeys('j', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('j', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    local counts = logger.get_session_counts()
    assert.equals(2, counts['j'])
  end)
end)

-- ── set_suppressed ───────────────────────────────────────────────────────────

describe('when a command is explicitly suppressed', function()
  before_each(function()
    logger.reset()
  end)

  it('marks it as suppressed', function()
    logger.set_suppressed(';', true)
    assert.is_true(logger.get(';').suppressed)
  end)

  it('can be un-suppressed', function()
    logger.set_suppressed(';', true)
    logger.set_suppressed(';', false)
    assert.is_false(logger.get(';').suppressed)
  end)
end)

-- ── set_pinned ───────────────────────────────────────────────────────────────

describe('when a command is pinned to the guide', function()
  before_each(function()
    logger.reset()
  end)

  it('marks it as pinned', function()
    logger.set_pinned(';', true)
    assert.is_true(logger.get(';').pinned)
  end)

  it('can be un-pinned', function()
    logger.set_pinned(';', true)
    logger.set_pinned(';', false)
    assert.is_false(logger.get(';').pinned)
  end)

  it('is not pinned by default', function()
    assert.is_false(logger.get(';').pinned)
  end)
end)

-- ── session tracking ──────────────────────────────────────────────────────────

describe('session tracking', function()
  before_each(function()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world test' })
  end)

  it('close_session appends the current-session count to usage.sessions', function()
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    assert.equals(3, logger.get('e').sessions[1])
  end)

  it('after close_session the next session starts fresh', function()
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    local sessions = logger.get('e').sessions
    assert.equals(2, #sessions)
    assert.equals(3, sessions[1])
    assert.equals(1, sessions[2])
  end)

  it('sessions array is capped at 10 entries', function()
    for _ = 1, 12 do
      vim.fn.feedkeys('e', 'x'); vim.api.nvim_feedkeys('', 'x', false)
      logger.close_session()
    end
    assert.equals(10, #logger.get('e').sessions)
  end)
end)

-- ── old-format migration ──────────────────────────────────────────────────────

describe('old-format migration', function()
  before_each(function()
    logger.reset()
  end)

  it('converts adopted=true entries to sessions=[10] on load', function()
    -- Write old-format data to disk
    local usage = logger.get_all()
    usage['cw'] = { count = 5, shown = 2, adopted = true }
    logger.save()
    -- Re-read: migrate() runs inside load()
    logger.load_from_disk()
    local data = logger.get('cw')
    assert.same({ 10 }, data.sessions)
    assert.is_nil(data.adopted)
  end)

  it('leaves entries without adopted field unchanged except for defaults', function()
    local usage = logger.get_all()
    usage['e'] = { count = 3, shown = 0, sessions = { 2, 3 } }
    logger.save()
    logger.load_from_disk()
    local data = logger.get('e')
    assert.same({ 2, 3 }, data.sessions)
    assert.is_false(data.suppressed)
  end)
end)

-- ── reset ─────────────────────────────────────────────────────────────────────

describe('after a reset', function()
  it('all usage data is cleared', function()
    logger.mark_shown('f')
    logger.reset()
    assert.same({}, logger.get_all())
  end)
end)

-- ── setup idempotence ─────────────────────────────────────────────────────────

describe('when setup is called more than once', function()
  it('does not error or register duplicate handlers', function()
    assert.has_no_error(function()
      logger.setup()
      logger.setup()
    end)
  end)
end)
-- ── reset side-effects ──────────────────────────────────────────────────────

describe('when reset is called', function()
  it('does not trigger a notification', function()
    local notified = false
    local orig = vim.notify
    vim.notify = function()
      notified = true
    end
    local ok, err = pcall(logger.reset)
    vim.notify = orig
    assert.is_true(ok, err)
    assert.is_false(notified)
  end)
end)

-- ── guide_seen ───────────────────────────────────────────────────────────────

describe('when the guide is marked as seen', function()
  it('reports it as seen immediately after', function()
    logger.mark_guide_seen()
    assert.is_true(logger.is_guide_seen())
  end)
end)

-- ── mode isolation ───────────────────────────────────────────────────────────

describe('when the user types while in insert mode', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

  before_each(function()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      vim.cmd('stopinsert')
    end
  end)

  it('does not fire a pattern callback for keys typed in insert mode', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    -- 'i' enters insert mode; 'd', 'w' typed inside insert are plain text, not operators.
    vim.fn.feedkeys('i', 'x')
    vim.fn.feedkeys('dw', 'x')
    vim.fn.feedkeys(esc, 'x')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)
end)

describe('when ModeChanged fires to operator-pending before the motion arrives', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      vim.cmd('stopinsert')
    end
  end)

  it('still detects dw_then_insert despite the mode being no between d and w', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    logger.setup()

    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })

    -- Simulate real interactive usage: ModeChanged (n→no) fires between
    -- keystrokes, but feedkeys batches events so we inject it manually.
    -- 1. 'd' sets seq.pending_op.
    vim.fn.feedkeys('d', 'x')
    -- 2. Force current_mode to 'no' via a synthetic ModeChanged.
    --    vim.fn.mode() is stubbed to 'no' for just this call so the
    --    ModeChanged callback (which calls vim.fn.mode()) writes 'no'
    --    into current_mode exactly as it would in real interactive usage.
    --    Old guard  (`~= 'n'`)            resets seq on 'w' → no pattern.
    --    Fixed guard (`:sub(1,1) ~= 'n'`) 'no' passes     → pattern fires.
    local real_mode = vim.fn.mode
    vim.fn.mode = function() return 'no' end
    vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
    vim.fn.mode = real_mode
    -- 3. 'w' arrives while current_mode = 'no'.
    vim.fn.feedkeys('wi', 'x')
    vim.api.nvim_feedkeys('', 'x', false)

    assert.equals('dw_then_insert', fired.pattern)
    assert.equals('cw', fired.cmd)
  end)
end)

-- ── pattern notification ─────────────────────────────────────────────────────

describe('when a tracked inefficiency is detected', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
  end)

  after_each(function()
    logger.on_pattern = nil
  end)

  it('notifies the wired callback with the detected pattern', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    logger.setup()

    -- Deleting a line then pasting it is the dd-then-p line-move inefficiency.
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb' })
    vim.fn.feedkeys('ddp', 'x')
    vim.api.nvim_feedkeys('', 'x', false)

    assert.equals('dd_then_p', fired.pattern)
    assert.equals('ddp', fired.cmd)
  end)
end)

describe('when the user deletes a word then enters insert mode', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      vim.cmd('stopinsert')
    end
  end)

  it('notifies the callback to suggest cw', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    logger.setup()

    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
    -- on_key sees 'i' while still in normal mode, so patterns.feed detects
    -- the dw-then-insert sequence before the mode actually changes.
    vim.fn.feedkeys('dwi', 'x')
    vim.api.nvim_feedkeys('', 'x', false)

    assert.equals('dw_then_insert', fired.pattern)
    assert.equals('cw', fired.cmd)
  end)
end)

-- ── stats ────────────────────────────────────────────────────────────────────

describe('when stats are displayed', function()
  before_each(function()
    logger.reset()
  end)

  it('notifies the user with a summary of recorded usage', function()
    local usage = logger.get_all()
    usage['dd'] = { count = 7, shown = 0, sessions = {}, suppressed = false }
    usage['cw'] = { count = 3, shown = 1, sessions = { 8 }, suppressed = false }

    local message = nil
    local orig = vim.notify
    vim.notify = function(msg, _)
      message = msg
    end
    local ok, err = pcall(logger.stats)
    vim.notify = orig

    assert.is_true(ok, err)
    assert.is_not_nil(message)
    assert.is_not_nil(message:find('dd'))
  end)
end)

-- ── save ─────────────────────────────────────────────────────────────────────

describe('when save is called explicitly', function()
  before_each(function()
    logger.reset()
  end)

  it('persists without error', function()
    logger.mark_shown('f')
    assert.has_no_error(function()
      logger.save()
    end)
  end)
end)

-- ── load: first-run (no file) ─────────────────────────────────────────────────

describe('when no usage file exists yet', function()
  it('loads without error and returns empty usage', function()
    logger.reset()
    assert.has_no_error(function()
      logger.load_from_disk()
    end)
    assert.same({}, logger.get_all())
  end)
end)

-- ── load: corrupt JSON ────────────────────────────────────────────────────────

describe('when the usage file contains invalid JSON', function()
  it('loads without error and returns empty usage', function()
    logger.reset()
    local data_dir = vim.fn.stdpath('data') .. '/tobira'
    vim.fn.mkdir(data_dir, 'p')
    local f = io.open(data_dir .. '/usage.json', 'w')
    f:write('not valid { json ][')
    f:close()
    assert.has_no_error(function()
      logger.load_from_disk()
    end)
    assert.same({}, logger.get_all())
  end)
end)

-- ── compound operator tracking ────────────────────────────────────────────────

describe('when a compound operator completes', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
  end)

  after_each(function()
    logger.on_pattern = nil
  end)

  it('increments the usage count for dw', function()
    vim.fn.feedkeys('dw', 'x')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('dw').count > 0)
  end)

  it('increments the usage count for dd', function()
    vim.fn.feedkeys('dd', 'x')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('dd').count > 0)
  end)
end)
