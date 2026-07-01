local commands = require('tobira.commands')

local M = {}

-- Composite milestone items: multi-key groupings tracked by usage count.
-- These cannot be derived from commands.registry because they bundle several
-- keys into a single "have you started using this family of commands?" signal.
local COMPOSITE = {
  motion = {
    { id = 'hjkl', keys = 'hjkl', track = { 'h', 'j', 'k', 'l' }, threshold = 10 },
    { id = 'wb', keys = 'w/b', track = { 'w', 'b' }, threshold = 5 },
    { id = 'gg', keys = 'gg/G', track = { 'g', 'G' }, threshold = 3 },
    { id = 'ft', keys = 'f/t', track = { 'f', 'F' }, threshold = 3 },
  },
  edit = {
    { id = 'insert', keys = 'i/a/o', track = { 'i', 'a', 'o' }, threshold = 5 },
    { id = 'delete', keys = 'x/dd', track = { 'x' }, threshold = 3 },
    { id = 'yank', keys = 'yy/p', track = { 'p' }, threshold = 2 },
    { id = 'undo', keys = 'u/<C-r>', track = { 'u' }, threshold = 2 },
    { id = 'visual', keys = 'v/V', track = { 'v' }, threshold = 2 },
  },
  search = {
    { id = 'search', keys = '/+n', track = { 'n' }, threshold = 2 },
    { id = 'star', keys = '*/#', track = { '*' }, threshold = 1 },
  },
}

-- Build tree: composite milestones first, then one entry per commands.registry
-- command that has a category and is not already covered by a composite item.
local function build_tree()
  local categories = { 'motion', 'edit', 'search', 'window', 'fold', 'mark', 'macro' }
  local result = {}

  for _, cat_id in ipairs(categories) do
    local composite = COMPOSITE[cat_id] or {}
    local covered = {}
    for _, item in ipairs(composite) do
      covered[item.id] = true
    end

    local auto_ids = {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.category == cat_id and not covered[cmd] then
        table.insert(auto_ids, cmd)
      end
    end
    table.sort(auto_ids)

    local items = {}
    for _, item in ipairs(composite) do
      table.insert(items, item)
    end
    for _, cmd in ipairs(auto_ids) do
      table.insert(items, { id = cmd, keys = cmd, adopted = cmd })
    end

    table.insert(result, { id = cat_id, items = items })
  end

  return result
end
M.tree = build_tree()

return M
