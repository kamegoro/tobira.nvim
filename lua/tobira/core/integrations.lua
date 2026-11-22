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

-- Neovim's own boot-time default mappings surface as sid == -8, but so does a
-- genuine remap set from a deferred callback, so a mapping counts as an
-- untouched default only when its desc also matches what Neovim shipped.
-- see docs/adr/0102-builtin-default-mapping-sid-detection.md
local NVIM_BUILTIN_DEFAULT_SID = -8

-- mode -> keytrans-canonical lhs -> accepted desc text(s). Every sid == -8
-- normal/insert-mode default from `nvim --clean` on 0.10.4, 0.11.0, 0.11.7
-- and 0.12.6, not only keys commands.lua teaches today.
local BUILTIN_DEFAULTS = {
  n = {
    ['gx'] = { 'Opens filepath or URI under cursor with the system handler (file explorer, web browser, …)' },
    ['&'] = { ':help &-default' },
    ['Y'] = { ':help Y-default' },
    ['<C-L>'] = { ':help CTRL-L-default' },
    ['gc'] = { 'Toggle comment' },
    ['gcc'] = { 'Toggle comment line' },
    ['gO'] = { 'vim.lsp.buf.document_symbol()' },
    ['gra'] = { 'vim.lsp.buf.code_action()' },
    ['gri'] = { 'vim.lsp.buf.implementation()' },
    ['grn'] = { 'vim.lsp.buf.rename()' },
    ['grr'] = { 'vim.lsp.buf.references()' },
    ['grt'] = { 'vim.lsp.buf.type_definition()' },
    ['grx'] = { 'vim.lsp.codelens.run()' },
    ['<C-W>d'] = { 'Show diagnostics under the cursor' },
    ['<C-W><C-D>'] = { 'Show diagnostics under the cursor' },
    [']d'] = { 'Jump to the next diagnostic in the current buffer', 'Jump to the next diagnostic' },
    ['[d'] = { 'Jump to the previous diagnostic in the current buffer', 'Jump to the previous diagnostic' },
    [']D'] = { 'Jump to the last diagnostic in the current buffer' },
    ['[D'] = { 'Jump to the first diagnostic in the current buffer' },
    [']q'] = { ':cnext' },
    ['[q'] = { ':cprevious' },
    [']Q'] = { ':clast' },
    ['[Q'] = { ':crewind' },
    [']<C-Q>'] = { ':cnfile' },
    ['[<C-Q>'] = { ':cpfile' },
    [']l'] = { ':lnext' },
    ['[l'] = { ':lprevious' },
    [']L'] = { ':llast' },
    ['[L'] = { ':lrewind' },
    [']<C-L>'] = { ':lnfile' },
    ['[<C-L>'] = { ':lpfile' },
    [']t'] = { ':tnext' },
    ['[t'] = { ':tprevious' },
    [']T'] = { ':tlast' },
    ['[T'] = { ':trewind' },
    [']<C-T>'] = { ':ptnext' },
    ['[<C-T>'] = { ':ptprevious', ' :ptprevious' },
    [']a'] = { ':next' },
    ['[a'] = { ':previous' },
    [']A'] = { ':last' },
    ['[A'] = { ':rewind' },
    [']b'] = { ':bnext' },
    ['[b'] = { ':bprevious' },
    [']B'] = { ':blast' },
    ['[B'] = { ':brewind' },
    [']<Space>'] = { 'Add empty line below cursor' },
    ['[<Space>'] = { 'Add empty line above cursor' },
  },
  i = {
    ['<C-W>'] = { ':help i_CTRL-W-default' },
    ['<C-U>'] = { ':help i_CTRL-U-default' },
    ['<C-S>'] = { 'vim.lsp.buf.signature_help()' },
    ['<Tab>'] = { 'vim.snippet.jump if active, otherwise <Tab>' },
    ['<S-Tab>'] = { 'vim.snippet.jump if active, otherwise <S-Tab>' },
  },
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

-- True only when BOTH the sid sentinel and the shipped desc text agree.
local function is_untouched_builtin_default(mode, map)
  local accepted = BUILTIN_DEFAULTS[mode][canonical_lhs(map.lhs)]
  if map.sid ~= NVIM_BUILTIN_DEFAULT_SID or not accepted then
    return false
  end
  return vim.tbl_contains(accepted, map.desc)
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
  -- mode: 'n'/'i' as passed to keymap_fn; watched: canon -> registry-key
  -- set for that same mode -- see the mode-split comment on suggestible_keys.
  local function collect(mode, watched)
    for _, map in ipairs(keymap_fn(mode)) do
      local registry_key = watched[canonical_lhs(map.lhs)] or watched[map.lhs]
      if registry_key and not is_untouched_builtin_default(mode, map) then
        local rhs = rhs_of(map)
        new_overrides[registry_key] = { rhs = rhs, equivalent = is_equivalent(registry_key, rhs) }
      end
    end
  end
  collect('n', watched_n)
  collect('i', watched_i)

  _overrides = new_overrides
  _plugins = detect_plugins()
end

function M.get_overrides()
  return _overrides
end

function M.get_override(cmd)
  return _overrides[cmd]
end

-- Sorted array of { cmd, rhs, equivalent } for :checkhealth; refresh itself
-- is silent. see docs/adr/0122-remap-report-in-checkhealth-not-startup-notify.md
function M.list_overrides()
  local list = {}
  for cmd, info in pairs(_overrides) do
    list[#list + 1] = { cmd = cmd, rhs = info.rhs, equivalent = info.equivalent }
  end
  table.sort(list, function(a, b)
    return a.cmd < b.cmd
  end)
  return list
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

  -- see docs/adr/0055-refresh-cadence-and-notification-dedup.md
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
  _initialized = false
end

return M
