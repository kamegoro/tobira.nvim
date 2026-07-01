-- :TobiraStats renderer.
-- M.render(usage) is pure: takes a usage table, returns { title, body } strings.
-- M.show() reads live usage from the logger and calls vim.notify.
local M = {}

local BAR_SEGMENTS = 16
local BAR_FILLED = '█'
local BAR_EMPTY = '░'
local TOP_N = 5

local STAR_BY_LEVEL = { [0] = ' ', [1] = '☆', [2] = '★', [3] = '★★', [4] = '★★★' }

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

function M.render(usage)
  local str = require('tobira.i18n').load().stats
  local graph = require('tobira.core.graph')

  local dist = graph.knowledge_dist(usage)
  local total_cmds = dist.never + dist.tried + dist.familiar + dist.mastered
  local discovered = total_cmds - dist.never
  local pct = total_cmds > 0 and math.floor(discovered / total_cmds * 100 + 0.5) or 0

  -- Total keystrokes: sum ALL tracked commands (including basic keys like j/k
  -- that live outside commands.registry). This is the raw "big number" metric.
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

  local gaps = graph.efficiency_gaps(usage, 3)

  local lines = { '' }

  -- ── Summary ───────────────────────────────────────────────────────────────
  table.insert(lines, string.format('  %s  %s', rpad(str.total_keystrokes, 18), fmt_int_commas(total_keys)))
  table.insert(
    lines,
    string.format('  %s  %s / %s', rpad(str.discovered, 18), fmt_int_commas(discovered), fmt_int_commas(total_cmds))
  )
  table.insert(lines, '')

  -- ── Mastery bar ───────────────────────────────────────────────────────────
  table.insert(lines, string.format('  %s  %s  %d%%', str.mastery, make_bar(pct), pct))
  table.insert(lines, string.format(str.mastery_dist, dist.never, dist.tried, dist.familiar, dist.mastered))

  -- ── Top commands ──────────────────────────────────────────────────────────
  if #sorted > 0 then
    table.insert(lines, '')
    table.insert(lines, '  ' .. str.top_commands)
    for i = 1, math.min(TOP_N, #sorted) do
      local item = sorted[i]
      local lv = graph.mastery_level(item.data)
      local star = STAR_BY_LEVEL[lv] or ' '
      table.insert(
        lines,
        string.format('    %s  %s  %s×', rpad(star, 5), rpad(item.cmd, 6), lpad(fmt_int_commas(item.data.count), 6))
      )
    end
  end

  -- ── Efficiency gaps ───────────────────────────────────────────────────────
  if #gaps > 0 then
    table.insert(lines, '')
    table.insert(lines, '  ' .. str.try_next)
    for _, g in ipairs(gaps) do
      table.insert(
        lines,
        string.format(
          '    %s %s×  →  %s %s×',
          rpad(g.parent, 5),
          lpad(fmt_int_commas(g.parent_count), 5),
          rpad(g.child, 5),
          lpad(fmt_int_commas(g.child_count), 4)
        )
      )
    end
  end

  return {
    title = str.title,
    body = table.concat(lines, '\n'),
  }
end

function M.show()
  local usage = require('tobira.core.logger').get_all()
  local rendered = M.render(usage)
  vim.notify(rendered.title .. '\n' .. rendered.body, vim.log.levels.INFO)
end

return M
