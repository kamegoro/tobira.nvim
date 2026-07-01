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
    vim.fn.feedkeys('i', 'xt')
    vim.fn.feedkeys('dw', 'xt')
    vim.fn.feedkeys(esc, 'xt')
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
