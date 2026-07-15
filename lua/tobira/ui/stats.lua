-- :TobiraStats renderer.
-- M.render(usage) is pure: takes a usage table, returns { title, body, hls }.
-- hls is a list of { lnum, group, cs, ce } (lnum 0-indexed against body's
-- line split) so M.open() can apply TobiraH1/TobiraDim without re-deriving
-- them from plain text.
-- M.toggle() opens/closes a focused custom float window.
local M = {}

local _win = nil
local _buf = nil
local _prev_win = nil
local _ns = vim.api.nvim_create_namespace('tobira_stats')

local BAR_SEGMENTS = 16
local BAR_FILLED = '█'
local BAR_EMPTY = '░'
local TOP_N = 8
local GAPS_N = 5
local ICON = ''

local setup_hls = require('tobira.ui.hls').setup

local function fmt_int_commas(n)
  local s = tostring(math.floor(n))
  while true do
    local replaced
    s, replaced = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    if replaced == 0 then
      break
    end
  end
  return s
end

local function make_bar(pct)
  local filled = math.floor(pct / 100 * BAR_SEGMENTS + 0.5)
  return string.rep(BAR_FILLED, filled) .. string.rep(BAR_EMPTY, BAR_SEGMENTS - filled)
end

-- Pad a string on the right to n display columns (handles ★ double-width).
local function rpad(s, n)
  return s .. string.rep(' ', math.max(0, n - vim.fn.strdisplaywidth(s)))
end

-- Pad a string on the left to n display columns.
local function lpad(s, n)
  return string.rep(' ', math.max(0, n - vim.fn.strdisplaywidth(s))) .. s
end

-- Order follows the dashboard "5-second rule" + actionable-vs-vanity-metrics
-- research from the #74 design review: the one section that changes what the
-- user does next (efficiency gaps) leads; the section that's just a fun
-- number (raw keystroke count) trails as a de-emphasized closing line.
function M.render(usage)
  local str = require('tobira.i18n').load().stats
  local graph = require('tobira.core.graph')

  local dist = graph.knowledge_dist(usage)
  local total_cmds = dist.never + dist.tried + dist.familiar + dist.mastered
  local discovered = total_cmds - dist.never
  local pct = total_cmds > 0 and math.floor(discovered / total_cmds * 100 + 0.5) or 0

  -- Total keystrokes: sum ALL tracked commands (including basic keys like j/k
  -- that live outside commands.registry). This is the raw "big number" metric
  -- — fun to see, doesn't drive a decision, so it's demoted to the footer.
  local total_keys = 0
  for cmd, data in pairs(usage) do
    if cmd ~= '_meta' and type(data) == 'table' then
      total_keys = total_keys + (data.count or 0)
    end
  end

  -- Top commands: include every recorded command (basic keys, compound ops,
  -- registry entries). This is a "what did I actually press" leaderboard —
  -- distinct from the discovered/registry-based mastery metric above.
  local sorted = {}
  for cmd, data in pairs(usage) do
    if cmd ~= '_meta' and type(data) == 'table' and (data.count or 0) > 0 then
      table.insert(sorted, { cmd = cmd, data = data })
    end
  end
  table.sort(sorted, function(a, b)
    if a.data.count ~= b.data.count then
      return a.data.count > b.data.count
    end
    return a.cmd < b.cmd
  end)

  local gaps = graph.efficiency_gaps(usage, GAPS_N)

  local STAR_BY_LEVEL = { [0] = ' ', [1] = '☆', [2] = '★', [3] = '★★', [4] = '★★★' }

  local lines = {}
  local hls = {}

  local function push(line, group, cs, ce)
    local lnum = #lines
    table.insert(lines, line)
    if group then
      table.insert(hls, { lnum = lnum, group = group, cs = cs or 0, ce = ce or -1 })
    end
  end

  push('')

  -- ── Try these next (promoted — the only actionable section) ────────────────
  if #gaps > 0 then
    push('  ' .. str.try_next, 'TobiraH1')
    for _, g in ipairs(gaps) do
      push(
        string.format(
          '    %s %s×  →  %s %s×',
          rpad(g.parent, 5),
          lpad(fmt_int_commas(g.parent_count), 5),
          rpad(g.child, 5),
          lpad(fmt_int_commas(g.child_count), 4)
        )
      )
    end
    push('')
  end

  -- ── Mastery ──────────────────────────────────────────────────────────────
  push('  ' .. str.mastery, 'TobiraH1')
  push(string.format('    %s  %d%%', make_bar(pct), pct))
  push(string.format(str.mastery_dist, dist.never, dist.tried, dist.familiar, dist.mastered))
  push('')

  -- ── Top commands ─────────────────────────────────────────────────────────
  if #sorted > 0 then
    push('  ' .. str.top_commands, 'TobiraH1')
    for i = 1, math.min(TOP_N, #sorted) do
      local item = sorted[i]
      local lv = graph.mastery_level(item.data)
      local star = STAR_BY_LEVEL[lv] or ' '
      push(
        string.format('    %s  %s  %s×', rpad(star, 5), rpad(item.cmd, 6), lpad(fmt_int_commas(item.data.count), 6))
      )
    end
    push('')
  end

  -- ── Footer summary (demoted — fun number, not a decision driver) ───────────
  push(
    '  '
      .. str.footer_summary:format(fmt_int_commas(total_keys), fmt_int_commas(discovered), fmt_int_commas(total_cmds)),
    'TobiraDim'
  )

  return {
    title = str.title,
    body = table.concat(lines, '\n'),
    hls = hls,
  }
end

function M.is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(_win, true)
  end
  if _prev_win ~= nil and vim.api.nvim_win_is_valid(_prev_win) then
    pcall(vim.api.nvim_set_current_win, _prev_win)
  end
  _win = nil
  _buf = nil
  _prev_win = nil
end

function M.open()
  if M.is_open() then
    return
  end

  local str = require('tobira.i18n').load()
  local usage = require('tobira.core.logger').get_all()
  local rendered = M.render(usage)

  _prev_win = vim.api.nvim_get_current_win()
  setup_hls()

  -- Build line array from the rendered body. The keybinding hint lives on the
  -- window footer (see below), not as a buffer line, so it stays pinned to the
  -- border and matches the progress panel.
  local lines = {}
  for line in (rendered.body .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, line)
  end

  -- Keybindings shown on the footer: g guide · p progress · q close.
  local footer, footer_w = require('tobira.ui.footer').build({
    { 'g', str.stats.footer.guide },
    { 'p', str.stats.footer.progress },
    { 'q', str.stats.footer.close },
  })

  -- Width: fit the widest line, also wide enough for the title and footer.
  local title_text = ' ' .. ICON .. ' ' .. rendered.title .. ' '
  local max_len = math.max(vim.fn.strdisplaywidth(title_text), footer_w) + 2
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_len then
      max_len = w
    end
  end

  local uis = vim.api.nvim_list_uis()
  local screen_w = uis[1] and uis[1].width or 120
  local screen_h = uis[1] and uis[1].height or 40
  local win_w = math.min(max_len + 2, screen_w - 6)
  -- Modal-sized (screen_h - 12), matching the progress panel, so it doesn't
  -- fill the screen and the footer stays clear of the editor's statusline.
  local win_h = math.min(#lines, screen_h - 12)

  _buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false
  vim.bo[_buf].bufhidden = 'wipe'

  for _, hl in ipairs(rendered.hls) do
    vim.api.nvim_buf_add_highlight(_buf, _ns, hl.group, hl.lnum + 1, hl.cs, hl.ce)
  end

  vim.keymap.set('n', 'q', M.close, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', '<Esc>', M.close, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', 'g', function()
    M.close()
    require('tobira.ui.guide').open()
  end, { buffer = _buf, nowait = true, silent = true })
  vim.keymap.set('n', 'p', function()
    M.close()
    require('tobira.ui.progress').open()
  end, { buffer = _buf, nowait = true, silent = true })

  -- Center on screen.
  local row = math.max(1, math.floor((screen_h - win_h) / 2))
  local col = math.max(1, math.floor((screen_w - win_w) / 2))

  _win = vim.api.nvim_open_win(_buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = win_w,
    height = win_h,
    style = 'minimal',
    border = 'rounded',
    title = title_text,
    title_pos = 'left',
    footer = footer,
    footer_pos = 'center',
    focusable = true,
    zindex = 50,
  })

  vim.wo[_win].winhl = 'Normal:TobiraGuideNormal,FloatBorder:TobiraGuideBorder'
  vim.wo[_win].wrap = false
  vim.wo[_win].cursorline = false
  vim.wo[_win].scrolloff = 0

  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = _buf,
    once = true,
    callback = function()
      vim.defer_fn(M.close, 0)
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

-- Kept for backwards compatibility (plugin/tobira.lua calls M.show).
function M.show()
  M.toggle()
end

return M
