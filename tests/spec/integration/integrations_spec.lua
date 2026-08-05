-- core/integrations.lua (#63): detects the user's actual keymap overrides
-- (phase 1) and installed helper plugins (phase 2), so graph.find_best() and
-- ui/guide.lua never present a remapped key as if it still did what
-- commands.lua says, and so config.integrations-gated promotions can boost a
-- suggestion when a relevant plugin is present. See lua/tobira/CLAUDE.md for
-- why this lives in its own file rather than inside graph.lua.

local integrations = require('tobira.core.integrations')
local config = require('tobira.core.config')

local function fake_keymap(entries)
  return function(_mode)
    return entries
  end
end

describe('M.refresh — keymap override detection (phase 1)', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)

  it('records an override for a suggestable command that has been remapped', function()
    integrations.refresh(fake_keymap({ { lhs = 'Y', rhs = 'y$', noremap = 1 } }))
    local override = integrations.get_override('Y')
    assert.is_not_nil(override)
    assert.equals('y$', override.rhs)
  end)

  it('marks a remap matching the curated equivalents table as equivalent', function()
    integrations.refresh(fake_keymap({ { lhs = 'Y', rhs = 'y$', noremap = 1 } }))
    assert.is_true(integrations.is_equivalent_override('Y'))
  end)

  it('marks a plugin-driven <Plug> remap as not equivalent', function()
    integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(some-plugin-thing)', noremap = 0 } }))
    assert.is_true(integrations.is_overridden('s'))
    assert.is_false(integrations.is_equivalent_override('s'))
  end)

  it('records a callback-based mapping using a placeholder rhs', function()
    integrations.refresh(fake_keymap({ { lhs = 's', callback = function() end, noremap = 1 } }))
    local override = integrations.get_override('s')
    assert.is_not_nil(override)
    assert.equals('<lua function>', override.rhs)
  end)

  it('records a mapping with neither an rhs string nor a callback using an empty rhs', function()
    integrations.refresh(fake_keymap({ { lhs = 's', rhs = '', noremap = 1 } }))
    local override = integrations.get_override('s')
    assert.is_not_nil(override)
    assert.equals('', override.rhs)
  end)

  it('marks a remap to something outside the curated equivalents list as not equivalent', function()
    -- 'Y' is in EQUIVALENT_REMAPS but only for rhs == 'y$' -- a remap to
    -- anything else (even something Y-shaped like plain 'yy') must still
    -- fall through to "not equivalent", not silently match.
    integrations.refresh(fake_keymap({ { lhs = 'Y', rhs = 'yy', noremap = 1 } }))
    assert.is_true(integrations.is_overridden('Y'))
    assert.is_false(integrations.is_equivalent_override('Y'))
  end)

  it(
    "marks Neovim's bundled matchit.vim remap of % (<Plug>(MatchitNormalForward)) as equivalent",
    function()
      -- Neovim auto-loads runtime/plugin/matchit.vim by default (packadd
      -- matchit), which does `nmap <silent> % <Plug>(MatchitNormalForward)`.
      -- This is a strict, compatible superset of the built-in % for the
      -- basic bracket-jump behavior tobira teaches, so it must not suppress
      -- the % suggestion the way a genuinely different remap would.
      integrations.refresh(fake_keymap({ { lhs = '%', rhs = '<Plug>(MatchitNormalForward)', noremap = 0 } }))
      assert.is_true(integrations.is_overridden('%'))
      assert.is_true(integrations.is_equivalent_override('%'))
    end
  )

  it('marks a % remap to something outside the curated equivalents list as not equivalent', function()
    -- A genuinely different % remap (not matchit's) must still suppress the
    -- suggestion -- this is not a blanket "any % override is fine" rule.
    integrations.refresh(fake_keymap({ { lhs = '%', rhs = '<Plug>(SomeOtherPluginJump)', noremap = 0 } }))
    assert.is_true(integrations.is_overridden('%'))
    assert.is_false(integrations.is_equivalent_override('%'))
  end)

  it('ignores mappings for keys that are not suggestable commands in commands.lua', function()
    integrations.refresh(fake_keymap({ { lhs = 'Q', rhs = 'gqip', noremap = 1 } }))
    assert.is_false(integrations.is_overridden('Q'))
  end)

  it('ignores mappings whose lhs matches a compound-only registry entry (dw, dd)', function()
    integrations.refresh(fake_keymap({ { lhs = 'dw', rhs = 'diw', noremap = 1 } }))
    assert.is_false(integrations.is_overridden('dw'))
  end)

  it('is_overridden is false for a key that has never been remapped', function()
    integrations.refresh(fake_keymap({}))
    assert.is_false(integrations.is_overridden('j'))
  end)

  it('clears an override once the mapping disappears on a later refresh', function()
    integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(x)', noremap = 0 } }))
    assert.is_true(integrations.is_overridden('s'))
    integrations.refresh(fake_keymap({}))
    assert.is_false(integrations.is_overridden('s'))
  end)

  it('get_overrides returns the full current cache as a table', function()
    integrations.refresh(fake_keymap({ { lhs = 'Y', rhs = 'y$', noremap = 1 } }))
    local overrides = integrations.get_overrides()
    assert.is_not_nil(overrides['Y'])
  end)
end)

describe('M.refresh — debug logging (#63 AC: "s is removed from the suggestion pool with a debug log line")', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)

  local function with_notify_spy(fn)
    local calls = {}
    local orig = vim.notify
    vim.notify = function(msg, level)
      table.insert(calls, { msg = msg, level = level })
    end
    local ok, err = pcall(fn)
    vim.notify = orig
    assert.is_true(ok, err)
    return calls
  end

  it('logs a DEBUG-level notification the first time an override is detected', function()
    local calls = with_notify_spy(function()
      integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(some-plugin-thing)', noremap = 0 } }))
    end)
    assert.equals(1, #calls)
    assert.equals(vim.log.levels.DEBUG, calls[1].level)
    assert.is_not_nil(calls[1].msg:find('s', 1, true))
  end)

  it('does not re-log an override that is still present on a later refresh', function()
    integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(x)', noremap = 0 } }))
    local calls = with_notify_spy(function()
      integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(x)', noremap = 0 } }))
    end)
    assert.equals(0, #calls)
  end)

  it('logs again if the override disappears and then reappears', function()
    integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(x)', noremap = 0 } }))
    integrations.refresh(fake_keymap({}))
    local calls = with_notify_spy(function()
      integrations.refresh(fake_keymap({ { lhs = 's', rhs = '<Plug>(x)', noremap = 0 } }))
    end)
    assert.equals(1, #calls)
  end)
end)

describe('M.has_plugin — plugin presence detection (phase 2)', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)

  local function with_runtime_stub(paths_present, fn)
    local orig = vim.api.nvim_get_runtime_file
    vim.api.nvim_get_runtime_file = function(path, _all)
      for _, p in ipairs(paths_present) do
        if path == p then
          return { '/fake/' .. path }
        end
      end
      return {}
    end
    local ok, err = pcall(fn)
    vim.api.nvim_get_runtime_file = orig
    assert.is_true(ok, err)
  end

  it('detects a plugin present as a flat lua/<name>.lua runtime file', function()
    with_runtime_stub({ 'lua/mini/surround.lua' }, function()
      integrations.refresh(fake_keymap({}))
      assert.is_true(integrations.has_plugin('surround'))
    end)
  end)

  it('detects a plugin present as a lua/<name>/init.lua runtime file', function()
    with_runtime_stub({ 'lua/hop/init.lua' }, function()
      integrations.refresh(fake_keymap({}))
      assert.is_true(integrations.has_plugin('hop'))
    end)
  end)

  it('never calls require() on the detected plugin module (no forced lazy-load)', function()
    with_runtime_stub({ 'lua/hop/init.lua' }, function()
      integrations.refresh(fake_keymap({}))
      integrations.has_plugin('hop')
      assert.is_nil(package.loaded['hop'])
    end)
  end)

  it('returns false for a plugin whose runtime files are absent', function()
    with_runtime_stub({}, function()
      integrations.refresh(fake_keymap({}))
      assert.is_false(integrations.has_plugin('hop'))
    end)
  end)

  it('is true if any module tagged with the same integration is present (surround: nvim-surround OR mini.surround)', function()
    with_runtime_stub({ 'lua/nvim-surround.lua' }, function()
      integrations.refresh(fake_keymap({}))
      assert.is_true(integrations.has_plugin('surround'))
    end)
  end)
end)

describe('M.get_promotions — gated integration promotions (phase 2)', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)

  local function with_runtime_stub(paths_present, fn)
    local orig = vim.api.nvim_get_runtime_file
    vim.api.nvim_get_runtime_file = function(path, _all)
      for _, p in ipairs(paths_present) do
        if path == p then
          return { '/fake/' .. path }
        end
      end
      return {}
    end
    local ok, err = pcall(fn)
    vim.api.nvim_get_runtime_file = orig
    assert.is_true(ok, err)
  end

  it('promotes ci" when surround is detected and dw usage crosses the threshold', function()
    with_runtime_stub({ 'lua/nvim-surround.lua' }, function()
      integrations.refresh(fake_keymap({}))
      local usage = { dw = { count = 50 } }
      local promotions = integrations.get_promotions(usage)
      assert.is_true(promotions['ci"'])
    end)
  end)

  it('does not promote when usage is below the threshold', function()
    with_runtime_stub({ 'lua/nvim-surround.lua' }, function()
      integrations.refresh(fake_keymap({}))
      local usage = { dw = { count = 5 } }
      local promotions = integrations.get_promotions(usage)
      assert.is_nil(promotions['ci"'])
    end)
  end)

  it('does not promote when the plugin is not detected', function()
    with_runtime_stub({}, function()
      integrations.refresh(fake_keymap({}))
      local usage = { dw = { count = 50 } }
      local promotions = integrations.get_promotions(usage)
      assert.is_nil(promotions['ci"'])
    end)
  end)

  it('returns an empty table when config.integrations is disabled, even with a qualifying plugin and usage', function()
    with_runtime_stub({ 'lua/nvim-surround.lua' }, function()
      integrations.refresh(fake_keymap({}))
      config.setup({ integrations = false })
      local usage = { dw = { count = 50 } }
      local promotions = integrations.get_promotions(usage)
      assert.equals(0, vim.tbl_count(promotions))
    end)
  end)

  it('promotes ; when flash is detected and f usage crosses the threshold', function()
    with_runtime_stub({ 'lua/flash/init.lua' }, function()
      integrations.refresh(fake_keymap({}))
      local usage = { f = { count = 50 } }
      local promotions = integrations.get_promotions(usage)
      assert.is_true(promotions[';'])
    end)
  end)
end)

describe('M.setup / M.reset', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)
  after_each(function()
    integrations.reset()
  end)

  it('populates the override cache immediately', function()
    integrations.setup()
    assert.is_table(integrations.get_overrides())
  end)

  it('registers an augroup that refreshes on VimEnter and SourcePost', function()
    integrations.setup()
    local autocmds = vim.api.nvim_get_autocmds({ group = 'tobira_integrations' })
    local events = {}
    for _, ac in ipairs(autocmds) do
      events[ac.event] = true
    end
    assert.is_true(events['VimEnter'])
    assert.is_true(events['SourcePost'])
  end)

  it('is idempotent — calling setup twice does not error or double-register', function()
    integrations.setup()
    assert.has_no_error(function()
      integrations.setup()
    end)
  end)

  it('reset clears the cache and allows setup to run again', function()
    integrations.setup()
    integrations.reset()
    assert.is_false(integrations.is_overridden('Y'))
    assert.has_no_error(function()
      integrations.setup()
    end)
  end)

  it('actually refreshes the cache when the VimEnter/SourcePost autocmd fires', function()
    integrations.setup()
    integrations.reset() -- setup() already ran refresh() once; clear it so the assertion below can only pass via the autocmd firing
    local orig = vim.api.nvim_get_keymap
    vim.api.nvim_get_keymap = function(_mode)
      return { { lhs = 'Y', rhs = 'y$', noremap = 1 } }
    end
    local ok, err = pcall(function()
      vim.api.nvim_exec_autocmds('VimEnter', { modeline = false })
    end)
    vim.api.nvim_get_keymap = orig
    assert.is_true(ok, err)
    assert.is_true(integrations.is_overridden('Y'))
  end)
end)
