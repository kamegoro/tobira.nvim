-- Detects the user's real editor environment: keymap overrides (phase 1) and
-- installed helper plugins (phase 2). Exposes both as plain data for
-- graph.lua and the ui/ layer; graph.lua itself never requires this module
-- (see lua/tobira/CLAUDE.md's dependency rules and module-splitting policy).
--
-- Phase 1 is ungated; phase 2 is gated by config.values.integrations; plugin
-- presence never triggers require() -- see docs/adr/0051-integrations-phase-gating.md
-- and docs/adr/0053-plugin-presence-without-require.md for why.

local commands = require('tobira.commands')
local config = require('tobira.core.config')

local M = {}

-- cmd (commands.lua registry key) -> { rhs = string, equivalent = boolean }
local _overrides = {}
-- integration tag -> true (e.g. surround = true) once any of its known
-- modules is found on the runtimepath.
local _plugins = {}
-- cmd -> true once a debug notification has been emitted for its current
-- override (dedup across VimEnter/SourcePost refreshes).
-- see docs/adr/0055-refresh-cadence-and-notification-dedup.md for why
local _logged = {}

local _initialized = false

-- Curated LHS -> accepted-equivalent RHS literal(s).
-- Y accepts exactly rhs == 'y$' (a common personal remap; Vim's real built-in
-- Y is a synonym for yy, not y$).
-- % accepts exactly rhs == '<Plug>(MatchitNormalForward)' -- Neovim auto-loads
-- runtime/plugin/matchit.vim by default (packadd matchit), which does
-- `nmap <silent> % <Plug>(MatchitNormalForward)`. That target is a strict,
-- compatible superset of the built-in % for the basic bracket-jump behavior
-- tobira teaches, so it must not suppress the % suggestion the way a
-- genuinely different remap would.
-- Any other rhs for either LHS is "not equivalent".
-- see docs/adr/0052-equivalent-remap-distinction.md for why this table exists
local EQUIVALENT_REMAPS = {
  Y = { 'y$' },
  ['%'] = { '<Plug>(MatchitNormalForward)' },
}

-- module path -> integration tag. Presence-only check (see module_available
-- below) -- never actually require()s any of these.
local KNOWN_PLUGINS = {
  { module = 'hop', tag = 'hop' },
  { module = 'leap', tag = 'leap' },
  { module = 'flash', tag = 'flash' },
  { module = 'nvim-surround', tag = 'surround' },
  { module = 'mini.surround', tag = 'surround' },
  { module = 'Comment', tag = 'comment' },
  { module = 'mini.comment', tag = 'comment' },
}

-- Phase 2 promotion rules: plugin tag + an already-tracked trigger-count
-- threshold -> an existing graph.suggestions cmd to promote into find_best's
-- priority pool.
-- see docs/adr/0054-promotion-rules-reuse-existing-commands.md for why these
-- reuse existing commands.lua entries instead of new teachable commands
local PROMOTION_RULES = {
  { plugin = 'surround', trigger = 'dw', cmd = 'ci"', threshold = 30 },
  { plugin = 'flash', trigger = 'f', cmd = ';', threshold = 30 },
}

local function is_equivalent(cmd, rhs)
  local accepted = EQUIVALENT_REMAPS[cmd]
  if not accepted then
    return false
  end
  for _, ok_rhs in ipairs(accepted) do
    if rhs == ok_rhs then
      return true
    end
  end
  return false
end

-- rhs is '' for an ordinary (non-remapped) mapping's absence; a Lua
-- callback-based mapping has no rhs string at all, only a callback function.
local function rhs_of(map)
  if map.rhs and map.rhs ~= '' then
    return map.rhs
  end
  if map.callback then
    return '<lua function>'
  end
  return ''
end

-- canonical (keytrans-normalized) form -> original commands.lua registry key.
-- Mirrors suggest.lua's normalize_cmd: only <...>-notation keys need
-- normalizing (nvim_get_keymap's lhs already matches plain literal keys like
-- 'Y'/'s'/'ciw' byte-for-byte).
local function suggestible_keys()
  local set = {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound then
      local canon = cmd
      if cmd:match('^<.->$') then
        local bytes = vim.api.nvim_replace_termcodes(cmd, true, false, true)
        local kt = vim.fn.keytrans(bytes)
        if kt ~= '' then
          canon = kt
        end
      end
      set[canon] = cmd
    end
  end
  return set
end

local function canonical_lhs(lhs)
  local bytes = vim.api.nvim_replace_termcodes(lhs, true, false, true)
  return vim.fn.keytrans(bytes)
end

local function log_override(cmd, info)
  local str = require('tobira.i18n').load()
  vim.notify(
    string.format(str.notifications.remap_detected, cmd, info.rhs ~= '' and info.rhs or '<lua function>'),
    vim.log.levels.DEBUG
  )
end

-- module_available checks BOTH a flat `lua/<name>.lua` file and a
-- `lua/<name>/init.lua` directory-style module, since plugins ship either
-- shape (e.g. mini.nvim's submodules are flat files; hop.nvim ships
-- lua/hop/init.lua).
local function module_available(modname)
  local base = 'lua/' .. modname:gsub('%.', '/')
  return #vim.api.nvim_get_runtime_file(base .. '.lua', false) > 0
    or #vim.api.nvim_get_runtime_file(base .. '/init.lua', false) > 0
end

local function detect_plugins()
  local found = {}
  for _, p in ipairs(KNOWN_PLUGINS) do
    if module_available(p.module) then
      found[p.tag] = true
    end
  end
  return found
end

-- keymap_fn defaults to vim.api.nvim_get_keymap; overridable so tests can
-- inject a fake keymap list without touching real editor state.
function M.refresh(keymap_fn)
  keymap_fn = keymap_fn or vim.api.nvim_get_keymap
  local watched = suggestible_keys()

  local new_overrides = {}
  for _, map in ipairs(keymap_fn('n')) do
    local registry_key = watched[canonical_lhs(map.lhs)] or watched[map.lhs]
    if registry_key then
      local rhs = rhs_of(map)
      new_overrides[registry_key] = { rhs = rhs, equivalent = is_equivalent(registry_key, rhs) }
    end
  end

  for cmd, info in pairs(new_overrides) do
    if not _logged[cmd] then
      _logged[cmd] = true
      log_override(cmd, info)
    end
  end
  for cmd in pairs(_logged) do
    if not new_overrides[cmd] then
      _logged[cmd] = nil
    end
  end

  _overrides = new_overrides
  _plugins = detect_plugins()
end

function M.get_overrides()
  return _overrides
end

function M.get_override(cmd)
  return _overrides[cmd]
end

function M.is_overridden(cmd)
  return _overrides[cmd] ~= nil
end

function M.is_equivalent_override(cmd)
  local o = _overrides[cmd]
  return o ~= nil and o.equivalent == true
end

function M.has_plugin(tag)
  return _plugins[tag] == true
end

-- Returns cmd -> true for every suggestion that should bypass find_best's
-- ordinary trigger_count > 0 gate right now. Empty whenever
-- config.values.integrations is disabled.
function M.get_promotions(usage)
  local promoted = {}
  if not config.values.integrations then
    return promoted
  end
  for _, rule in ipairs(PROMOTION_RULES) do
    if M.has_plugin(rule.plugin) then
      local data = usage[rule.trigger]
      if data and (data.count or 0) >= rule.threshold then
        promoted[rule.cmd] = true
      end
    end
  end
  return promoted
end

function M.setup()
  if _initialized then
    return
  end
  _initialized = true

  M.refresh()

  local group = vim.api.nvim_create_augroup('tobira_integrations', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimEnter', 'SourcePost' }, {
    group = group,
    callback = function()
      M.refresh()
    end,
  })
end

function M.reset()
  _overrides = {}
  _plugins = {}
  _logged = {}
  _initialized = false
end

return M
