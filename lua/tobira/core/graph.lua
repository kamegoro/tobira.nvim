local M = {}

M.suggestions = {
  -- f / F repeat
  [';'] = {
    cmd = ';',
    trigger = 'f',
    title = '; — repeat the last f',
    body = 'After f{char}, press ; to jump to the next occurrence\n, goes in the reverse direction',
    example = 'fa ;; → next a, then the next',
  },
  [','] = {
    cmd = ',',
    trigger = 'f',
    title = ', — repeat f in reverse',
    body = 'The opposite of ; — jumps back to the previous f match\nUseful when you overshoot with ;',
    example = 'fa ;;; , → jump back one',
  },

  -- dw → insert
  ['cw'] = {
    cmd = 'cw',
    trigger = 'dw',
    title = 'cw — delete word and insert',
    body = 'Replaces the dw + i sequence in one motion\nDrops you into insert mode immediately after deleting',
    example = 'cw → deletes from cursor to end of word → insert mode',
  },
  ['ciw'] = {
    cmd = 'ciw',
    trigger = 'dw',
    title = 'ciw — change inner word',
    body = 'Works even when cursor is in the middle of a word\ncw only deletes from cursor forward; ciw replaces the whole word',
    example = 'hel|lo → ciw → world',
  },

  -- u repeat → redo
  ['<C-r>'] = {
    cmd = '<C-r>',
    trigger = 'u',
    title = '<C-r> — redo',
    body = 'Undid too much? <C-r> redoes the last undone change\nPair with u / <C-r> to navigate change history',
    example = 'u u u <C-r> → undo 3 times, redo once',
  },

  -- dd → p → swap lines
  ['ddp'] = {
    cmd = 'ddp',
    trigger = 'dd',
    title = 'ddp — swap current line with the next',
    body = 'dd deletes the line, p pastes it below — ddp in one go swaps lines\nNo need to navigate between the two lines',
    example = 'ddp → current line moves down one',
  },

  -- j repeat → count prefix
  ['{n}j'] = {
    cmd = '{n}j',
    trigger = 'j',
    title = '{n}j — jump multiple lines at once',
    body = 'Prefix any motion with a count to repeat it\n5j moves down 5 lines; also works with k, w, b, etc.',
    example = '5j → moves down 5 lines',
  },

  -- 0 then w → ^
  ['^'] = {
    cmd = '^',
    trigger = '0',
    title = '^ — jump to first non-blank character',
    body = '0 goes to column 0; ^ goes to the first non-whitespace\nUsually ^ is what you actually want',
    example = '    hello → ^ → cursor on h',
  },

  -- n repeat after search → cgn
  ['cgn'] = {
    cmd = 'cgn',
    trigger = 'n',
    title = 'cgn — change next search match',
    body = 'After /, use cgn to change the next match\nThen press . to repeat on every subsequent match',
    example = '/word → cgn → new → Esc → . . .',
  },
}

M.adjacency = {
  ['f'] = { ';', ',' },
  ['F'] = { ';', ',' },
  ['dw'] = { 'cw', 'ciw' },
  ['dd'] = { 'ddp', 'dip', 'cc' },
  ['u'] = { '<C-r>' },
  ['j'] = { '{n}j', '<C-d>' },
  ['0'] = { '^' },
  ['/'] = { 'gn', 'cgn', '*' },
  ['n'] = { 'cgn', 'gn' },
  ['p'] = { 'P', '"0p' },
  ['x'] = { 's', 'r', '{n}x' },
}

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
