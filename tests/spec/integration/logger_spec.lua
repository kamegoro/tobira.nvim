local logger = require('tobira.core.logger')

-- Test-local disk cleanup. Production `logger.reset()` deliberately does no
-- I/O (per CLAUDE.md); specs that also need a clean usage.json on disk call
-- this helper directly.
local _data_file = vim.fn.stdpath('data') .. '/tobira/usage.json'
local function wipe_disk()
  pcall(os.remove, _data_file)
end

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

-- ── mark_celebrated / is_celebrated ─────────────────────────────────────────

describe('when a command has never been celebrated', function()
  before_each(function()
    logger.reset()
  end)

  it('reports it as not celebrated', function()
    assert.is_false(logger.is_celebrated(';'))
  end)

  it('reports an unknown command as not celebrated', function()
    assert.is_false(logger.is_celebrated('never_seen'))
  end)
end)

describe('when a command is marked celebrated', function()
  before_each(function()
    logger.reset()
  end)

  it('reports it as celebrated afterwards', function()
    logger.mark_celebrated(';')
    assert.is_true(logger.is_celebrated(';'))
  end)

  it('creates a new record even if the command was never used', function()
    logger.mark_celebrated('brand_new_cmd')
    assert.is_true(logger.is_celebrated('brand_new_cmd'))
    assert.equals(0, logger.get('brand_new_cmd').count)
  end)

  it('does not affect other commands', function()
    logger.mark_celebrated(';')
    assert.is_false(logger.is_celebrated(','))
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
    vim.fn.feedkeys('j', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('j', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
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
    wipe_disk()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world test' })
  end)

  it('close_session appends the current-session count to usage.sessions', function()
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    assert.equals(3, logger.get('e').sessions[1])
  end)

  it('after close_session the next session starts fresh', function()
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    local sessions = logger.get('e').sessions
    assert.equals(2, #sessions)
    assert.equals(3, sessions[1])
    assert.equals(1, sessions[2])
  end)

  it('sessions array is capped at 10 entries', function()
    for _ = 1, 12 do
      vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
      logger.close_session()
    end
    assert.equals(10, #logger.get('e').sessions)
  end)
end)

-- ── zero-padding for untouched commands (#62 prerequisite) ─────────────────────
-- close_session() previously only appended a sessions[] entry for commands
-- actually used that session, so "sessions[len] == 0" (an idle real session)
-- could never occur from real usage — is_forgotten()'s "last 2 sessions are 0"
-- check was effectively dead on production data. This backfills a 0 for every
-- already-known command that went untouched, so decay-based scoring has a
-- real "time passed with no use" signal to work with.

describe('when a known command goes untouched for a session', function()
  before_each(function()
    wipe_disk()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world test' })
  end)

  it('appends a 0 to that command sessions on close_session', function()
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session() -- 'e' now known: sessions = {1}

    -- Next session: only 'w' is used, 'e' is untouched.
    vim.fn.feedkeys('w', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()

    assert.same({ 1, 0 }, logger.get('e').sessions)
    assert.same({ 1 }, logger.get('w').sessions)
  end)

  it('does not zero-pad a command that has never been used at all', function()
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    -- 'w' was never used in any session — should stay entirely absent, not
    -- gain a spurious sessions = {0} entry.
    assert.same({}, logger.get('w').sessions)
    assert.equals(0, logger.get('w').count)
  end)

  it('zero-padding also respects the 10-entry cap', function()
    vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    for _ = 1, 12 do
      vim.fn.feedkeys('w', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
      logger.close_session()
    end
    assert.equals(10, #logger.get('e').sessions)
  end)
end)

describe('when a command is flushed via mark_adopted mid-session', function()
  before_each(function()
    wipe_disk()
    logger.reset()
    logger.setup()
  end)

  it('is not double-appended when close_session runs later in the same session', function()
    vim.fn.feedkeys('eee', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    logger.mark_adopted('e') -- flushes a boosted count into sessions immediately
    assert.equals(1, #logger.get('e').sessions)

    logger.close_session()
    -- Must still be exactly 1 entry — close_session must not also append a
    -- second (spurious) entry for 'e' just because it saw no fresh session_counts.
    assert.equals(1, #logger.get('e').sessions)
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

  it('defaults celebrated to false for entries written before the field existed', function()
    local usage = logger.get_all()
    usage['e'] = { count = 3, shown = 0, sessions = { 2, 3 }, suppressed = false, pinned = false }
    logger.save()
    logger.load_from_disk()
    assert.is_false(logger.get('e').celebrated)
  end)

  it('preserves celebrated=true across a save/load round-trip', function()
    logger.mark_celebrated('cw')
    logger.load_from_disk()
    assert.is_true(logger.is_celebrated('cw'))
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
    vim.fn.feedkeys('i', 'xt')
    vim.fn.feedkeys('dw', 'xt')
    vim.fn.feedkeys(esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)

  it('routes to the insert-mode handler (not the normal seq) when current_mode is i', function()
    -- In headless mode vim.fn.mode() always reports 'n', so stub it to 'i'
    -- (same technique as the operator-pending test below). Since #58, mode
    -- 'i' is routed to handle_insert_key rather than the generic
    -- non-normal-mode reset branch — 'j' is an ordinary insert-mode key, so
    -- feed_insert() just breaks any streak and returns nil.
    local real_mode = vim.fn.mode
    vim.fn.mode = function() return 'i' end
    vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
    vim.fn.mode = real_mode
    local fired = false
    logger.on_pattern = function() fired = true end
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
    assert.equals(0, logger.get('j').count)
  end)

  it('resets both seq and insert_seq when current_mode is neither n nor i', function()
    -- Visual mode ('v') exercises the generic fallback branch — distinct
    -- from both the normal path and the #58 insert-mode path.
    local real_mode = vim.fn.mode
    vim.fn.mode = function() return 'v' end
    vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
    vim.fn.mode = real_mode
    local fired = false
    logger.on_pattern = function() fired = true end
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
    assert.equals(0, logger.get('j').count)
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
    vim.fn.feedkeys('d', 'xt')
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
    vim.fn.feedkeys('wi', 'xt')
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
    vim.fn.feedkeys('ddp', 'xt')
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
    vim.fn.feedkeys('dwi', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)

    assert.equals('dw_then_insert', fired.pattern)
    assert.equals('cw', fired.cmd)
  end)
end)

describe('insert-mode inefficiency detection (#58)', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  local bs = vim.api.nvim_replace_termcodes('<BS>', true, false, true)
  local left = vim.api.nvim_replace_termcodes('<Left>', true, false, true)
  local right = vim.api.nvim_replace_termcodes('<Right>', true, false, true)
  local ctrl_w = vim.api.nvim_replace_termcodes('<C-w>', true, false, true)

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

  it('increments the usage count for <C-w> only while actually in insert mode', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar' })
    -- Fed as a single feedkeys call (not separate ones) so the mode cache's
    -- ModeChanged autocmd has definitely fired by the time <C-w> is processed.
    vim.fn.feedkeys('A' .. ctrl_w .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('<C-w>').count > 0)
  end)

  it('does not count the normal-mode window-prefix <C-w> as the insert-mode command', function()
    vim.cmd('enew')
    -- <C-w><C-w> in normal mode is "cycle to next window" — a no-op here
    -- since there is only one window, but it must not increment '<C-w>'.
    vim.fn.feedkeys(ctrl_w .. ctrl_w, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('<C-w>').count)
  end)

  it('fires insert_bs_repeat suggesting <C-w> after 5 backspaces in a row', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a very long line of text here' })
    vim.fn.feedkeys('A' .. bs:rep(5) .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals('insert_bs_repeat', fired.pattern)
    assert.equals('<C-w>', fired.cmd)
  end)

  it('fires insert_left_repeat suggesting b after 5 <Left> presses in a row', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a very long line of text here' })
    vim.fn.feedkeys('A' .. left:rep(5) .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals('insert_left_repeat', fired.pattern)
    assert.equals('b', fired.cmd)
  end)

  it('fires insert_right_repeat suggesting w after 5 <Right> presses in a row', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a very long line of text here' })
    -- 'I' (insert at start of line) so there is room to move right
    vim.fn.feedkeys('I' .. right:rep(5) .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals('insert_right_repeat', fired.pattern)
    assert.equals('w', fired.cmd)
  end)

  it('fires insert_bounce suggesting A after two empty enter/escape round-trips', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello' })
    vim.fn.feedkeys('i' .. esc, 'xt') -- 1st empty bounce
    vim.fn.feedkeys('i' .. esc, 'xt') -- 2nd empty bounce
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals('insert_bounce', fired.pattern)
    assert.equals('A', fired.cmd)
  end)

  it('does not fire insert_bounce when the user actually typed something', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello' })
    vim.fn.feedkeys('ix' .. esc, 'xt') -- typed a real character before leaving
    vim.fn.feedkeys('i' .. esc, 'xt') -- this one alone is not 2 in a row
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)
end)

-- (stats rendering has moved to tests/spec/unit/ui_stats_spec.lua)

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

  it('leaves no .tmp file after writing (atomic write)', function()
    logger.mark_shown('f')
    local tmp = vim.fn.stdpath('data') .. '/tobira/usage.json.tmp'
    local f = io.open(tmp, 'r')
    assert.is_nil(f, 'expected no lingering .tmp file after save()')
    if f then f:close() end
  end)

  it('does not crash when the data directory is not writable', function()
    local real_open = io.open
    io.open = function(path, mode)
      if mode == 'w' then
        return nil
      end
      return real_open(path, mode)
    end
    local ok, err = pcall(logger.save)
    io.open = real_open
    assert.is_true(ok, tostring(err))
  end)
end)

-- ── multi-instance merge ──────────────────────────────────────────────────────

describe('when a concurrent Neovim instance has written counts to disk', function()
  before_each(function()
    wipe_disk()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world test' })
  end)

  it('adds this session\'s delta on top of the concurrent count instead of overwriting it', function()
    -- Press 'e' 3 times in this session (delta = 3).
    for _ = 1, 3 do
      vim.fn.feedkeys('e', 'xt'); vim.api.nvim_feedkeys('', 'x', false)
    end

    -- Simulate a concurrent instance that wrote count=7 while this session ran.
    local data_dir = vim.fn.stdpath('data') .. '/tobira'
    vim.fn.mkdir(data_dir, 'p')
    local f = io.open(data_dir .. '/usage.json', 'w')
    f:write(vim.json.encode({ e = { count = 7, sessions = {}, shown = 0, suppressed = false, pinned = false } }))
    f:close()

    -- close_session must produce count = 7 (disk) + 3 (delta) = 10, not 3.
    logger.close_session()
    logger.load_from_disk()
    assert.equals(10, logger.get('e').count)
  end)

  it('preserves commands recorded only by the concurrent instance', function()
    -- This session never touches 'w'. Concurrent instance recorded count=5 for 'w'.
    local data_dir = vim.fn.stdpath('data') .. '/tobira'
    vim.fn.mkdir(data_dir, 'p')
    local f = io.open(data_dir .. '/usage.json', 'w')
    f:write(vim.json.encode({ w = { count = 5, sessions = {}, shown = 0, suppressed = false, pinned = false } }))
    f:close()

    logger.close_session()
    logger.load_from_disk()
    assert.equals(5, logger.get('w').count)
  end)
end)

-- ── load: first-run (no file) ─────────────────────────────────────────────────

describe('when no usage file exists yet', function()
  it('loads without error and returns empty usage', function()
    logger.reset()
    wipe_disk()
    assert.has_no_error(function()
      logger.load_from_disk()
    end)
    assert.same({}, logger.get_all())
  end)
end)

-- ── data_dir / data_file accessors (for :checkhealth, #42) ──────────────────

describe('data_dir and data_file', function()
  it('data_file is data_dir with /usage.json appended', function()
    assert.equals(logger.data_dir() .. '/usage.json', logger.data_file())
  end)

  it('data_dir ends with /tobira', function()
    assert.is_not_nil(logger.data_dir():match('/tobira$'))
  end)

  it('matches the path wipe_disk() operates on', function()
    assert.equals(_data_file, logger.data_file())
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
    vim.fn.feedkeys('dw', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('dw').count > 0)
  end)

  it('increments the usage count for dd', function()
    vim.fn.feedkeys('dd', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('dd').count > 0)
  end)

  it('increments the usage count for >> (indent)', function()
    vim.fn.feedkeys('>>', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('>>').count > 0)
  end)

  it('increments the usage count for gg (go to top)', function()
    vim.fn.feedkeys('gg', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('gg').count > 0)
  end)

  it('increments the usage count for <C-d> (half page down)', function()
    local ctrl_d = vim.api.nvim_replace_termcodes('<C-d>', true, true, true)
    vim.fn.feedkeys(ctrl_d, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('<C-d>').count > 0)
  end)

  it('increments the usage count for <C-u> (half page up)', function()
    local ctrl_u = vim.api.nvim_replace_termcodes('<C-u>', true, true, true)
    vim.fn.feedkeys(ctrl_u, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('<C-u>').count > 0)
  end)

  it('tracks gj as a compound command', function()
    vim.fn.feedkeys('gj', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('gj').count > 0)
  end)

  -- #120: g; / gp / gu were added to patterns.lua's pending_g dispatch table
  -- so the change-list / paste / case-operator teaching chains become
  -- trackable. pcall absorbs real Vim errors (e.g. g; with an empty change
  -- list, gp with an empty register) — on_key fires before the command
  -- executes so the count is already set regardless of the outcome.
  it('tracks g; as a compound command', function()
    pcall(vim.fn.feedkeys, 'g;', 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    assert.is_true(logger.get('g;').count > 0)
  end)

  it('tracks gp as a compound command', function()
    pcall(vim.fn.feedkeys, 'gp', 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    assert.is_true(logger.get('gp').count > 0)
  end)

  it('tracks gu as a compound command', function()
    -- 'guu' (doubled operator = linewise) is a complete, harmless real Vim
    -- command — unlike a bare 'gu' it does not leave an operator pending,
    -- so it can't swallow the next test's first keystroke as its motion.
    pcall(vim.fn.feedkeys, 'guu', 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    assert.is_true(logger.get('gu').count > 0)
  end)

  -- #120: <C-w>X window-command compounds — patterns.lua's new pending_ctrl_w
  -- dispatch table. Some of these (s/v split, q close) have real window
  -- side effects; pcall absorbs any resulting error (E444 etc. — same
  -- rationale as the ctrl_keys loop below) and the trailing `:only` collapses
  -- back to a single window so a split/close in one iteration can't affect
  -- the next. on_key fires before the command executes so the count is
  -- already set regardless of the command's outcome.
  local ctrl_w = vim.api.nvim_replace_termcodes('<C-w>', true, true, true)
  local ctrl_w_targets = { 's', 'v', 'w', 'h', 'j', 'k', 'l', 'q', '=' }
  for _, target in ipairs(ctrl_w_targets) do
    local cmd = '<C-w>' .. target
    it('tracks ' .. cmd .. ' as a compound command', function()
      pcall(vim.fn.feedkeys, ctrl_w .. target, 'xt')
      pcall(vim.api.nvim_feedkeys, '', 'x', false)
      pcall(vim.cmd, 'only')
      assert.is_true(logger.get(cmd).count > 0)
    end)
  end

  it('does not track <C-w><C-w> (double raw byte) as any <C-w>X compound', function()
    -- <C-w><C-w> is a valid Vim window command (cycle window) using two raw
    -- Ctrl-W bytes, not <C-w> + literal 'w' — must keep passing alongside the
    -- pre-existing "does not count the normal-mode window-prefix <C-w> as the
    -- insert-mode command" test above; this is the normal-mode-compound side
    -- of that same guarantee.
    pcall(vim.fn.feedkeys, ctrl_w .. ctrl_w, 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    pcall(vim.cmd, 'only')
    assert.equals(0, logger.get('<C-w>w').count)
  end)

  -- All Ctrl keys changed to track=true are verified here so a stray
  -- track=false revert is caught immediately by CI.
  -- pcall absorbs Neovim errors (e.g. E433 for <C-]> with no tags file):
  -- on_key fires before the command executes so the count is already set.
  local ctrl_keys = {
    '<C-r>', '<C-o>', '<C-i>', '<C-f>', '<C-b>',
    '<C-a>', '<C-x>', '<C-v>', '<C-e>', '<C-y>',
    '<C-^>', '<C-]>',
  }
  for _, notation in ipairs(ctrl_keys) do
    it('increments the usage count for ' .. notation, function()
      local raw = vim.api.nvim_replace_termcodes(notation, true, true, true)
      pcall(vim.fn.feedkeys, raw, 'xt')
      pcall(vim.api.nvim_feedkeys, '', 'x', false)
      assert.is_true(logger.get(notation).count > 0)
    end)
  end
end)

-- ── single-char key tracking ─────────────────────────────────────────────────
-- Smoke test: every track=true single-char key in commands.lua must increment
-- its usage count when pressed. A stray track=false revert is caught here.

describe('when single-char track=true keys are pressed', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew')
    -- Rich buffer: multi-line, multi-word so motions like w/b/e/J/H/M/L work.
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'hello world foo bar baz',
      'second line here now',
      'third line content ok',
      'fourth line text yes',
      'fifth line end done',
    })
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
  end)

  -- pcall absorbs Neovim side-effects (mode changes, missing prior context for
  -- ; / , , etc.). on_key fires before the command executes so the count is set.
  local single_keys = {
    ';', ',', '.', '*', '#', '~',
    'A', 'b', 'C', 'D', 'e', 'F',
    'H', 'I', 'J', 'L', 'M', 'N',
    'O', 'P', 'r', 's', 't', 'V',
    'w', 'X', 'Y',
  }
  for _, key in ipairs(single_keys) do
    it('increments the usage count for ' .. key, function()
      pcall(vim.fn.feedkeys, key, 'xt')
      pcall(vim.api.nvim_feedkeys, '', 'x', false)
      assert.is_true(logger.get(key).count > 0)
    end)
  end
end)

describe('when single-char commands that were missing track=true are pressed', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'hello world foo bar baz',
      '',
      'second paragraph here now.',
      'third line content ok.',
      '',
      'fourth paragraph text yes.',
      'fifth line end done.',
    })
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
  end)

  -- These were track=false by mistake; each is a single real keystroke.
  -- pcall absorbs side-effects (motion fails, replace mode entered, etc.).
  local missing_keys = {
    '}', '{', '(', ')', '%', '^', '$', '_', '|',
    'B', 'E', 'W', 'T', 'U', 'K', 'R',
  }
  for _, key in ipairs(missing_keys) do
    it('increments the usage count for ' .. key, function()
      pcall(vim.fn.feedkeys, key, 'xt')
      pcall(vim.api.nvim_feedkeys, '', 'x', false)
      assert.is_true(logger.get(key).count > 0)
    end)
  end

  it('increments the usage count for q (macro recording key)', function()
    -- q<Esc>: on_key fires for q before the register-waiting state begins;
    -- Esc cancels so RecordingEnter never fires and no state leaks to later tests.
    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    pcall(vim.fn.feedkeys, 'q' .. esc, 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    assert.is_true(logger.get('q').count > 0)
  end)
end)

describe('when on_key fires with typed="" (internally-generated key)', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello', 'world' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)

  it('does not count the key (typed filter blocks it)', function()
    -- feedkeys without 't' flag → typed='' → filtered by `if typed == '' then return end`
    vim.fn.feedkeys('j', 'x')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('j').count)
  end)
end)

describe('when the user records a macro', function()
  before_each(function()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello', 'world', 'foo' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)

  after_each(function()
    logger.on_pattern = nil
  end)

  it('does not count keystrokes typed while recording a macro', function()
    -- qa starts recording to register a, j is the macro body, q stops
    vim.fn.feedkeys('qa', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('q', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('j').count)
  end)
end)
