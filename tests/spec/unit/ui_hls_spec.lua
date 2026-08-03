local hls = require('tobira.ui.hls')

-- Helper: run fn() with mocked hlexists + notify, restore unconditionally.
local function with_notify_present(fn)
  local orig_hlexists = vim.fn.hlexists
  vim.fn.hlexists = function(name)
    if name == 'TobiraGuideBorder' then
      return 0
    end
    if name == 'NotifyINFOBorder' then
      return 1
    end
    return orig_hlexists(name)
  end
  package.loaded['notify'] = {}
  local ok, err = pcall(fn)
  vim.fn.hlexists = orig_hlexists
  package.loaded['notify'] = nil
  assert.is_true(ok, err)
end

describe('when nvim-notify highlight groups are available', function()
  it('links TobiraGuideBorder to NotifyINFOBorder', function()
    with_notify_present(function()
      hls.setup()
    end)
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraGuideBorder', link = true })
    assert.equals('NotifyINFOBorder', hl.link)
  end)
end)

describe('category highlight groups', function()
  local expected = {
    TobiraSuggestMotion = 'Special',
    TobiraSuggestEdit = 'Function',
    TobiraSuggestSearch = 'String',
    TobiraSuggestWindow = 'Type',
    TobiraSuggestFold = 'Constant',
    TobiraSuggestMark = 'Identifier',
    TobiraSuggestMacro = 'PreProc',
    -- #57: Ex commands (:g, :norm, ...) are statement-like — the nearest
    -- syntax-group analog to a colon command, matching the "what kind of
    -- thing is this" intuition the other 7 categories already follow.
    TobiraSuggestEx = 'Statement',
  }

  it('defines a distinct group linked to a standard syntax group for every category', function()
    hls.setup()
    for group, target in pairs(expected) do
      local hl = vim.api.nvim_get_hl(0, { name = group, link = true })
      assert.equals(target, hl.link, group .. ' should link to ' .. target)
    end
  end)
end)

describe('TobiraSuggestKey and TobiraCelebrate highlight groups', function()
  it('defines TobiraSuggestKey', function()
    hls.setup()
    assert.equals(1, vim.fn.hlexists('TobiraSuggestKey'))
  end)

  it('defines TobiraCelebrate linked to DiagnosticOk', function()
    hls.setup()
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraCelebrate', link = true })
    assert.equals('DiagnosticOk', hl.link)
  end)
end)

describe('TobiraDim and TobiraH1 highlight groups', function()
  it('links TobiraDim to Comment', function()
    hls.setup()
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraDim', link = true })
    assert.equals('Comment', hl.link)
  end)

  it('links TobiraH1 to Title', function()
    hls.setup()
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraH1', link = true })
    assert.equals('Title', hl.link)
  end)
end)

describe('TobiraGuideForgotten highlight group', function()
  it('links to DiagnosticHint, not DiagnosticWarn (already owned by TobiraGuideLearning)', function()
    hls.setup()
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraGuideForgotten', link = true })
    assert.equals('DiagnosticHint', hl.link)
  end)
end)

-- #126: setup() used to return early whenever TobiraGuideBorder already existed, so
-- has_notify_hl was only ever computed on the very first call across the whole session.
-- In a lazy-loaded setup where nvim-notify hasn't loaded yet when tobira's first panel
-- opens, this permanently locked TobiraGuideBorder/Normal/Section onto the
-- FloatBorder/NormalFloat/Title fallback -- even after nvim-notify loaded moments later
-- and a different panel opened. setup() must re-evaluate has_notify_hl on every call.
describe('re-evaluating nvim-notify availability on every hls.setup() call (#126)', function()
  -- hlexists() never reports a group as "gone" again once it has been set for real in
  -- this Neovim instance, so the only way to simulate "this is the very first hls.setup()
  -- call in a fresh session" is to stub hlexists for TobiraGuideBorder specifically,
  -- the same technique the file's other describe block above already uses for
  -- NotifyINFOBorder. Every other hlexists() lookup passes through to the real function.
  local function first_ever_call(fn)
    local orig_hlexists = vim.fn.hlexists
    vim.fn.hlexists = function(name)
      if name == 'TobiraGuideBorder' then
        return 0
      end
      return orig_hlexists(name)
    end
    local ok, err = pcall(fn)
    vim.fn.hlexists = orig_hlexists
    assert.is_true(ok, err)
  end

  local function notify_unavailable(fn)
    local orig_preload = package.preload['notify']
    local orig_loaded = package.loaded['notify']
    package.preload['notify'] = nil
    package.loaded['notify'] = nil
    local ok, err = pcall(fn)
    package.preload['notify'] = orig_preload
    package.loaded['notify'] = orig_loaded
    assert.is_true(ok, err)
  end

  local function notify_available(fn)
    local orig_loaded = package.loaded['notify']
    package.loaded['notify'] = {}
    -- Mirrors what nvim-notify's own setup() defines.
    vim.api.nvim_set_hl(0, 'NotifyINFOBorder', { link = 'FloatBorder' })
    local ok, err = pcall(fn)
    package.loaded['notify'] = orig_loaded
    assert.is_true(ok, err)
  end

  local function guide_border_link()
    return vim.api.nvim_get_hl(0, { name = 'TobiraGuideBorder', link = true }).link
  end

  it('links TobiraGuideBorder to FloatBorder on the first call when nvim-notify is unavailable', function()
    first_ever_call(function()
      notify_unavailable(function()
        hls.setup()
      end)
    end)
    assert.equals('FloatBorder', guide_border_link())
  end)

  it('upgrades TobiraGuideBorder to NotifyINFOBorder once nvim-notify becomes available mid-session', function()
    -- This is the exact staleness scenario from #126: nvim-notify was not yet
    -- lazy-loaded on the call above, so TobiraGuideBorder locked onto FloatBorder.
    -- It has now finished loading and a later panel opens, calling setup() again --
    -- this must pick up NotifyINFOBorder rather than staying stuck.
    notify_available(function()
      hls.setup()
    end)
    assert.equals('NotifyINFOBorder', guide_border_link())
  end)

  it('reverts TobiraGuideBorder to FloatBorder if nvim-notify becomes unavailable again', function()
    -- Less realistic (plugins don't normally unload mid-session) but confirms setup()
    -- performs a clean re-evaluation on every call rather than a one-way upgrade latch.
    notify_unavailable(function()
      hls.setup()
    end)
    assert.equals('FloatBorder', guide_border_link())
  end)
end)
