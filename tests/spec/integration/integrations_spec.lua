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

-- Like fake_keymap, but mode-sensitive: entries differ between normal and
-- insert mode, the way a real nvim_get_keymap('n') vs nvim_get_keymap('i')
-- query would. by_mode = { n = {...}, i = {...} }; either key may be omitted
-- (defaults to no mappings for that mode). Needed for #256 tests, which must
-- distinguish "this mapping exists in normal mode" from "this mapping exists
-- in insert mode" -- exactly the distinction the bug collapsed.
local function fake_keymap_by_mode(by_mode)
  return function(mode)
    return by_mode[mode] or {}
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

-- #255: nvim_get_keymap('n') returns Neovim's own factory-shipped default
-- mappings (gx, &, ]q/[q/]l/[l, and -- on Neovim 0.10+ -- Y=y$ too) the same
-- way it returns a real user nnoremap. Neovim registers every one of these
-- directly via the Lua/C API with no attached sourced script, which the
-- keymap dict surfaces as sid == -8 (empirically verified against a vanilla
-- `nvim -u NONE`; see docs/adr/0102-builtin-default-mapping-sid-detection.md).
-- ANY mapping sourced from a real script -- the user's own init.lua, a
-- lazy-loaded plugin, or even a shipped runtime plugin like matchit.vim --
-- gets a normal positive sid instead, so this field reliably tells "still
-- exactly what Neovim ships out of the box" apart from "something has
-- touched this key", independent of whether the current rhs is a literal
-- string or a Lua callback.
describe('M.refresh — Neovim built-in default mappings are not user overrides (#255)', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)

  -- Real desc text, empirically verified against a vanilla `nvim -u NONE` on
  -- Neovim 0.10.4 / 0.12.4 / nightly (0.13.0-dev) -- see the QA note above
  -- BUILTIN_DEFAULT_DESC in integrations.lua for why the fixture needs this
  -- field at all now (sid alone is not sufficient -- see below).
  local BUILTIN_DESC = {
    gx = 'Opens filepath or URI under cursor with the system handler (file explorer, web browser, …)',
    ['&'] = ':help &-default',
    [']q'] = ':cnext',
    ['[q'] = ':cprevious',
    [']l'] = ':lnext',
    ['[l'] = ':lprevious',
    Y = ':help Y-default',
  }

  it('does not treat an untouched Neovim built-in default mapping as an override', function()
    -- gx / & / ]q / [q / ]l / [l are all real Neovim 0.10+ default mappings
    -- (:help gx, :help ]q, etc.) registered with the internal sid sentinel
    -- AND Neovim's own descriptive `desc` text -- both must be present for
    -- the exemption (see "does not treat a deferred user override that
    -- happens to land on sid==-8" below for why sid alone is not enough).
    for _, lhs in ipairs({ 'gx', '&', ']q', '[q', ']l', '[l' }) do
      integrations.reset()
      integrations.refresh(
        fake_keymap({ { lhs = lhs, rhs = '', callback = function() end, sid = -8, desc = BUILTIN_DESC[lhs], noremap = 1 } })
      )
      assert.is_false(integrations.is_overridden(lhs), lhs .. ' should not be overridden (untouched built-in default)')
    end
  end)

  it("does not treat Neovim's own default Y=y$ mapping (sid=-8) as an override", function()
    -- Distinct from the existing "records an override for Y=y$" test above:
    -- that test has no sid field (simulating a genuine user nnoremap Y y$),
    -- this one has sid=-8 (simulating Neovim's own untouched 0.10+ default).
    -- Before this fix both cases were indistinguishable and Y could never be
    -- proactively suggested on any modern Neovim, for any user.
    integrations.refresh(fake_keymap({ { lhs = 'Y', rhs = 'y$', sid = -8, desc = BUILTIN_DESC.Y, noremap = 1 } }))
    assert.is_false(integrations.is_overridden('Y'))
  end)

  it('still treats a genuine user override of a default-mapped key as overridden (control case)', function()
    -- A user's own script gets a real, positive sid -- this must still be
    -- detected as a genuine override, not swallowed by the new exemption.
    integrations.refresh(fake_keymap({ { lhs = 'gx', rhs = ':MyCustomGx<CR>', sid = 5, noremap = 1 } }))
    assert.is_true(integrations.is_overridden('gx'))
  end)

  it(
    'still treats a deferred user/plugin override that happens to land on sid==-8 as overridden (regression, QA-found)',
    function()
      -- CRITICAL: sid==-8 is NOT unique to Neovim's own boot-time defaults.
      -- It is Neovim's generic sentinel for "this nvim_set_keymap/
      -- vim.keymap.set call had no active :source-ing script context at
      -- call time" -- and that is exactly what happens for any keymap set
      -- from inside a deferred callback: vim.schedule(), vim.defer_fn(), or
      -- a VimEnter/User-autocmd callback (independently reproduced live
      -- against real Neovim 0.12.4 stable and 0.13.0-dev nightly, and
      -- end-to-end through this module's own M.refresh()). This is exactly
      -- how lazy.nvim defers `event = "VeryLazy"`/event-based plugin
      -- config -- an extremely common pattern, not a contrived edge case --
      -- so a real plugin remapping e.g. gx this way previously vanished
      -- from find_best()/efficiency_gaps() entirely: is_overridden('gx')
      -- returned false for a key that WAS genuinely remapped. sid alone
      -- cannot tell these two cases apart; Neovim's own default additionally
      -- carries a distinctive `desc` string (verified stable across 0.10.4/
      -- 0.12.4/nightly) that a real override emphatically does not
      -- reproduce unless the rhs/opts explicitly set the exact same desc.
      integrations.refresh(fake_keymap({ { lhs = 'gx', rhs = '', callback = function() end, sid = -8, noremap = 1 } }))
      assert.is_true(
        integrations.is_overridden('gx'),
        'a deferred override landing on sid==-8 with no matching desc must still count as an override'
      )
    end
  )

  it("still treats Neovim's bundled matchit.vim remap of % (a real sourced script, not the internal sentinel) as overridden-but-equivalent", function()
    -- matchit.vim is auto-loaded via packadd and is a real sourced runtime
    -- script (positive sid), unlike the internal-sid default mappings this
    -- fix targets -- the existing EQUIVALENT_REMAPS handling for % must keep
    -- working unchanged.
    integrations.refresh(fake_keymap({ { lhs = '%', rhs = '<Plug>(MatchitNormalForward)', sid = 12, noremap = 0 } }))
    assert.is_true(integrations.is_overridden('%'))
    assert.is_true(integrations.is_equivalent_override('%'))
  end)

  it('falls back to treating a mapping as overridden when sid is unavailable (safe default)', function()
    integrations.refresh(fake_keymap({ { lhs = 'gx', rhs = '<lua function>', noremap = 1 } }))
    assert.is_true(integrations.is_overridden('gx'))
  end)
end)

-- #256: M.refresh() only ever queried keymap_fn('n'), never keymap_fn('i'),
-- so registry entries representing insert-mode behavior (<C-w>, <C-n>,
-- <C-t>, i_<C-o>, i_<C-d>) were checked against the wrong mode's keymaps --
-- both a false-positive (an unrelated normal-mode remap of the same raw key
-- wrongly suppressed the insert-mode suggestion) and a false-negative (a
-- real insert-mode override never suppressed anything) failure mode.
-- Separately, i_<C-o> / i_<C-d> could never be detected as overridden at
-- all: suggestible_keys()'s canonicalization only handled keys matching
-- '^<.->$', and 'i_<C-o>' doesn't start with '<'.
describe('M.refresh — insert-mode registry entries are checked against insert-mode keymaps (#256)', function()
  before_each(function()
    integrations.reset()
    config.reset()
  end)

  it('does NOT flag <C-n> as overridden when only an unrelated NORMAL-mode remap exists (false-positive fixed)', function()
    -- nnoremap <C-n> :bnext<CR> -- normal-mode, unrelated to insert-mode completion.
    integrations.refresh(fake_keymap_by_mode({ n = { { lhs = '<C-n>', rhs = ':bnext<CR>', noremap = 1 } } }))
    assert.is_false(integrations.is_overridden('<C-n>'))
  end)

  it('DOES flag <C-t> as overridden when a genuine INSERT-mode remap exists (false-negative fixed)', function()
    -- inoremap <C-t> <Nop> -- genuinely overrides what tobira teaches (indent without leaving insert).
    integrations.refresh(fake_keymap_by_mode({ i = { { lhs = '<C-t>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_true(integrations.is_overridden('<C-t>'))
  end)

  it('does NOT flag <C-w> as overridden when only an unrelated NORMAL-mode remap exists (false-positive fixed)', function()
    -- nnoremap <C-w> <Nop> -- normal-mode window-prefix remap, unrelated to insert-mode delete-word.
    integrations.refresh(fake_keymap_by_mode({ n = { { lhs = '<C-w>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_false(integrations.is_overridden('<C-w>'))
  end)

  it('DOES flag <C-w> as overridden when a genuine INSERT-mode remap exists', function()
    integrations.refresh(fake_keymap_by_mode({ i = { { lhs = '<C-w>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_true(integrations.is_overridden('<C-w>'))
  end)

  -- QA follow-up: <C-w>'s insert-mode meaning (delete word before cursor) is
  -- ALSO a genuine Neovim 0.10+ default (`:help i_CTRL-W-default`, rhs
  -- `<C-G>u<C-W>`, undo-breaking) that ships with sid == -8 out of the box --
  -- same #255 collision as gx/&/]q/[q/]l/[l/Y, just discovered for a #256
  -- key during independent audit rather than named in the original issue.
  -- Without this exemption, <C-w>'s own insert-mode suggestion would be
  -- permanently unsuggestable on any untouched Neovim install.
  it("does not treat the untouched insert-mode <C-w> default (Neovim's own i_CTRL-W-default) as an override", function()
    integrations.refresh(fake_keymap_by_mode({
      i = { { lhs = '<C-w>', rhs = '<C-G>u<C-W>', sid = -8, desc = ':help i_CTRL-W-default', noremap = 1 } },
    }))
    assert.is_false(integrations.is_overridden('<C-w>'))
  end)

  it('still treats a deferred INSERT-mode override of <C-w> that happens to land on sid==-8 as overridden', function()
    -- Same collision as the gx regression test above, for an insert-mode
    -- key: a real vim.schedule()/vim.defer_fn()-deferred remap gets
    -- sid == -8 too but does not reproduce Neovim's exact desc text.
    integrations.refresh(fake_keymap_by_mode({
      i = { { lhs = '<C-w>', rhs = '', callback = function() end, sid = -8, noremap = 1 } },
    }))
    assert.is_true(integrations.is_overridden('<C-w>'))
  end)

  it('detects an insert-mode override of the composite i_<C-o> entry (canonicalization fix)', function()
    -- Before the fix, suggestible_keys()'s canonical form for 'i_<C-o>' stayed
    -- the literal string 'i_<C-o>' (no leading '<'), which no real keytrans()
    -- output could ever match -- so this override could never be detected.
    integrations.refresh(fake_keymap_by_mode({ i = { { lhs = '<C-o>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_true(integrations.is_overridden('i_<C-o>'))
  end)

  it('does not confuse an insert-mode <C-o> override with the distinct normal-mode <C-o> entry', function()
    integrations.refresh(fake_keymap_by_mode({ i = { { lhs = '<C-o>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_false(integrations.is_overridden('<C-o>'))
  end)

  it('detects an insert-mode override of the composite i_<C-d> entry (canonicalization fix)', function()
    integrations.refresh(fake_keymap_by_mode({ i = { { lhs = '<C-d>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_true(integrations.is_overridden('i_<C-d>'))
  end)

  it('does not confuse an insert-mode <C-d> override with the distinct normal-mode <C-d> entry', function()
    integrations.refresh(fake_keymap_by_mode({ i = { { lhs = '<C-d>', rhs = '<Nop>', noremap = 1 } } }))
    assert.is_false(integrations.is_overridden('<C-d>'))
  end)

  it('non-regression: a genuine NORMAL-mode override of <C-d> is still detected (dual-meaning raw byte)', function()
    integrations.refresh(fake_keymap_by_mode({ n = { { lhs = '<C-d>', rhs = ':bd<CR>', noremap = 1 } } }))
    assert.is_true(integrations.is_overridden('<C-d>'))
    assert.is_false(integrations.is_overridden('i_<C-d>'))
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
