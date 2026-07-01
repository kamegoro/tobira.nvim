-- Structural sync guard between en.lua and ja.lua.
-- For every string key in the "flat" locale sections (progress, notifications,
-- stats, float), ja.lua must have a matching non-empty string value.
-- Prevents adding a new key to en.lua without updating ja.lua.

local en = require('tobira.locales.en')
local ja = require('tobira.locales.ja')

-- Recursively verify that all leaf string values in en_tbl exist and are
-- non-empty in ja_tbl. Arrays (numeric keys) are skipped.
local function assert_strings_match(en_tbl, ja_tbl, path)
  for k, v in pairs(en_tbl) do
    if type(k) == 'string' then
      local full = path .. '.' .. tostring(k)
      if type(v) == 'string' then
        local ja_val = ja_tbl and ja_tbl[k]
        assert.is_not_nil(ja_val, full .. ': missing from ja.lua')
        assert.is_string(ja_val, full .. ': must be a string in ja.lua')
        assert.is_true(#ja_val > 0, full .. ': must not be empty in ja.lua')
      elseif type(v) == 'table' then
        assert_strings_match(v, ja_tbl and ja_tbl[k] or {}, full)
      end
    end
  end
end

describe('progress locale', function()
  it('en.lua and ja.lua have the same string keys', function()
    assert_strings_match(en.progress, ja.progress, 'progress')
  end)

  it('has a level_label key (for the Level: banner)', function()
    assert.is_string(en.progress.level_label, 'en.lua progress.level_label missing')
    assert.is_true(#en.progress.level_label > 0, 'en.lua progress.level_label is empty')
    assert.is_string(ja.progress.level_label, 'ja.lua progress.level_label missing')
    assert.is_true(#ja.progress.level_label > 0, 'ja.lua progress.level_label is empty')
  end)
end)

describe('notifications locale', function()
  it('en.lua and ja.lua have the same string keys', function()
    assert_strings_match(en.notifications, ja.notifications, 'notifications')
  end)
end)

describe('stats locale', function()
  it('en.lua and ja.lua have the same string keys', function()
    assert_strings_match(en.stats, ja.stats, 'stats')
  end)
end)

describe('float locale', function()
  it('en.lua and ja.lua have the same string keys', function()
    assert_strings_match(en.float, ja.float, 'float')
  end)
end)

describe('guide top-level locale', function()
  it('has title and hint in both en.lua and ja.lua', function()
    assert.is_string(en.guide.title)
    assert.is_string(ja.guide.title)
    assert.is_true(#en.guide.title > 0)
    assert.is_true(#ja.guide.title > 0)
    assert.is_string(en.guide.hint)
    assert.is_string(ja.guide.hint)
    assert.is_true(#en.guide.hint > 0)
    assert.is_true(#ja.guide.hint > 0)
  end)
end)
