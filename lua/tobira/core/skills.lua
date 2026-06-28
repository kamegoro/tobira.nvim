local M = {}

-- Each item has one of:
--   track + threshold : sum of usage counts for listed keys must reach threshold
--   adopted           : usage[cmd].adopted == true (command was suggested and used)
M.tree = {
  {
    id = 'motion',
    items = {
      { id = 'hjkl', keys = 'hjkl', track = { 'h', 'j', 'k', 'l' }, threshold = 10 },
      { id = 'wb', keys = 'w/b', track = { 'w', 'b' }, threshold = 5 },
      { id = 'gg', keys = 'gg/G', track = { 'g', 'G' }, threshold = 3 },
      { id = 'ft', keys = 'f/t', track = { 'f', 'F' }, threshold = 3 },
      { id = 'semi', keys = ';/,', track = { ';', ',' }, threshold = 2 },
      { id = 'ctrldu', keys = '<C-d>/<C-u>', adopted = '<C-d>' },
    },
  },
  {
    id = 'edit',
    items = {
      { id = 'insert', keys = 'i/a/o', track = { 'i', 'a', 'o' }, threshold = 5 },
      { id = 'delete', keys = 'x/dd', track = { 'x' }, threshold = 3 },
      { id = 'yank', keys = 'yy/p', track = { 'p' }, threshold = 2 },
      { id = 'undo', keys = 'u/<C-r>', track = { 'u' }, threshold = 2 },
      { id = 'cw', keys = 'cw/ciw', adopted = 'cw' },
      { id = 'visual', keys = 'v/V', track = { 'v' }, threshold = 2 },
    },
  },
  {
    id = 'search',
    items = {
      { id = 'search', keys = '/+n', track = { 'n' }, threshold = 2 },
      { id = 'star', keys = '*/#', track = { '*' }, threshold = 1 },
      { id = 'cgn', keys = 'cgn', adopted = 'cgn' },
    },
  },
}

function M.is_learned(item, usage)
  if item.adopted then
    local d = usage[item.adopted]
    return d ~= nil and (d.adopted == true or d.count > 0)
  end
  if not item.track or not item.threshold then
    return false
  end
  local total = 0
  for _, k in ipairs(item.track) do
    total = total + ((usage[k] and usage[k].count) or 0)
  end
  return total >= item.threshold
end

return M
