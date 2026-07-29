local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_guide')

local WIDTH = 60 -- widened to fit the mastery-symbol and count columns
local ICON = '' -- nerd font fa-info-circle (matches nvim-notify INFO icon)

-- Caps each category's auto section so the panel stays a small "glance while
-- you code" sidebar regardless of how many commands a brand-new user hasn't
-- touched yet, instead of growing to fit everything.
local MAX_PER_CATEGORY = 3

local CATEGORY_ORDER = { 'motion', 'edit', 'search', 'window', 'fold', 'mark', 'macro', 'diff', 'ex', 'terminal' }

local setup_hls = require('tobira.ui.hls').setup

-- Extract only the description part from a title like "cmd — description".
local function short_desc(title)
  return title:match(' — (.+)$') or title
end

-- The auto section's suffix: forgotten_suffix plus a remapped_suffix for
-- commands remapped to something functionally equivalent to what
-- commands.lua documents (e.g. `nnoremap Y y$` — see integrations.lua's
-- EQUIVALENT_REMAPS). A *non*-equivalent remap never reaches this function —
-- M.build() drops that row from the auto section entirely, since showing
-- wrong information in a reference row is worse than omitting it. Shared by
-- the description-width pass and format_row so the two never disagree about
-- a row's rendered width.
local function auto_suffix(cmd, data, str)
  local graph = require('tobira.core.graph')
  local integrations = require('tobira.core.integrations')
  local suffix = graph.is_forgotten(data) and str.forgotten_suffix or ''
  if integrations.is_equivalent_override(cmd) then
    local override = integrations.get_override(cmd)
    suffix = suffix .. string.format(str.remapped_suffix, override.rhs)
  end
  return suffix
end

-- Returns (glyph, hlgroup) for the mastery-symbol column, or (nil, nil) for a
-- never-tried command (blank cell + TobiraDim on the whole row instead — see
-- format_row). Forgotten takes priority over the numeric level: a command
-- once mastered that's gone quiet should read as "come back to this", not
-- whatever star count it reached before going quiet.
--
-- Only two branches are reachable here (is_forgotten, or level <= 1):
-- build() only calls this for rows guide_commands() included, whose filter
-- is `not is_mastered(data)` = `mastery_level < 2 or is_forgotten`. So a
-- level >= 2 row reaching here is always forgotten and already returns
-- above — there is deliberately no `elseif level >= 2` branch; it would be
-- dead code.
local function mastery_glyph(data)
  local graph = require('tobira.core.graph')
  if graph.is_forgotten(data) then
    return '⟳', 'TobiraGuideForgotten'
  end
  if graph.mastery_level(data) == 1 then
    return '☆', 'TobiraGuideHint'
  end
  return nil, nil
end

-- Builds one pinned-section row. Position-tracking emit() avoids
-- hand-computed byte offsets for highlight ranges (glyph and key are both
-- variable-width once combined with multi-byte glyphs).
--
-- `data` drives the same forgotten-state check format_row makes: a pinned
-- command once mastered that's gone quiet gets the ⟳ glyph + forgotten_suffix
-- here too, instead of staying a plain ● row forever.
--
-- A pinned row is never *omitted* for a remap, unlike the auto section
-- (which drops a non-equivalent remap entirely — see auto_suffix's header):
-- the user pinned this on purpose, so silently vanishing would read as
-- tobira losing track of the pin. An equivalent remap (`nnoremap Y y$`)
-- still substitutes wording via remapped_suffix; a *different* remap
-- replaces the description with remapped_invalid instead of appending a
-- correction after text that's now flatly wrong — the row stays visible,
-- just with an accurate note.
local function format_pinned_row(cmd, data, desc, str)
  local graph = require('tobira.core.graph')
  local integrations = require('tobira.core.integrations')
  local commands = require('tobira.commands')
  local forgotten = graph.is_forgotten(data)

  local override = integrations.get_override(cmd)
  if override then
    if integrations.is_equivalent_override(cmd) then
      desc = desc .. string.format(str.remapped_suffix, override.rhs)
    else
      desc = string.format(str.remapped_invalid, override.rhs)
    end
  end
  if forgotten then
    desc = desc .. str.forgotten_suffix
  end

  local pos = 0
  local parts = {}
  local hls = {}

  local function emit(text, group)
    table.insert(parts, text)
    if group then
      table.insert(hls, { cs = pos, ce = pos + #text, group = group })
    end
    pos = pos + #text
  end

  emit('   ')
  emit('●', 'TobiraGuidePinned')
  emit('  ')
  emit(string.format('%-12s', commands.display_key(cmd)), 'TobiraGuideKey')
  emit('  ')
  if forgotten then
    emit('⟳ ', 'TobiraGuideForgotten')
  end
  emit(desc)

  return table.concat(parts), hls
end

-- Builds one auto-section row: mastery glyph, key, description (+ forgotten
-- suffix), and a right-aligned count. `desc_col_w` is the max display width of
-- desc+suffix across every row in the current build pass (not a fixed global
-- constant) so the count column aligns without padding every row out to the
-- width of the single longest description in the whole command set.
local function format_row(cmd, desc, data, desc_col_w, str)
  local commands = require('tobira.commands')
  local glyph, glyph_hl = mastery_glyph(data)
  local dim = glyph == nil
  local suffix = auto_suffix(cmd, data, str)
  local count = data.count or 0
  local count_str = count > 0 and (tostring(count) .. '×') or ''

  local pos = 0
  local parts = {}
  local hls = {}

  local function emit(text, group)
    table.insert(parts, text)
    if group and not dim then
      table.insert(hls, { cs = pos, ce = pos + #text, group = group })
    end
    pos = pos + #text
  end

  emit('   ')
  emit(glyph or ' ', glyph_hl)
  emit('  ')
  emit(string.format('%-12s', commands.display_key(cmd)), 'TobiraGuideKey')
  emit('  ')
  local desc_str = desc .. suffix
  emit(desc_str)
  emit(string.rep(' ', math.max(0, desc_col_w - vim.fn.strdisplaywidth(desc_str))))
  if count_str ~= '' then
    emit('  ')
    emit(count_str, 'TobiraGuideHint')
  end

  local line = table.concat(parts)
  if dim then
    hls = { { cs = 0, ce = -1, group = 'TobiraDim' } }
  end
  return line, hls
end

-- Pure: takes usage explicitly (mirrors ui/stats.lua's M.render(usage)) so
-- layout can be tested without opening a real window. M.open()/M.refresh()
-- are the only callers that read logger.get_all().
function M.build(usage)
  local loc = require('tobira.i18n').load()
  local strings = loc.guide
  local suggestions = loc.suggestions or {}
  local cat_labels = loc.progress and loc.progress.categories or {}
  local commands = require('tobira.commands')
  local graph = require('tobira.core.graph')

  -- Collect pinned commands (sorted for determinism)
  local pinned_cmds = {}
  local pinned_set = {}
  for cmd, data in pairs(usage) do
    if data.pinned and commands.registry[cmd] then
      table.insert(pinned_cmds, cmd)
      pinned_set[cmd] = true
    end
  end
  table.sort(pinned_cmds)

  local by_cat = graph.guide_commands(usage)

  -- Remove pinned commands from the auto section to avoid duplication, sort
  -- each category never-tried-first (Guide surfaces blind spots — Progress
  -- already owns the "close to mastery" gradient, see ui/CLAUDE.md) with an
  -- alphabetical tie-break, and cap to MAX_PER_CATEGORY. A command remapped
  -- to something *not* equivalent to what commands.lua documents is dropped
  -- entirely — this is a persistent reference row, and showing wrong
  -- information is worse than omitting it. An equivalent remap
  -- (`nnoremap Y y$`) still renders, suffixed via auto_suffix() instead.
  local integrations = require('tobira.core.integrations')
  local overflow_by_cat = {}
  for cat, cmds in pairs(by_cat) do
    local filtered = {}
    for _, cmd in ipairs(cmds) do
      local hidden = integrations.is_overridden(cmd) and not integrations.is_equivalent_override(cmd)
      if not pinned_set[cmd] and not hidden then
        table.insert(filtered, cmd)
      end
    end
    table.sort(filtered, function(a, b)
      local a_never = ((usage[a] or {}).count or 0) == 0
      local b_never = ((usage[b] or {}).count or 0) == 0
      if a_never ~= b_never then
        return a_never
      end
      return a < b
    end)
    if #filtered > MAX_PER_CATEGORY then
      overflow_by_cat[cat] = #filtered - MAX_PER_CATEGORY
      local capped = {}
      for i = 1, MAX_PER_CATEGORY do
        capped[i] = filtered[i]
      end
      filtered = capped
    end
    by_cat[cat] = filtered
  end

  -- First pass: collect every auto-section row so the count column can be
  -- aligned to the max description width actually being rendered right now.
  local auto_rows = {}
  for _, cat in ipairs(CATEGORY_ORDER) do
    local cmds = by_cat[cat]
    if cmds and #cmds > 0 then
      for _, cmd in ipairs(cmds) do
        local sug = suggestions[cmd]
        local desc = short_desc((sug and sug.title) or cmd)
        local data = usage[cmd] or { count = 0 }
        table.insert(auto_rows, { cat = cat, cmd = cmd, desc = desc, data = data })
      end
    end
  end

  -- Per category, not global — a long description in one category (e.g.
  -- motion) must not force every row in a short category (e.g. fold) to pad
  -- out to match it.
  local desc_col_w_by_cat = {}
  for _, row in ipairs(auto_rows) do
    local suffix = auto_suffix(row.cmd, row.data, strings)
    local w = vim.fn.strdisplaywidth(row.desc .. suffix)
    desc_col_w_by_cat[row.cat] = math.max(desc_col_w_by_cat[row.cat] or 0, w)
  end

  local lines = {}
  local hls = {}

  local function push(line, group, cs, ce)
    local lnum = #lines
    table.insert(lines, line)
    if group then
      table.insert(hls, { lnum = lnum, cs = cs or 0, ce = ce or -1, group = group })
    end
  end

  push('')

  -- Pinned section
  if #pinned_cmds > 0 then
    push('')
    local pin_label = strings.pinned or 'Pinned'
    push('  ' .. pin_label, 'TobiraGuidePinned', 2, 2 + #pin_label)
    for _, cmd in ipairs(pinned_cmds) do
      local sug = suggestions[cmd]
      local desc = short_desc((sug and sug.title) or cmd)
      local data = usage[cmd] or { count = 0 }
      local line, row_hls = format_pinned_row(cmd, data, desc, strings)
      local lnum = #lines
      table.insert(lines, line)
      for _, h in ipairs(row_hls) do
        table.insert(hls, { lnum = lnum, cs = h.cs, ce = h.ce, group = h.group })
      end
    end
  end

  -- Auto section
  local function push_overflow(cat)
    local overflow = overflow_by_cat[cat]
    if overflow then
      push('      ' .. string.format(strings.more_suffix, overflow), 'TobiraDim')
    end
  end

  local current_cat = nil
  for _, row in ipairs(auto_rows) do
    if row.cat ~= current_cat then
      if current_cat then
        push_overflow(current_cat)
      end
      current_cat = row.cat
      push('')
      local label = cat_labels[row.cat] or row.cat
      push('  ' .. label, 'TobiraGuideSection', 2, 2 + #label)
    end
    local line, row_hls = format_row(row.cmd, row.desc, row.data, desc_col_w_by_cat[row.cat], strings)
    local lnum = #lines
    table.insert(lines, line)
    for _, h in ipairs(row_hls) do
      table.insert(hls, { lnum = lnum, cs = h.cs, ce = h.ce, group = h.group })
    end
  end
  if current_cat then
    push_overflow(current_cat)
  end

  if #auto_rows == 0 and #pinned_cmds == 0 then
    push('')
    push('  ' .. (strings.all_mastered or ''), 'TobiraGuideMastered')
  end

  push('')

  return lines, hls, strings
end

-- Returns the number of terminal rows the lines will occupy after wrapping.
local function wrapped_height(lines)
  local h = 0
  for _, line in ipairs(lines) do
    h = h + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / WIDTH))
  end
  return h
end

local function apply_content(lines, hls)
  vim.bo[_buf].modifiable = true
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(_buf, _ns, 0, -1)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
  end
  vim.bo[_buf].modifiable = false
end

function M.is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

function M.refresh()
  if not M.is_open() then
    return
  end
  local lines, hls = M.build(require('tobira.core.logger').get_all())
  apply_content(lines, hls)
  vim.api.nvim_win_set_height(_win, wrapped_height(lines))
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(_win, true)
  end
  pcall(vim.api.nvim_del_augroup_by_name, 'tobira_guide_ctx')
  _win = nil
  _buf = nil
end

function M.open()
  if M.is_open() then
    return
  end

  setup_hls()

  local lines, hls, strings = M.build(require('tobira.core.logger').get_all())

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'
  vim.bo[_buf].filetype = 'tobira_guide'

  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
  end

  local uis = vim.api.nvim_list_uis()
  local screen_w = (uis[1] and uis[1].width) or 120
  local screen_h = (uis[1] and uis[1].height) or 40
  local height = math.min(wrapped_height(lines), screen_h - 4)

  _win = vim.api.nvim_open_win(_buf, false, {
    relative = 'editor',
    row = math.max(1, math.floor((screen_h - height) / 2)),
    col = screen_w - WIDTH - 2,
    width = WIDTH,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. ICON .. ' ' .. strings.title .. ' ',
    title_pos = 'left',
    focusable = false,
    zindex = 40,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = true
  vim.wo[_win].linebreak = true
  vim.wo[_win].breakindent = true

  -- Auto-refresh when moving between windows (context or mastery may change)
  vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('tobira_guide_ctx', { clear = true }),
    callback = function()
      if vim.api.nvim_get_current_win() == _win then
        return
      end
      vim.schedule(M.refresh)
    end,
  })
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
