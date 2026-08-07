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

-- Curated LHS -> accepted-equivalent RHS literal(s); any other rhs is "not
-- equivalent". Y accepts 'y$' (Vim's built-in Y is really yy, not y$). %
-- accepts '<Plug>(MatchitNormalForward)' -- Neovim auto-loads matchit.vim's
-- own equivalent % remap by default, so it must not read as an override.
-- see docs/adr/0052-equivalent-remap-distinction.md
local EQUIVALENT_REMAPS = {
  Y = { 'y$' },
  ['%'] = { '<Plug>(MatchitNormalForward)' },
}

-- Neovim's own boot-time default mappings (gx, &, ]q/[q/]l/[l, Y=y$ on
-- 0.10+) register via the Lua/C API with no sourced script, so
-- nvim_get_keymap() reports sid == -8; a mapping from a real sourced script
-- gets a normal positive sid instead. See
-- docs/adr/0102-builtin-default-mapping-sid-detection.md -- sid alone is NOT
-- sufficient on its own (see is_untouched_builtin_default below).
local NVIM_BUILTIN_DEFAULT_SID = -8

-- sid == -8 also occurs for a genuine remap set from a deferred callback
-- (vim.schedule/vim.defer_fn/VimEnter -- how lazy.nvim's event-based config
-- commonly runs), so sid alone would misclassify it as an untouched
-- default. Mitigated by also requiring an exact match against the curated
-- `desc` text Neovim's own _defaults.lua sets on each mapping, which a real
-- remap won't reproduce unless explicitly copied. Both signals must agree;
-- a key with no entry here falls through to the conservative "assume
-- override" behavior. See
-- docs/adr/0102-builtin-default-mapping-sid-detection.md's QA addendum for
-- the full investigation and why this isn't a generic "has any desc" check.
local BUILTIN_DEFAULT_DESC = {
  ['gx'] = 'Opens filepath or URI under cursor with the system handler (file explorer, web browser, …)',
  ['&'] = ':help &-default',
  [']q'] = ':cnext',
  ['[q'] = ':cprevious',
  [']l'] = ':lnext',
  ['[l'] = ':lprevious',
  ['Y'] = ':help Y-default',
  ['<C-w>'] = ':help i_CTRL-W-default',
}

-- True only when BOTH the sid sentinel and the curated desc text agree this
-- mapping is still exactly what Neovim shipped -- see BUILTIN_DEFAULT_DESC
-- above for why sid alone is not sufficient.
local function is_untouched_builtin_default(registry_key, map)
  local expected_desc = BUILTIN_DEFAULT_DESC[registry_key]
  return expected_desc ~= nil and map.sid == NVIM_BUILTIN_DEFAULT_SID and map.desc == expected_desc
end

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

-- canonical (keytrans-normalized) form -> registry key, split into a
-- normal-mode set and an insert-mode set so M.refresh checks each entry
-- against the keymap for the mode it actually represents. Strips the 'i_'
-- composite-key prefix (commands.display_key) before the <...>-notation
-- check so composite entries canonicalize the same as their bare form.
-- see docs/adr/0008-composite-keys-for-dual-meaning-bytes.md's addendum
local function suggestible_keys()
  local watched_n = {}
  local watched_i = {}
  for cmd, entry in pairs(commands.registry) do
    if not entry.compound then
      local raw = commands.display_key(cmd)
      local canon = raw
      if raw:match('^<.->$') then
        local bytes = vim.api.nvim_replace_termcodes(raw, true, false, true)
        local kt = vim.fn.keytrans(bytes)
        if kt ~= '' then
          canon = kt
        end
      end
      local set = entry.mode == 'i' and watched_i or watched_n
      set[canon] = cmd
    end
  end
  return watched_n, watched_i
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
  local watched_n, watched_i = suggestible_keys()

  local new_overrides = {}
  -- maps: nvim_get_keymap(mode)'s raw list; watched: canon -> registry-key
  -- set for that same mode -- see the mode-split comment on suggestible_keys.
  local function collect(maps, watched)
    for _, map in ipairs(maps) do
      local registry_key = watched[canonical_lhs(map.lhs)] or watched[map.lhs]
      -- Skip Neovim's own untouched factory-default mapping -- not a real
      -- override. sid alone is insufficient; see is_untouched_builtin_default.
      if registry_key and not is_untouched_builtin_default(registry_key, map) then
        local rhs = rhs_of(map)
        new_overrides[registry_key] = { rhs = rhs, equivalent = is_equivalent(registry_key, rhs) }
      end
    end
  end
  collect(keymap_fn('n'), watched_n)
  collect(keymap_fn('i'), watched_i)

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
