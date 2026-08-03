local M = {}

local _win = nil
local _buf = nil
local _ns = vim.api.nvim_create_namespace('tobira_guide')

local WIDTH = 60 -- widened to fit the mastery-symbol and count columns
local ICON = '' -- nerd font fa-info-circle (matches nvim-notify INFO icon)

-- Per-category cap for the auto section — see
-- docs/adr/0060-guide-auto-section-capped-never-tried-first.md for why.
local MAX_PER_CATEGORY = 3

local CATEGORY_ORDER = { 'motion', 'edit', 'search', 'window', 'fold', 'mark', 'macro', 'diff', 'ex', 'terminal' }

-- Named hls_mod, not hls -- `hls` is already used throughout this file as
-- the local variable name for the highlight-range list (M.build,
-- apply_content, M.open), so aliasing the module to the same name would
-- shadow it inside every function that builds or applies that list.
local hls_mod = require('tobira.ui.hls')
local setup_hls = hls_mod.setup

-- Extract only the description part from a title like "cmd — description".
local function short_desc(title)
  return title:match(' — (.+)$') or title
end

-- Builds the auto section's suffix: forgotten_suffix plus remapped_suffix
-- for an equivalent remap. A non-equivalent remap never reaches this
-- function — M.build() drops that row entirely. Shared by the
-- description-width pass and format_row so both agree on row width.
-- See docs/adr/0061-guide-auto-vs-pinned-remap-visibility.md for why.
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

-- Returns (glyph, hlgroup) for the mastery column, or (nil, nil) for a
-- never-tried command (blank + TobiraDim row instead — see format_row).
-- Only two branches are reachable: guide_commands()'s filter guarantees any
-- row reaching here with level >= 2 is already forgotten, so there is no
-- `elseif level >= 2` branch.
-- See docs/adr/0062-guide-mastery-glyph-forgotten-priority.md for why.
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
-- variable-width once combined with multi-byte glyphs). Applies the same
-- forgotten-state check as format_row, and never omits a row for a remap
-- (unlike the auto section) — see
-- docs/adr/0061-guide-auto-vs-pinned-remap-visibility.md for why.
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
-- suffix), and a right-aligned count. `desc_col_w` is the max description
-- width for the current build pass, not a fixed constant — see M.build's
-- per-category pass below.
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

-- Pure: takes usage explicitly, so layout can be tested without a real
-- window. M.open()/M.refresh() are the only callers that read logger.get_all().
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

  -- Strip pinned commands, sort each category never-tried-first, cap to
  -- MAX_PER_CATEGORY, and drop non-equivalent remaps entirely. See
  -- docs/adr/0060-guide-auto-section-capped-never-tried-first.md and
  -- docs/adr/0061-guide-auto-vs-pinned-remap-visibility.md for why.
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

  -- First pass: collect every row so the count column aligns to the
  -- description widths actually being rendered.
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

  -- Per category, not global — a long description in one category must not
  -- pad out rows in a shorter category.
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
    hls_mod.set_range(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
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
    hls_mod.set_range(_buf, _ns, hl.group, hl.lnum, hl.cs, hl.ce)
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
