local M = {}

-- Suggestion definitions: cmd → display info
-- trigger: the command a user is already using heavily
-- pattern: the detection pattern id from logger.lua
M.suggestions = {
  [';'] = {
    cmd = ';',
    trigger = 'f',
    pattern = 'f_repeat',
    title = '; — repeat the last f',
    body = 'After f{char}, press ; to find the same char again\n, goes in reverse',
    example = 'fa ;; → jumps to the next a, then the next',
  },
  ['cw'] = {
    cmd = 'cw',
    trigger = 'dw',
    pattern = 'dw_then_insert',
    title = 'cw — delete word and insert',
    body = 'cw replaces the dw + i sequence in one motion\nDrops you into insert mode immediately',
    example = 'cw → deletes word → insert mode',
  },
  ['ciw'] = {
    cmd = 'ciw',
    trigger = 'dw',
    pattern = 'dw_then_insert',
    title = 'ciw — change inner word',
    body = 'Works even when cursor is in the middle of the word\nUnlike cw, which only deletes from cursor forward',
    example = 'hel|lo → ciw → world',
  },
  ['gn'] = {
    cmd = 'gn',
    trigger = '/',
    pattern = nil,
    title = 'gn — select next search match',
    body = 'After /, gn visually selects the next match\ncgn changes it; . repeats on the next match',
    example = '/word → cgn → newword → . . .',
  },
}

-- Adjacency map for :Tobira manual discovery
M.adjacency = {
  ['f'] = { ';', ',' },
  ['F'] = { ';', ',' },
  ['dw'] = { 'cw', 'ciw' },
  ['dd'] = { 'dip', 'cc', 'S' },
  ['x'] = { 's', 'r', 'cl' },
  ['/'] = { '*', '#', 'gn', 'cgn' },
  ['p'] = { 'P', '"0p' },
  ['u'] = { 'U', '<C-r>' },
}

-- Find the best suggestion based on current usage data
function M.find_best(usage)
  local best_cmd = nil
  local best_score = -1

  for cmd, sug in pairs(M.suggestions) do
    local data = usage[cmd] or { count = 0, shown = 0, adopted = false }

    if not data.adopted and data.shown < 3 then
      local trigger_count = (usage[sug.trigger] and usage[sug.trigger].count) or 0
      local cmd_count = data.count

      if trigger_count > 0 then
        local score = trigger_count - cmd_count
        if score > best_score then
          best_score = score
          best_cmd = cmd
        end
      end
    end
  end

  return best_cmd
end

return M
