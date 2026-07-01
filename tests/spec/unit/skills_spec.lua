local skills = require('tobira.core.skills')

-- ── auto-generation from commands.registry ────────────────────────────────────

describe('when commands.registry has a command with a category', function()
  it('that command appears in the matching category of skills.tree', function()
    local found = false
    for _, cat in ipairs(skills.tree) do
      if cat.id == 'motion' then
        for _, item in ipairs(cat.items) do
          if item.id == 'e' then
            found = true
          end
        end
      end
    end
    assert.is_true(found, "'e' (category=motion) should appear in skills.tree motion category")
  end)
end)

describe('every non-compound command in commands.registry that has a category', function()
  it('appears in skills.tree', function()
    local commands = require('tobira.commands')
    local in_tree = {}
    for _, cat in ipairs(skills.tree) do
      for _, item in ipairs(cat.items) do
        in_tree[item.id] = true
      end
    end
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.category then
        assert.is_not_nil(in_tree[cmd], cmd .. ' missing from skills.tree')
      end
    end
  end)
end)
