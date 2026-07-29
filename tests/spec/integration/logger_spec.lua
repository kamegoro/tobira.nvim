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
    wipe_disk()
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
    wipe_disk()
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
    wipe_disk()
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
    wipe_disk()
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
    wipe_disk()
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
    wipe_disk()
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
    wipe_disk()
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

describe('when checking in-session keystroke counts before the session closes', function()
  before_each(function()
    wipe_disk()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
  end)

  it('returns the in-session keystroke counts before close_session is called', function()
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    local counts = logger.get_session_counts()
    assert.equals(2, counts['j'])
  end)
end)

-- ── set_suppressed ───────────────────────────────────────────────────────────

describe('when a command is explicitly suppressed', function()
  before_each(function()
    wipe_disk()
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
    wipe_disk()
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
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    assert.equals(3, logger.get('e').sessions[1])
  end)

  it('after close_session the next session starts fresh', function()
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    local sessions = logger.get('e').sessions
    assert.equals(2, #sessions)
    assert.equals(3, sessions[1])
    assert.equals(1, sessions[2])
  end)

  it('sessions array is capped at 10 entries', function()
    for _ = 1, 12 do
      vim.fn.feedkeys('e', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
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
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session() -- 'e' now known: sessions = {1}

    -- Next session: only 'w' is used, 'e' is untouched.
    vim.fn.feedkeys('w', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()

    assert.same({ 1, 0 }, logger.get('e').sessions)
    assert.same({ 1 }, logger.get('w').sessions)
  end)

  it('does not zero-pad a command that has never been used at all', function()
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    -- 'w' was never used in any session — should stay entirely absent, not
    -- gain a spurious sessions = {0} entry.
    assert.same({}, logger.get('w').sessions)
    assert.equals(0, logger.get('w').count)
  end)

  it('zero-padding also respects the 10-entry cap', function()
    vim.fn.feedkeys('e', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    logger.close_session()
    for _ = 1, 12 do
      vim.fn.feedkeys('w', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
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
    vim.fn.feedkeys('eee', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
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
    wipe_disk()
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
    vim.fn.mode = function()
      return 'i'
    end
    vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
    vim.fn.mode = real_mode
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
    assert.equals(0, logger.get('j').count)
  end)

  it('resets both seq and insert_seq when current_mode is neither n nor i', function()
    -- Visual mode ('v') exercises the generic fallback branch — distinct
    -- from both the normal path and the #58 insert-mode path.
    local real_mode = vim.fn.mode
    vim.fn.mode = function()
      return 'v'
    end
    vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
    vim.fn.mode = real_mode
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    vim.fn.feedkeys('j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
    assert.equals(0, logger.get('j').count)
  end)
end)

-- ── terminal mode: ineffective <Esc> → suggest <C-\><C-n> (#110) ─────────────
-- mode() == 't' is terminal-job mode: keys go straight to the job, not to
-- Neovim's own key handling. Headless Neovim can never actually enter 't'
-- mode (there is no real job to attach to), so these tests use the same
-- vim.fn.mode() stub + synthetic ModeChanged technique as the 'i' mode
-- tests above (see tests/CLAUDE.md's "Testing non-normal mode in headless
-- Neovim").

local function enter_terminal_mode()
  local real_mode = vim.fn.mode
  vim.fn.mode = function()
    return 't'
  end
  vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
  vim.fn.mode = real_mode
end

local function leave_terminal_mode_to_normal()
  local real_mode = vim.fn.mode
  vim.fn.mode = function()
    return 'n'
  end
  vim.api.nvim_exec_autocmds('ModeChanged', { modeline = false })
  vim.fn.mode = real_mode
end

describe('when the user is stuck in terminal mode', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    enter_terminal_mode()
  end)

  after_each(function()
    logger.on_pattern = nil
    leave_terminal_mode_to_normal()
  end)

  it('does not fire on a single <Esc> with no effect', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    vim.fn.feedkeys(esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)

  it('fires terminal_esc_repeat suggesting <C-\\><C-n> on the second consecutive <Esc>', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    vim.fn.feedkeys(esc, 'xt')
    vim.fn.feedkeys(esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(1, #fired)
    assert.equals('terminal_esc_repeat', fired[1].pattern)
    assert.equals('<C-\\><C-n>', fired[1].cmd)
  end)

  it('does not spam the suggestion on further <Esc> presses in the same streak', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    vim.fn.feedkeys(esc, 'xt')
    vim.fn.feedkeys(esc, 'xt')
    vim.fn.feedkeys(esc, 'xt')
    vim.fn.feedkeys(esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(1, #fired, 'expected exactly one suggestion despite 4 consecutive <Esc> presses')
  end)

  it('resets the streak once the user actually leaves terminal mode', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    vim.fn.feedkeys(esc, 'xt') -- 1st Esc, no fire yet
    vim.api.nvim_feedkeys('', 'x', false)
    leave_terminal_mode_to_normal() -- successful exit — a real mode change
    enter_terminal_mode() -- back into a fresh terminal session
    vim.fn.feedkeys(esc, 'xt') -- only the 1st Esc of the NEW session
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, #fired, 'a single leftover Esc from a previous session must not carry over')
  end)
end)

describe('terminal-mode <Esc> detection does not affect other modes (mode isolation)', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

  before_each(function()
    wipe_disk()
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

  it('still fires insert_bounce (not terminal_esc_repeat) for <Esc> <Esc> in insert mode', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    -- Each enter/escape round-trip fed as one feedkeys call (not separate
    -- ones) so the mode cache's ModeChanged autocmd has definitely fired by
    -- the time <Esc> is processed — see the <C-w> test elsewhere in this
    -- file for the same rule.
    vim.fn.feedkeys('i' .. esc, 'xt')
    vim.fn.feedkeys('i' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(1, #fired)
    assert.equals('insert_bounce', fired[1].pattern)
    assert.equals('A', fired[1].cmd)
  end)

  it('still lets <Esc> cancel a pending operator in normal mode with no pattern fired', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    vim.fn.feedkeys('d', 'xt')
    vim.fn.feedkeys(esc, 'xt')
    vim.fn.feedkeys('w', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)
end)

describe('when ModeChanged fires to operator-pending before the motion arrives', function()
  before_each(function()
    wipe_disk()
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
    vim.fn.mode = function()
      return 'no'
    end
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
    wipe_disk()
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
    wipe_disk()
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
  local ctrl_n = vim.api.nvim_replace_termcodes('<C-n>', true, false, true)

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

describe('insert-mode completion detection (#112)', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  local ctrl_n = vim.api.nvim_replace_termcodes('<C-n>', true, false, true)

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

  it('fires insert_completion_repeat suggesting <C-n> when a 6+ char word is typed twice in full', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      fired = { pattern = pattern, cmd = cmd }
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
    vim.fn.feedkeys('iidentifier identifier' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals('insert_completion_repeat', fired.pattern)
    assert.equals('<C-n>', fired.cmd)
  end)

  it('does not fire for a short word retyped several times', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
    vim.fn.feedkeys('iif if if' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)

  it('increments the usage count for <C-n> only while actually in insert mode', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar' })
    vim.fn.feedkeys('A' .. ctrl_n .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('<C-n>').count > 0)
  end)

  it('does not count the normal-mode down-motion <C-n> as the insert-mode completion command', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
    vim.fn.feedkeys(ctrl_n, 'xt') -- normal-mode Ctrl-N: move down a line, unrelated command
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('<C-n>').count)
  end)
end)

-- #105: insert-mode <C-o> (run exactly one Normal-mode command, then return
-- to insert automatically). See commands.lua's 'i_<C-o>' registry comment for
-- why this is a distinct composite key from the normal-mode '<C-o>' entry.
describe('insert-mode <C-o> one-shot detection (#105)', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  local ctrl_o = vim.api.nvim_replace_termcodes('<C-o>', true, false, true)

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

  it("increments 'i_<C-o>' when the real insert-mode <C-o> is pressed", function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
    -- <C-o>l moves right one column (the one Normal command), then Neovim
    -- returns to insert mode automatically — no explicit i/a needed.
    vim.fn.feedkeys('A' .. ctrl_o .. 'l' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('i_<C-o>').count > 0)
  end)

  it('does not count the normal-mode jumplist-back <C-o> as the insert-mode command', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
    vim.fn.feedkeys(ctrl_o, 'xt') -- pure normal-mode <C-o>, never entered insert
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('i_<C-o>').count)
  end)

  it('fires insert_co_oneshot when <Esc> is followed by exactly one motion then back to insert', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      if pattern == 'insert_co_oneshot' then
        fired = { pattern = pattern, cmd = cmd }
      end
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line one', 'line two', 'line three' })
    vim.fn.feedkeys('i' .. esc .. 'j' .. 'i', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals('insert_co_oneshot', fired.pattern)
    assert.equals('i_<C-o>', fired.cmd)
  end)

  it('does not fire insert_co_oneshot when 2 or more motions are interleaved before returning', function()
    local fired = false
    logger.on_pattern = function(pattern)
      if pattern == 'insert_co_oneshot' then
        fired = true
      end
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line one', 'line two', 'line three' })
    vim.fn.feedkeys('i' .. esc .. 'j' .. 'k' .. 'i', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)

  it('does not fire insert_co_oneshot when returning to insert with no motion at all', function()
    local fired = false
    logger.on_pattern = function(pattern)
      if pattern == 'insert_co_oneshot' then
        fired = true
      end
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line one' })
    vim.fn.feedkeys('i' .. esc .. 'i', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)
end)

-- patterns.feed() (patterns.lua) and feed_after_escape() (patterns_insert.lua,
-- #105) are both fed the same Normal-mode keystroke in handle_key and can
-- both produce a result for it — e.g. <Esc>0i matches patterns.lua's
-- zero_col_then_insert (0 then i -> suggest gI) AND patterns_insert.lua's
-- insert_co_oneshot (Esc, one motion, back to insert -> suggest <C-o>).
-- Before this reconciliation existed, whichever call happened to run second
-- in handle_key's source order won the race in suggest.queue() by accident.
-- logger.lua now decides deterministically: patterns.lua's result (a
-- pre-existing, more specific suggestion) always takes priority over
-- patterns_insert.lua's generic insert_co_oneshot hint for the same
-- keystroke. See logger.lua's handle_key for the implementation.
describe('reconciling insert_co_oneshot with pre-existing specific patterns (priority)', function()
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

  local function feed_and_collect(keys)
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
    vim.fn.feedkeys(keys, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    return fired
  end

  it('fires only zero_col_then_insert (gI) for <Esc>0i, not insert_co_oneshot', function()
    local fired = feed_and_collect('i' .. esc .. '0i')
    assert.equals(1, #fired)
    assert.equals('zero_col_then_insert', fired[1].pattern)
    assert.equals('gI', fired[1].cmd)
  end)

  it('fires only x_then_insert (s) for <Esc>xi, not insert_co_oneshot', function()
    local fired = feed_and_collect('i' .. esc .. 'xi')
    assert.equals(1, #fired)
    assert.equals('x_then_insert', fired[1].pattern)
    assert.equals('s', fired[1].cmd)
  end)

  it('fires only dollar_then_append (A) for <Esc>$a, not insert_co_oneshot', function()
    local fired = feed_and_collect('i' .. esc .. '$a')
    assert.equals(1, #fired)
    assert.equals('dollar_then_append', fired[1].pattern)
    assert.equals('A', fired[1].cmd)
  end)

  it('still fires insert_co_oneshot for <Esc>hi (no competing specific pattern)', function()
    local fired = feed_and_collect('i' .. esc .. 'hi')
    assert.equals(1, #fired)
    assert.equals('insert_co_oneshot', fired[1].pattern)
    assert.equals('i_<C-o>', fired[1].cmd)
  end)

  it('still fires insert_co_oneshot for <Esc>li (no competing specific pattern)', function()
    local fired = feed_and_collect('i' .. esc .. 'li')
    assert.equals(1, #fired)
    assert.equals('insert_co_oneshot', fired[1].pattern)
    assert.equals('i_<C-o>', fired[1].cmd)
  end)

  it('still fires insert_co_oneshot for <Esc>wi (no competing specific pattern)', function()
    local fired = feed_and_collect('i' .. esc .. 'wi')
    assert.equals(1, #fired)
    assert.equals('insert_co_oneshot', fired[1].pattern)
    assert.equals('i_<C-o>', fired[1].cmd)
  end)
end)

-- ── Ex command tracking (#57) ────────────────────────────────────────────────
-- vim.on_key sees every keystroke including cmdline ones. Confirmed
-- empirically (not just assumed): querying vim.fn.getcmdtype()/getcmdline()
-- from inside the on_key callback for the terminating <CR>/<Esc> keystroke
-- still reports the PRE-submission state (mode/cmdtype have not flipped back
-- to normal yet, and getcmdline() still holds the full buffer content) —
-- same timing property patterns_insert.lua's bounce-detection design note
-- relies on for <Esc> vs insert mode. Unlike insert mode, cmdline mode is
-- genuinely enterable via feedkeys in headless Neovim, so these tests need
-- no vim.fn.mode() stubbing.

describe('Ex command tracking (#57)', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
  local cr = vim.api.nvim_replace_termcodes('<CR>', true, true, true)
  local up = vim.api.nvim_replace_termcodes('<Up>', true, true, true)
  local ctrl_c = vim.api.nvim_replace_termcodes('<C-c>', true, true, true)

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'TODO', 'foo' })
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      pcall(vim.api.nvim_input, esc)
    end
  end)

  it('increments usage["ex:s"] when a %s/../../ substitute command is completed', function()
    pcall(vim.fn.feedkeys, ':%s/foo/bar/g' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('ex:s').count > 0)
  end)

  it('increments usage["ex:g"] when a global command is completed', function()
    pcall(vim.fn.feedkeys, ':g/TODO/d' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('ex:g').count > 0)
  end)

  it('does not increment usage["ex:s"] when the command is aborted with <Esc> before <CR>', function()
    pcall(vim.fn.feedkeys, ':s/foo' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('ex:s').count)
  end)

  it('does not increment anything when the command is canceled mid-typing with <C-c>', function()
    pcall(vim.fn.feedkeys, ':g/TOD' .. ctrl_c, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('ex:g').count)
  end)

  it('increments the recalled command when it is submitted via <Up> history recall', function()
    -- Prime recall by typing (and aborting) a target command first. Neovim's
    -- <Up> recalls the most recently edited command line regardless of
    -- whether it was submitted or aborted — this is exactly why reading
    -- vim.fn.getcmdline() at <CR> time (not reconstructing keystrokes
    -- ourselves) is the right design: <Up> never "types" characters that a
    -- manual accumulator could append.
    pcall(vim.fn.feedkeys, ':g/TODO/d' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(0, logger.get('ex:g').count) -- the primer itself was aborted

    pcall(vim.fn.feedkeys, ':' .. up .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('ex:g').count > 0)
  end)

  it('does not track a search (/) cmdline as an Ex command', function()
    pcall(vim.fn.feedkeys, '/foo' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    local has_ex_key = false
    for cmd in pairs(logger.get_all()) do
      if cmd:sub(1, 3) == 'ex:' then
        has_ex_key = true
      end
    end
    assert.is_false(has_ex_key, 'a / search must never be tokenized as an Ex command')
  end)

  it('does not fire an on_pattern callback (usage-based tracking, not a reactive pattern)', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end
    pcall(vim.fn.feedkeys, ':g/TODO/d' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_false(fired)
  end)
end)

-- ── Ex command tracking excludes tobira's own commands (QA bug on #57) ──────
-- Running tobira's own UI commands (:TobiraStats, :TobiraGuide, ...) got
-- tokenized and tracked as Ex-command usage themselves -- e.g. running
-- :TobiraReset once made "ex:tobirastats" show up as a top command in
-- :TobiraStats, even though the user only ever ran :TobiraReset. Any command
-- whose tokenized name starts with tobira's own command prefix must never be
-- tracked. See plugin/tobira.lua for the definitive list of registered
-- commands (all share the 'Tobira' prefix).

describe("Ex command tracking excludes tobira's own commands", function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
  local cr = vim.api.nvim_replace_termcodes('<CR>', true, true, true)

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'TODO', 'foo' })
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      pcall(vim.api.nvim_input, esc)
    end
  end)

  -- Asserts no ex:* key exists at all (rather than checking one specific key)
  -- so this also catches the tokenizer producing an unexpected variant, e.g.
  -- if a future refactor of tokenize()'s casing broke the prefix match.
  local function assert_no_ex_key_tracked()
    for cmd in pairs(logger.get_all()) do
      assert.is_false(cmd:sub(1, 3) == 'ex:', 'expected no ex:* usage key to be tracked, but found ' .. cmd)
    end
  end

  it('does not track :TobiraStats as Ex-command usage', function()
    pcall(vim.fn.feedkeys, ':TobiraStats' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert_no_ex_key_tracked()
  end)

  it('does not track :TobiraGuide as Ex-command usage', function()
    pcall(vim.fn.feedkeys, ':TobiraGuide' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert_no_ex_key_tracked()
  end)

  it('does not track :TobiraReset as Ex-command usage', function()
    pcall(vim.fn.feedkeys, ':TobiraReset' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert_no_ex_key_tracked()
  end)

  it('does not track :Tobira as Ex-command usage', function()
    pcall(vim.fn.feedkeys, ':Tobira' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert_no_ex_key_tracked()
  end)

  it('does not track :TobiraProgress as Ex-command usage', function()
    pcall(vim.fn.feedkeys, ':TobiraProgress' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert_no_ex_key_tracked()
  end)

  it('still tracks an ordinary Ex command that merely starts with an unrelated word', function()
    -- Over-broad exclusion guard: only tobira's own prefix should be
    -- excluded, not every Ex command in general.
    pcall(vim.fn.feedkeys, ':%s/foo/bar/g' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.is_true(logger.get('ex:s').count > 0)
  end)
end)

-- ── Repeated substitute detection (#115) ────────────────────────────────────
-- Builds on #57's cmdline infrastructure: logger.lua's handle_cmdline_key
-- feeds the same completed cmdline text to
-- patterns_cmdline.track_substitute() alongside tokenize(). See that
-- module's header comment for the full parsing scope and the &-vs-g&
-- threshold heuristic (2nd distinct line -> &, 3rd distinct line -> g&).

describe('Repeated substitute detection (#115)', function()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
  local cr = vim.api.nvim_replace_termcodes('<CR>', true, true, true)

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'foo', 'foo' })
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      pcall(vim.api.nvim_input, esc)
    end
  end)

  local function goto_line(n)
    vim.api.nvim_win_set_cursor(0, { n, 0 })
  end

  local function run_substitute(text)
    pcall(vim.fn.feedkeys, ':' .. text .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    -- Verify-before-credit fix (bug found by QA, same problem/timing class as
    -- #114's ex_file_pingpong fix): the actual credit is now deferred to
    -- vim.schedule(), which only runs once Neovim has fully processed this
    -- <CR> (command succeeded, or already failed, against the buffer's
    -- changedtick snapshotted right before it ran). Each call needs to let
    -- that settle before the next one starts, otherwise multiple pending
    -- callbacks in these tests' synthetic back-to-back feedkeys would all
    -- resolve against whatever changedtick is current by then rather than
    -- each against the outcome of ITS OWN command.
    vim.wait(20)
  end

  it('fires substitute_repeat / & when the same :s/// runs on a second distinct line', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end

    goto_line(1)
    run_substitute('s/foo/bar/')
    goto_line(2)
    run_substitute('s/foo/bar/')

    assert.equals(1, #fired)
    assert.equals('substitute_repeat', fired[1].pattern)
    assert.equals('&', fired[1].cmd)
  end)

  it('fires substitute_repeat_wide / g& when a third distinct line repeats it', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end

    for i = 1, 3 do
      goto_line(i)
      run_substitute('s/foo/bar/')
    end

    assert.equals(2, #fired)
    assert.equals('substitute_repeat_wide', fired[2].pattern)
    assert.equals('g&', fired[2].cmd)
  end)

  it('does not fire when the pattern differs between invocations', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end

    goto_line(1)
    run_substitute('s/foo/bar/')
    goto_line(2)
    run_substitute('s/food/bar/')

    assert.is_false(fired)
  end)

  it('does not fire when the replacement differs between invocations', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end

    goto_line(1)
    run_substitute('s/foo/bar/')
    goto_line(2)
    run_substitute('s/foo/baz/')

    assert.is_false(fired)
  end)

  it('does not count an aborted :s toward the repeat (consistent with #57 abort handling)', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end

    -- Typed but aborted with <Esc> before <CR> -- must not be counted as a
    -- completed invocation on this line.
    goto_line(1)
    pcall(vim.fn.feedkeys, ':s/foo/bar/' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)

    -- Only one REAL completed substitute so far (below); must not fire yet.
    goto_line(2)
    run_substitute('s/foo/bar/')
    assert.is_false(fired, 'expected no fire after only one completed invocation')

    -- Second real completed substitute on a new distinct line now fires.
    goto_line(3)
    run_substitute('s/foo/bar/')
    assert.is_true(fired)
  end)

  it('does not track a ranged substitute (:%s) toward the repeat', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end

    run_substitute('%s/foo/bar/')

    goto_line(1)
    run_substitute('s/foo/bar/')

    assert.is_false(fired) -- only one bare (unranged) invocation counted
  end)

  -- Regression test for a QA-found false positive: track_substitute() used to
  -- be fed straight from the cmdline TEXT with no check of whether Neovim
  -- actually executed/matched it. Retyping an identical :s/// that matches
  -- NOTHING on two different lines (E486 "Pattern not found" both times, zero
  -- substitutions performed) must never be credited as a real repeated edit.
  it('does not fire when the identical :s/// fails to match anything on either line (E486)', function()
    local fired = false
    logger.on_pattern = function()
      fired = true
    end

    goto_line(1)
    run_substitute('s/nonexistent_pattern_xyz/foo/')
    goto_line(2)
    run_substitute('s/nonexistent_pattern_xyz/foo/')

    assert.is_false(fired, 'a substitute that never matched must never credit the &/g& streak')
  end)

  it('still fires normally once a real match succeeds after an earlier failed attempt', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end

    -- A failed attempt on line 1 must not poison the state for the real
    -- (matching) substitute that follows.
    goto_line(1)
    run_substitute('s/nonexistent_pattern_xyz/foo/')
    goto_line(1)
    run_substitute('s/foo/bar/')
    goto_line(2)
    run_substitute('s/foo/bar/')

    assert.equals(1, #fired)
    assert.equals('substitute_repeat', fired[1].pattern)
    assert.equals('&', fired[1].cmd)
  end)
end)

-- ── :e/:b file ping-pong detection (#114) ────────────────────────────────────
-- Wires patterns_cmdline.command_arg()/feed_pingpong() into the same <CR>
-- handling handle_cmdline_key already does for tokenize() (#57). Real :e/:b
-- commands are run against buffer names that don't exist on disk yet, which
-- is safe in headless Neovim: :e just opens a new in-memory buffer with that
-- name, and :b only needs a same-named buffer to already exist (created by
-- an earlier :e in the same test), so nothing ever touches the filesystem.

describe(':e/:b file ping-pong detection (#114)', function()
  local cr = vim.api.nvim_replace_termcodes('<CR>', true, true, true)

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('enew!')
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      pcall(vim.api.nvim_input, vim.api.nvim_replace_termcodes('<Esc>', true, true, true))
    end
  end)

  it('fires ex_file_pingpong suggesting <C-^> when bouncing :e A -> :e B -> :e A', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end

    -- The actual credit for each switch is now deferred (vim.schedule, #114
    -- verify-before-credit fix), so each command needs a short vim.wait()
    -- before the next one starts -- otherwise multiple pending callbacks
    -- would all resolve at once, against whatever buffer is current by then,
    -- rather than each against the buffer immediately after ITS OWN command
    -- (see logger.lua's handle_cmdline_key comment on vim.schedule ordering).
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_a.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_b.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_a.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)

    local found = nil
    for _, f in ipairs(fired) do
      if f.pattern == 'ex_file_pingpong' then
        found = f
      end
    end
    assert.is_not_nil(found, 'expected ex_file_pingpong to fire on the A -> B -> A bounce')
    assert.equals('<C-^>', found.cmd)
  end)

  it('fires when the return trip is via :b instead of :e', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end

    pcall(vim.fn.feedkeys, ':e tobira_pingpong_c.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_d.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    pcall(vim.fn.feedkeys, ':b tobira_pingpong_c.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)

    local found = nil
    for _, f in ipairs(fired) do
      if f.pattern == 'ex_file_pingpong' then
        found = f
      end
    end
    assert.is_not_nil(found, 'expected :b to count toward the same ping-pong rotation as :e')
    assert.equals('<C-^>', found.cmd)
  end)

  it('does not fire when switching between 3+ different files', function()
    local fired = {}
    logger.on_pattern = function(pattern)
      table.insert(fired, pattern)
    end

    local files = {
      'tobira_pingpong_e.txt',
      'tobira_pingpong_f.txt',
      'tobira_pingpong_g.txt',
      'tobira_pingpong_e.txt',
      'tobira_pingpong_f.txt',
      'tobira_pingpong_g.txt',
    }
    for _, name in ipairs(files) do
      pcall(vim.fn.feedkeys, ':e ' .. name .. cr, 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
      vim.wait(20)
    end

    for _, pattern in ipairs(fired) do
      assert.are_not.equal('ex_file_pingpong', pattern, 'a 3+ file rotation must never fire the 2-file ping-pong')
    end
  end)

  it('resets the ping-pong history on logger.reset()', function()
    -- Each command's deferred verification (#114 fix) must settle BEFORE
    -- logger.reset() reassigns the module-local pingpong_seq -- otherwise
    -- these two commands' still-pending callbacks would run against the
    -- fresh post-reset seq instead of the one they belong to. In real usage
    -- there's no way for a stale callback to still be pending by the time a
    -- user deliberately runs :TobiraReset (see logger.lua's ordering
    -- comment); this vim.wait() only recreates that natural settling point
    -- for a synthetic back-to-back test.
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_h.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_i.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)

    logger.reset()
    logger.setup()

    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    -- Without the reset, this would be the 3rd distinct-file switch relative
    -- to the two :e calls above and would fire; after reset it must be
    -- treated as only the 2nd switch ever, in a fresh history.
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_h.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)

    assert.equals(0, #fired, 'ping-pong history must not survive logger.reset()')
  end)

  -- Regression test for a QA-found false positive (#114 follow-up): tokenize()/
  -- command_arg() only see the TEXT of the submitted :e/:b command, read at
  -- <CR> time before Neovim has validated or executed it. Typing and
  -- submitting the command is not the same thing as the file switch actually
  -- happening -- Neovim can still reject it outright. This reproduces the
  -- exact rejected-command shape and confirms no switch is ever credited
  -- unless it really happened.
  it('does not fire when the file switches were rejected by Neovim, not real bounces', function()
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end

    -- 1) :e alpha.txt -- a real, successful switch.
    pcall(vim.fn.feedkeys, ':e tobira_pingpong_reject_alpha.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)

    -- 2) Dirty edit, never saved.
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved change' })
    assert.is_true(vim.bo.modified)

    -- 3) :b gamma.txt -- gamma.txt was never opened, so Neovim rejects this
    --    with E94 ("No matching buffer"). The current buffer stays alpha.txt.
    local ok_b = pcall(vim.fn.feedkeys, ':b tobira_pingpong_reject_gamma.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    assert.is_false(ok_b, 'expected :b on a never-opened name to raise E94')
    assert.equals('tobira_pingpong_reject_alpha.txt', vim.fn.bufname('%'))

    -- 4) :e alpha.txt again, still dirty and without ! -- Neovim rejects this
    --    with E37 ("No write since last change"). The buffer never reloads.
    local ok_e = pcall(vim.fn.feedkeys, ':e tobira_pingpong_reject_alpha.txt' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.wait(20)
    assert.is_false(ok_e, 'expected :e on a dirty buffer without ! to raise E37')
    assert.equals('tobira_pingpong_reject_alpha.txt', vim.fn.bufname('%'))

    -- Only one real switch ever happened (step 1). Textually this looks like
    -- alpha -> gamma -> alpha, but no bounce actually occurred, so
    -- ex_file_pingpong must never fire.
    for _, f in ipairs(fired) do
      assert.are_not.equal('ex_file_pingpong', f.pattern, 'a rejected :e/:b must never be credited as a real file switch')
    end
  end)
end)

-- ── tabnew one-file-per-tab habit detection (#113) ───────────────────────────
-- logger.lua threads vim.api.nvim_tabpage_list_wins into
-- patterns_cmdline.feed_tabnew() the same way it threads vim.wo.diff into
-- patterns.feed() for #111 — see patterns_cmdline.lua's module comment for
-- the full design. Real :tabnew / :split here (not stubs) so the window
-- structure feed_tabnew() reads is genuine, not simulated.

describe('tabnew one-file-per-tab habit detection (#113)', function()
  local cr = vim.api.nvim_replace_termcodes('<CR>', true, true, true)

  before_each(function()
    wipe_disk()
    logger.reset()
    logger.on_pattern = nil
    logger.setup()
    vim.cmd('silent! tabonly!')
    vim.cmd('enew!')
  end)

  after_each(function()
    logger.on_pattern = nil
    if vim.fn.mode() ~= 'n' then
      pcall(vim.api.nvim_input, vim.api.nvim_replace_termcodes('<Esc>', true, true, true))
    end
    vim.cmd('silent! tabonly!')
  end)

  local function tabnew(name)
    pcall(vim.fn.feedkeys, ':tabnew tobira_test_' .. name .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
  end

  it('fires tabnew_run, suggesting <C-^>, after 3 :tabnew {file} calls each opening a fresh single-window tab', function()
    local fired_pattern, fired_cmd = nil, nil
    logger.on_pattern = function(pattern, cmd)
      fired_pattern = pattern
      fired_cmd = cmd
    end

    tabnew('a.txt')
    assert.is_nil(fired_pattern)
    tabnew('b.txt')
    assert.is_nil(fired_pattern)
    tabnew('c.txt')

    assert.equals('tabnew_run', fired_pattern)
    assert.equals('<C-^>', fired_cmd)
  end)

  it('does not fire when a window was split inside one of the tabs before the streak reached 3', function()
    local fired_pattern = nil
    logger.on_pattern = function(pattern)
      fired_pattern = pattern
    end

    tabnew('a.txt')
    tabnew('b.txt')
    vim.cmd('split') -- the tab :tabnew b.txt opened now has 2 windows
    tabnew('c.txt')

    assert.is_nil(fired_pattern, 'the split should have reset the streak before it reached 3')
  end)

  it('does not extend the streak for a bare :tabnew with no file argument', function()
    local fired_pattern = nil
    logger.on_pattern = function(pattern)
      fired_pattern = pattern
    end

    tabnew('a.txt')
    pcall(vim.fn.feedkeys, ':tabnew' .. cr, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    tabnew('b.txt')
    tabnew('c.txt')

    assert.is_nil(fired_pattern, 'the bare :tabnew should have reset the streak, needing 3 more file tabnews to fire')
  end)

  it('still tracks ex:tabnew usage the same way every other Ex command is tracked', function()
    tabnew('a.txt')
    assert.is_true(logger.get('ex:tabnew').count > 0)
  end)

  -- Regression (QA): opening the exact same file 3x via :tabnew used to fire
  -- the suggestion anyway, because the pre-fix implementation only tracked
  -- whether :tabnew was given SOME argument, never which filename. Vim
  -- reuses the existing buffer for a file already open in another tab, so
  -- this scenario only ever has 1 real buffer — the resulting :b / <C-^>
  -- suggestion made no sense. See patterns_cmdline.feed_tabnew's doc comment
  -- for the fix (threading the actual filename, resetting on a repeat).
  it('does not fire when the exact same file is opened via :tabnew repeatedly', function()
    local fired_pattern = nil
    logger.on_pattern = function(pattern)
      fired_pattern = pattern
    end

    tabnew('samefile.txt')
    tabnew('samefile.txt')
    tabnew('samefile.txt')

    assert.is_nil(fired_pattern, 'reopening a file already open in another tab is not one-tab-per-file browsing')
  end)
end)

-- (stats rendering has moved to tests/spec/unit/ui_stats_spec.lua)

-- ── save ─────────────────────────────────────────────────────────────────────

describe('when save is called explicitly', function()
  before_each(function()
    wipe_disk()
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
    if f then
      f:close()
    end
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

-- ── clear_disk (:TobiraReset, #122) ─────────────────────────────────────────
-- save() deliberately merges with disk so concurrent instances never clobber
-- each other. :TobiraReset's "erase everything" action needs the opposite
-- guarantee — an empty in-memory `usage` must actually end up empty on disk,
-- not get merged back up to whatever was there before. clear_disk() is the
-- dedicated escape hatch for that one caller.

describe('when clear_disk is called after a reset', function()
  before_each(function()
    wipe_disk()
    logger.reset()
  end)

  it('erases previously-saved data instead of merging it back in', function()
    logger.mark_shown('f')
    logger.set_suppressed(';', true)

    logger.reset()
    logger.clear_disk()
    logger.load_from_disk()

    assert.same({}, logger.get_all())
  end)

  it('differs from save(), which would merge stale disk data back in', function()
    logger.mark_shown('f')

    logger.reset()
    -- save() is the merge-aware path — confirms clear_disk() is not simply
    -- redundant with it. Reading the raw file (rather than load_from_disk(),
    -- which always resets .shown to 0 for the per-launch max_shown cap) is
    -- what actually distinguishes "merged back in" from "erased".
    logger.save()

    local f = io.open(logger.data_file(), 'r')
    local disk = vim.json.decode(f:read('*a'))
    f:close()

    assert.is_not_nil(disk.f)
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

  it("adds this session's delta on top of the concurrent count instead of overwriting it", function()
    -- Press 'e' 3 times in this session (delta = 3).
    for _ = 1, 3 do
      vim.fn.feedkeys('e', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
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

-- ── concurrent-instance field protection (#122) ───────────────────────────────
-- close_session() already merged `.count`; these cover every OTHER
-- save-triggering function (mark_shown, set_suppressed, ...) and every OTHER
-- field (.sessions, .suppressed, .pinned, .celebrated), which previously had
-- no merge at all — a save from any of them clobbered whatever a concurrent
-- Neovim instance had just written.

describe('when a concurrent Neovim instance has suppressed a command', function()
  before_each(function()
    wipe_disk()
    logger.reset()
    logger.setup()
  end)

  it("is not lost when this instance's mark_shown saves afterward", function()
    -- This instance never touches ';' at all — a second, concurrent instance
    -- suppressed it and wrote that directly to disk.
    local data_dir = vim.fn.stdpath('data') .. '/tobira'
    vim.fn.mkdir(data_dir, 'p')
    local f = io.open(data_dir .. '/usage.json', 'w')
    f:write(vim.json.encode({
      [';'] = { count = 0, sessions = {}, shown = 0, suppressed = true, pinned = false, celebrated = false },
    }))
    f:close()

    -- This instance is unaware of that and records an unrelated suggestion
    -- being shown, which used to call save() and overwrite the whole file.
    logger.mark_shown('other_cmd')

    logger.load_from_disk()
    assert.is_true(logger.get(';').suppressed)
  end)

  it('is still un-suppressible by this instance after a concurrent write to a different command', function()
    logger.set_suppressed('f', true)

    -- A concurrent instance saves something unrelated in between.
    local data_dir = vim.fn.stdpath('data') .. '/tobira'
    local disk_f = io.open(data_dir .. '/usage.json', 'r')
    local disk = vim.json.decode(disk_f:read('*a'))
    disk_f:close()
    disk.other_cmd = { count = 1, sessions = {}, shown = 0, suppressed = false, pinned = false, celebrated = false }
    local write_f = io.open(data_dir .. '/usage.json', 'w')
    write_f:write(vim.json.encode(disk))
    write_f:close()

    -- This instance's own explicit un-suppress must still win for its own flag.
    logger.set_suppressed('f', false)

    logger.load_from_disk()
    assert.is_false(logger.get('f').suppressed)
    assert.equals(1, logger.get('other_cmd').count)
  end)
end)

describe('when a concurrent Neovim instance has recorded its own session', function()
  before_each(function()
    wipe_disk()
    logger.reset()
    logger.setup()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
  end)

  it("retains both instances' recorded sessions instead of one overwriting the other", function()
    -- This instance uses 'e' twice this session.
    vim.fn.feedkeys('ee', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)

    -- A concurrent instance already closed its own session for 'e' and wrote
    -- that to disk before this instance's close_session runs.
    local data_dir = vim.fn.stdpath('data') .. '/tobira'
    vim.fn.mkdir(data_dir, 'p')
    local f = io.open(data_dir .. '/usage.json', 'w')
    f:write(vim.json.encode({
      e = { count = 3, sessions = { 3 }, shown = 0, suppressed = false, pinned = false, celebrated = false },
    }))
    f:close()

    logger.close_session()
    logger.load_from_disk()

    assert.same({ 3, 2 }, logger.get('e').sessions)
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

describe('when locating the on-disk usage data directory and file (for :checkhealth)', function()
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
    wipe_disk()
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

  -- #59: "+y system-clipboard yank, tracked via patterns.lua's
  -- pending_clipboard_yank compound (see patterns_spec.lua for the pure-logic
  -- coverage of the state machine itself).
  it('tracks "+y as a compound command', function()
    pcall(vim.fn.feedkeys, '"+yy', 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    assert.is_true(logger.get('"+y').count > 0)
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

  -- pending_ctrl_w (#120) was added after op_completed (#119) already existed
  -- elsewhere in patterns.lua, so its last_op assignment needed the same flag
  -- added by hand during the merge — this is the integration-level guard
  -- against that path silently regressing to the #119 undercount bug.
  it('increments the usage count for <C-w>j by 2 when it is run twice in a row', function()
    pcall(vim.fn.feedkeys, ctrl_w .. 'j', 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    pcall(vim.fn.feedkeys, ctrl_w .. 'j', 'xt')
    pcall(vim.api.nvim_feedkeys, '', 'x', false)
    assert.equals(2, logger.get('<C-w>j').count)
  end)

  -- #119: consecutive identical compounds (dd dd, dw dw, …) were undercounted
  -- because the old detection compared seq.last_op's value before/after each
  -- keystroke — a second, identical compound re-assigns the same string, so
  -- no value change was observed and the second occurrence was silently
  -- dropped from the count.
  it('increments the usage count for dd by 2 when dd is run twice in a row', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb', 'ccc' })
    vim.fn.feedkeys('dd', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('dd', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(2, logger.get('dd').count)
  end)

  it('increments the usage count for dw by 2 when dw is run twice in a row', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world foo bar' })
    vim.fn.feedkeys('dw', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('dw', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(2, logger.get('dw').count)
  end)

  it('keeps counting dd on every repeat, even the one that also fires the dd_run streak', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb', 'ccc', 'ddd' })
    for _ = 1, 3 do
      vim.fn.feedkeys('dd', 'xt')
      vim.api.nvim_feedkeys('', 'x', false)
    end
    assert.equals(3, logger.get('dd').count)
  end)

  it('does not double count dd when it is immediately consumed by dd_then_p', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb' })
    vim.fn.feedkeys('ddp', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(1, logger.get('dd').count)
  end)

  it('does not double count dw when it is immediately consumed by dw_then_insert', function()
    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world' })
    vim.fn.feedkeys('dwi' .. esc, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    assert.equals(1, logger.get('dw').count)
  end)

  -- All Ctrl keys changed to track=true are verified here so a stray
  -- track=false revert is caught immediately by CI.
  -- pcall absorbs Neovim errors (e.g. E433 for <C-]> with no tags file):
  -- on_key fires before the command executes so the count is already set.
  local ctrl_keys = {
    '<C-r>',
    '<C-o>',
    '<C-i>',
    '<C-f>',
    '<C-b>',
    '<C-a>',
    '<C-x>',
    '<C-v>',
    '<C-e>',
    '<C-y>',
    '<C-^>',
    '<C-]>',
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
    wipe_disk()
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
    ';',
    ',',
    '.',
    '*',
    '#',
    '~',
    '&', -- #115: repeat last :substitute on the current line
    'A',
    'b',
    'C',
    'D',
    'e',
    'F',
    'H',
    'I',
    'J',
    'L',
    'M',
    'N',
    'O',
    'P',
    'r',
    's',
    't',
    'V',
    'w',
    'X',
    'Y',
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
    wipe_disk()
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
    '}',
    '{',
    '(',
    ')',
    '%',
    '^',
    '$',
    '_',
    '|',
    'B',
    'E',
    'W',
    'T',
    'U',
    'K',
    'R',
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
    wipe_disk()
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
    wipe_disk()
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

-- ── macro opportunity detection (#60) ────────────────────────────────────────
-- End-to-end regression pass for the reactive detector added in patterns.lua
-- (M.feed_macro) and wired into both the normal- and insert-mode branches of
-- handle_key() here in logger.lua. patterns_spec.lua already covers the pure
-- detection logic directly; these tests confirm the real keystroke path
-- (vim.on_key -> handle_key -> patterns.feed_macro) actually reaches it,
-- through real Neovim edits rather than direct patterns.feed_macro() calls.
describe('macro opportunity detection (#60)', function()
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

  local function feed_and_collect(keys)
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    vim.fn.feedkeys(keys, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    return fired
  end

  it('fires macro_opportunity suggesting @q when cwFooBar<Esc> is repeated 3x with j navigation between', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaaaaa', 'aaaaaa', 'aaaaaa' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local rep = 'cwFooBar' .. esc
    local fired = feed_and_collect(rep .. 'j' .. rep .. 'j' .. rep)
    local macro_fired = nil
    for _, f in ipairs(fired) do
      if f.pattern == 'macro_opportunity' then
        macro_fired = f
      end
    end
    assert.is_not_nil(macro_fired, 'expected macro_opportunity to fire')
    assert.equals('@q', macro_fired.cmd)
  end)

  it('does not fire macro_opportunity when the same edit sequence happens only twice', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaaaaa', 'aaaaaa', 'aaaaaa' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local rep = 'cwFooBar' .. esc
    local fired = feed_and_collect(rep .. 'j' .. rep)
    for _, f in ipairs(fired) do
      assert.are_not.equal('macro_opportunity', f.pattern)
    end
  end)

  it('does not fire macro_opportunity when the repeated sequence itself types the letter q', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaaaaa', 'aaaaaa', 'aaaaaa' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local rep = 'cwq' .. esc
    local fired = feed_and_collect(rep .. 'j' .. rep .. 'j' .. rep)
    for _, f in ipairs(fired) do
      assert.are_not.equal('macro_opportunity', f.pattern)
    end
  end)

  it('fires macro_opportunity for a repeated edit sequence entirely within Normal mode', function()
    -- x / X never enter insert mode — this exercises the branch of
    -- handle_key() where macro_result is the ONLY candidate pattern for the
    -- keystroke (patterns.feed()'s own `result` and feed_after_escape's
    -- `co_result` are both nil), as opposed to the cw-based tests above
    -- which fire from inside handle_insert_key().
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaaaaaaaaaaa', 'aaaaaaaaaaaa', 'aaaaaaaaaaaa' })
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    local rep = 'xXx'
    local fired = feed_and_collect(rep .. 'j' .. rep .. 'j' .. rep)
    local macro_fired = nil
    for _, f in ipairs(fired) do
      if f.pattern == 'macro_opportunity' then
        macro_fired = f
      end
    end
    assert.is_not_nil(macro_fired, 'expected macro_opportunity to fire')
    assert.equals('@q', macro_fired.cmd)
  end)

  it(
    'does not fire macro_opportunity for 12x bare j, and fires j_repeat instead (#60 follow-up bug: '
      .. 'holding j to scroll used to steal priority from j_repeat)',
    function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaaaaa', 'aaaaaa', 'aaaaaa', 'aaaaaa', 'aaaaaa', 'aaaaaa' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local fired = feed_and_collect(string.rep('j', 12))
      local j_repeat_fired = false
      for _, f in ipairs(fired) do
        assert.are_not.equal('macro_opportunity', f.pattern)
        if f.pattern == 'j_repeat' then
          j_repeat_fired = true
        end
      end
      assert.is_true(j_repeat_fired, 'expected j_repeat to fire')
    end
  )

  it(
    'does not fire macro_opportunity for 0fh repeated 4x, and fires f_repeat instead (#60 follow-up bug: '
      .. 'multi-key navigation repeated back-to-back used to steal priority from f_repeat)',
    function()
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hhhhhh', 'hhhhhh', 'hhhhhh', 'hhhhhh' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local fired = feed_and_collect(string.rep('0fh', 4))
      local f_repeat_fired = false
      for _, f in ipairs(fired) do
        assert.are_not.equal('macro_opportunity', f.pattern)
        if f.pattern == 'f_repeat' then
          f_repeat_fired = true
        end
      end
      assert.is_true(f_repeat_fired, 'expected f_repeat to fire')
    end
  )

  it('is suppressed while the user is recording a macro (reg_recording() ~= "")', function()
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaaaaa', 'aaaaaa', 'aaaaaa' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local fired = {}
    logger.on_pattern = function(pattern, cmd)
      table.insert(fired, { pattern = pattern, cmd = cmd })
    end
    local rep = 'cwFooBar' .. esc

    vim.fn.feedkeys('qa', 'xt') -- start recording into register a
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys(rep .. 'j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys(rep .. 'j', 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys(rep, 'xt')
    vim.api.nvim_feedkeys('', 'x', false)
    vim.fn.feedkeys('q', 'xt') -- stop recording
    vim.api.nvim_feedkeys('', 'x', false)

    for _, f in ipairs(fired) do
      assert.are_not.equal('macro_opportunity', f.pattern)
    end
  end)
end)
