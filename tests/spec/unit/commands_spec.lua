local commands = require('tobira.commands')

-- The registry is the single source of truth for all teachable commands.
-- These tests act as a schema guard: a malformed entry fails CI before reaching users.

describe('the command registry', function()
  it('is not empty', function()
    local count = 0
    for _ in pairs(commands.registry) do
      count = count + 1
    end
    assert.is_true(count > 0)
  end)
end)

describe('every suggestion entry in the registry', function()
  it('declares a requires field', function()
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound then
        assert.is_string(entry.requires, cmd .. ': missing requires')
        assert.is_true(#entry.requires > 0, cmd .. ': empty requires')
      end
    end
  end)

  it('requires field points to a single char or another registry entry', function()
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound and entry.requires then
        local req = entry.requires
        local is_single_char = #req == 1
        local is_in_registry = commands.registry[req] ~= nil
        assert.is_true(
          is_single_char or is_in_registry,
          cmd .. ': requires "' .. req .. '" is neither a single char nor in the registry'
        )
      end
    end
  end)
end)

-- Display strings belong in locale files, not in commands.lua.
-- These tests act as a sync guard: adding a registry entry without locale strings fails CI.
describe('locale coverage', function()
  local en = require('tobira.locales.en')
  local ja = require('tobira.locales.ja')

  it('every suggestion in the registry has title / body / example in en.lua', function()
    local sug_loc = en.suggestions or {}
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound then
        local str = sug_loc[cmd]
        assert.is_not_nil(str, cmd .. ': missing entry in en.lua .suggestions')
        assert.is_string(str.title, cmd .. ': en.lua missing title')
        assert.is_true(#str.title > 0, cmd .. ': en.lua title is empty')
        assert.is_string(str.body, cmd .. ': en.lua missing body')
        assert.is_true(#str.body > 0, cmd .. ': en.lua body is empty')
        assert.is_string(str.example, cmd .. ': en.lua missing example')
        assert.is_true(#str.example > 0, cmd .. ': en.lua example is empty')
      end
    end
  end)

  it('every en.lua suggestion also has title and body in ja.lua', function()
    local en_sug = en.suggestions or {}
    local ja_sug = ja.suggestions or {}
    for cmd in pairs(en_sug) do
      local str = ja_sug[cmd]
      assert.is_not_nil(str, cmd .. ': missing entry in ja.lua .suggestions')
      assert.is_string(str.title, cmd .. ': ja.lua missing title')
      assert.is_true(#str.title > 0, cmd .. ': ja.lua title is empty')
      assert.is_string(str.body, cmd .. ': ja.lua missing body')
      assert.is_true(#str.body > 0, cmd .. ': ja.lua body is empty')
    end
  end)
end)

describe('every non-compound entry in the registry', function()
  it('has a category field (motion | edit | search)', function()
    local valid = { motion = true, edit = true, search = true }
    for cmd, entry in pairs(commands.registry) do
      if not entry.compound then
        assert.is_not_nil(
          valid[entry.category],
          cmd .. ': missing or invalid category (got ' .. tostring(entry.category) .. ')'
        )
      end
    end
  end)

  it('has a level field (beginner | intermediate | advanced) on every suggestable entry', function()
    local valid_levels = { beginner = true, intermediate = true, advanced = true }
    for cmd, entry in pairs(commands.registry) do
      if entry.requires then
        assert.is_not_nil(entry.level, cmd .. ': missing level field')
        assert.is_true(
          valid_levels[entry.level] == true,
          cmd .. ': invalid level "' .. tostring(entry.level) .. '"'
        )
      end
    end
  end)
end)

describe('the f → ; → , learning progression', function()
  it('; requires f', function()
    assert.equals('f', commands.registry[';'].requires)
  end)

  it(', requires ; (comes after learning ;)', function()
    assert.equals(';', commands.registry[','].requires)
  end)
end)

describe('the dw → cw / ciw teaching chain', function()
  it('cw and ciw both require dw', function()
    assert.equals('dw', commands.registry['cw'].requires)
    assert.equals('dw', commands.registry['ciw'].requires)
  end)

  it('dw is registered as a compound operator', function()
    assert.is_not_nil(commands.registry['dw'])
    assert.is_true(commands.registry['dw'].compound)
  end)
end)

describe('the cw → . (dot repeat) teaching chain', function()
  it('. requires cw (so dot-repeat is offered once the user knows cw)', function()
    assert.equals('cw', commands.registry['.'].requires)
  end)
end)

describe('the a / o insert continuations', function()
  it('A requires a', function()
    assert.equals('a', commands.registry['A'].requires)
  end)

  it('O requires o', function()
    assert.equals('o', commands.registry['O'].requires)
  end)
end)

describe('the x → D → C deletion chain', function()
  it('D requires x', function()
    assert.equals('x', commands.registry['D'].requires)
  end)

  it('C requires D (two-step chain: x → D → C)', function()
    assert.equals('D', commands.registry['C'].requires)
  end)

  it('dd is registered as a compound operator', function()
    assert.is_not_nil(commands.registry['dd'])
    assert.is_true(commands.registry['dd'].compound)
  end)
end)

describe('the * → gn search-and-change chain', function()
  it('gn requires *', function()
    assert.equals('*', commands.registry['gn'].requires)
  end)
end)

describe('the w → e word-end chain', function()
  it('e requires w (word-end forward is the next step after word-jump)', function()
    assert.equals('w', commands.registry['e'].requires)
  end)
end)

describe('the i → I / a → A line-edge insert chain', function()
  it('I requires i (insert at line start, complement of A)', function()
    assert.equals('i', commands.registry['I'].requires)
  end)
end)

describe('the G → H → M → L screen-navigation chain', function()
  it('H requires G (jump to screen top once the user knows file-end jumps)', function()
    assert.equals('G', commands.registry['H'].requires)
  end)

  it('M requires H (screen middle once the user knows screen top)', function()
    assert.equals('H', commands.registry['M'].requires)
  end)

  it('L requires M (screen bottom once the user knows screen middle)', function()
    assert.equals('M', commands.registry['L'].requires)
  end)
end)

describe('the x → {n}x count-prefix chain', function()
  it('{n}x requires x (multi-delete once the user hammers x)', function()
    assert.equals('x', commands.registry['{n}x'].requires)
  end)
end)

describe('the j → <C-d> → <C-u> scroll chain', function()
  it('<C-d> requires j (half-page scroll replaces many j presses)', function()
    assert.equals('j', commands.registry['<C-d>'].requires)
  end)

  it('<C-u> requires <C-d> (scroll back once the user knows scroll forward)', function()
    assert.equals('<C-d>', commands.registry['<C-u>'].requires)
  end)
end)
