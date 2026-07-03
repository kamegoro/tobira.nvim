-- :checkhealth tobira (#42).
-- vim.health (Neovim >= 0.10) is mocked per-test so we can assert exactly
-- which of start/ok/warn/error fired, without a real :checkhealth buffer.

local logger = require('tobira.core.logger')
local config = require('tobira.core.config')

-- Installs a fake vim.health, runs fn(), restores the real one even on error.
-- Returns a table of captured calls: { start = {...}, ok = {...}, warn = {...}, error = {...} }.
local function with_health_mock(fn)
  local calls = { start = {}, ok = {}, warn = {}, error = {} }
  local orig = vim.health
  vim.health = {
    start = function(msg)
      table.insert(calls.start, msg)
    end,
    ok = function(msg)
      table.insert(calls.ok, msg)
    end,
    warn = function(msg)
      table.insert(calls.warn, msg)
    end,
    error = function(msg)
      table.insert(calls.error, msg)
    end,
  }
  local ok, err = pcall(fn)
  vim.health = orig
  assert.is_true(ok, err)
  return calls
end

-- Installs a fake vim.fn.has that overrides only the given feature-string
-- responses (everything else falls through to the real vim.fn.has).
local function with_has_mock(overrides, fn)
  local orig = vim.fn.has
  vim.fn.has = function(feature)
    if overrides[feature] ~= nil then
      return overrides[feature]
    end
    return orig(feature)
  end
  local ok, err = pcall(fn)
  vim.fn.has = orig
  assert.is_true(ok, err)
end

local function fresh_health()
  package.loaded['tobira.health'] = nil
  return require('tobira.health')
end

describe('when Neovim is >= 0.10', function()
  it('reports ok with a full-accuracy message', function()
    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    assert.equals(1, #calls.start)
    assert.equals('tobira.nvim', calls.start[1])
    local found = false
    for _, msg in ipairs(calls.ok) do
      if msg:find('Neovim', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an ok() call mentioning Neovim version')
    assert.equals(0, #calls.error, 'no version-related error expected on a modern Neovim')
  end)
end)

describe('when Neovim is >= 0.9 but < 0.10', function()
  it('reports a warning about reduced pattern-detection accuracy, not an error', function()
    local health = fresh_health()
    local calls
    with_has_mock({ ['nvim-0.9'] = 1, ['nvim-0.10'] = 0 }, function()
      calls = with_health_mock(function()
        health.check()
      end)
    end)
    local found = false
    for _, msg in ipairs(calls.warn) do
      if msg:find('0.10', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected a warn() call mentioning the 0.10 typed-argument gap')
  end)
end)

describe('when Neovim is below the minimum supported version', function()
  it('reports an error', function()
    local health = fresh_health()
    local calls
    with_has_mock({ ['nvim-0.9'] = 0, ['nvim-0.10'] = 0 }, function()
      calls = with_health_mock(function()
        health.check()
      end)
    end)
    assert.is_true(#calls.error > 0, 'expected at least one error() call for an unsupported Neovim version')
  end)
end)

describe('the data directory check', function()
  it('reports ok when the directory already exists and is writable', function()
    vim.fn.mkdir(logger.data_dir(), 'p')
    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    local found = false
    for _, msg in ipairs(calls.ok) do
      if msg:find(logger.data_dir(), 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an ok() call mentioning the data directory')
    assert.equals(0, #calls.error)
  end)

  it('reports an error when the directory exists but is read-only', function()
    vim.fn.mkdir(logger.data_dir(), 'p')
    vim.loop.fs_chmod(logger.data_dir(), tonumber('500', 8))

    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)

    vim.loop.fs_chmod(logger.data_dir(), tonumber('700', 8))

    local found = false
    for _, msg in ipairs(calls.error) do
      if msg:find(logger.data_dir(), 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an error() call about the read-only data directory')
  end)

  it('reports an error when the directory does not exist and its parent is read-only', function()
    vim.fn.delete(logger.data_dir(), 'rf')
    local parent = vim.fn.fnamemodify(logger.data_dir(), ':h')
    vim.loop.fs_chmod(parent, tonumber('500', 8))

    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)

    vim.loop.fs_chmod(parent, tonumber('700', 8))

    local found = false
    for _, msg in ipairs(calls.error) do
      if msg:find(parent, 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an error() call about the unwritable parent directory')
  end)
end)

describe('the usage.json check', function()
  before_each(function()
    pcall(os.remove, logger.data_file())
  end)

  it('reports ok when usage.json does not exist yet', function()
    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    local found = false
    for _, msg in ipairs(calls.ok) do
      if msg:find('usage.json', 1, true) and msg:find('fresh', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an ok() call noting usage.json does not exist yet')
  end)

  it('reports ok when usage.json contains valid JSON', function()
    vim.fn.mkdir(logger.data_dir(), 'p')
    local f = io.open(logger.data_file(), 'w')
    f:write('{"cw":{"count":1}}')
    f:close()

    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    local found = false
    for _, msg in ipairs(calls.ok) do
      if msg:find('usage.json', 1, true) and msg:find('valid', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an ok() call confirming usage.json is valid JSON')
  end)

  it('reports an error when usage.json contains invalid JSON', function()
    vim.fn.mkdir(logger.data_dir(), 'p')
    local f = io.open(logger.data_file(), 'w')
    f:write('{not valid json')
    f:close()

    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    local found = false
    for _, msg in ipairs(calls.error) do
      if msg:find('usage.json', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an error() call about invalid usage.json')
  end)

  after_each(function()
    pcall(os.remove, logger.data_file())
  end)
end)

describe('the lang config check', function()
  after_each(function()
    config.reset()
  end)

  it('reports ok when lang is a supported locale', function()
    config.setup({ lang = 'en' })
    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    local found = false
    for _, msg in ipairs(calls.ok) do
      if msg:find('lang', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected an ok() call confirming lang is supported')
  end)

  it('reports a warning when lang has no matching locale file', function()
    config.setup({ lang = 'xx_not_a_real_locale' })
    local health = fresh_health()
    local calls = with_health_mock(function()
      health.check()
    end)
    local found = false
    for _, msg in ipairs(calls.warn) do
      if msg:find('xx_not_a_real_locale', 1, true) then
        found = true
      end
    end
    assert.is_true(found, 'expected a warn() call about the unsupported lang value')
  end)
end)

-- M.resolve_api adapts either the modern (Neovim >= 0.10) vim.health shape or
-- the legacy require('health').report_* shape to a common interface. Tested
-- directly with plain constructed tables rather than by trying to force
-- vim.health to nil — `vim` resolves unknown fields through a metatable that
-- keeps re-populating it, so that approach doesn't reliably simulate < 0.10.
describe('resolve_api with the modern vim.health >= 0.10 shape', function()
  it('uses start/ok/warn/error directly', function()
    local health = fresh_health()
    local modern = {
      start = function() end,
      ok = function() end,
      warn = function() end,
      error = function() end,
    }
    local api = health.resolve_api(modern)
    assert.equals(modern.start, api.start)
    assert.equals(modern.ok, api.ok)
    assert.equals(modern.warn, api.warn)
    assert.equals(modern.error, api.error)
  end)
end)

describe('resolve_api with the legacy require("health") < 0.10 shape', function()
  it('falls back to the report_* names', function()
    local health = fresh_health()
    local legacy = {
      report_start = function() end,
      report_ok = function() end,
      report_warn = function() end,
      report_error = function() end,
    }
    local api = health.resolve_api(legacy)
    assert.equals(legacy.report_start, api.start)
    assert.equals(legacy.report_ok, api.ok)
    assert.equals(legacy.report_warn, api.warn)
    assert.equals(legacy.report_error, api.error)
  end)

  it('is actually callable end-to-end through the resolved names', function()
    local health = fresh_health()
    local called = {}
    local legacy = {
      report_start = function(msg)
        called.start = msg
      end,
      report_ok = function(msg)
        called.ok = msg
      end,
      report_warn = function() end,
      report_error = function() end,
    }
    local api = health.resolve_api(legacy)
    api.start('tobira.nvim')
    api.ok('all good')
    assert.equals('tobira.nvim', called.start)
    assert.equals('all good', called.ok)
  end)
end)
