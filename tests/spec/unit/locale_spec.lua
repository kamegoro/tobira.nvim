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

describe('suggestion title format', function()
  -- ui/float.lua splits "cmd — description" to highlight the answer key
  -- separately from its explanation. Every suggestion title must follow this
  -- exact separator so that split never has to fall back.
  it('every en.lua suggestion title contains the " — " separator', function()
    for cmd, entry in pairs(en.suggestions) do
      assert.is_not_nil(entry.title:find(' — ', 1, true), cmd .. ': title missing " — " separator')
    end
  end)

  it('every ja.lua suggestion title contains the " — " separator', function()
    for cmd, entry in pairs(ja.suggestions) do
      assert.is_not_nil(entry.title:find(' — ', 1, true), cmd .. ': title missing " — " separator')
    end
  end)
end)

describe('float.celebrate template', function()
  it('is defined as a non-empty string in both en.lua and ja.lua', function()
    assert.is_string(en.float.celebrate)
    assert.is_true(#en.float.celebrate > 0)
    assert.is_string(ja.float.celebrate)
    assert.is_true(#ja.float.celebrate > 0)
  end)
end)

describe('float.reasons locale', function()
  -- Mirrors the pattern names patterns.lua can fire (patterns_spec.lua tests each
  -- individually). Kept as an explicit list so a new pattern with no reason text
  -- is caught here instead of silently falling back at display time.
  local all_patterns = {
    'b_repeat', 'c_dollar', 'd_dollar', 'D_then_insert', 'dd_run', 'dd_then_insert',
    'dd_then_p', 'dedent_run', 'dollar_then_append', 'dot_repeat', 'dw_then_insert',
    'f_repeat', 'h_repeat', 'indent_run', 'j_many', 'j_repeat', 'J_repeat', 'k_many',
    'k_repeat', 'k_then_o', 'l_repeat', 'n_repeat', 'p_repeat', 'P_repeat', 'r_run',
    'tilde_repeat', 'u_repeat', 'visual_textobj', 'w_repeat', 'x_repeat', 'x_then_insert',
    'yy_then_p', 'zero_then_insert', 'zero_then_w',
  }

  it('has a non-empty reason string in en.lua for every pattern patterns.lua can fire', function()
    for _, pattern in ipairs(all_patterns) do
      local reason = en.float.reasons[pattern]
      assert.is_string(reason, pattern .. ': missing from en.lua float.reasons')
      assert.is_true(#reason > 0, pattern .. ': empty in en.lua float.reasons')
    end
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

  it('en.lua and ja.lua have the same string keys', function()
    assert_strings_match(en.guide, ja.guide, 'guide')
  end)
end)

-- ── UI redesign foundation (#66) ─────────────────────────────────────────────
-- These keys aren't wired to any UI module yet (that happens in #67/#68/#74),
-- but must exist and stay in sync in both locales from the start.

describe('progress.mastered_total / section_count / preview / nav_hint', function()
  it('are defined as non-empty strings in both locales', function()
    assert.is_string(en.progress.mastered_total)
    assert.is_true(#en.progress.mastered_total > 0)
    assert.is_string(ja.progress.mastered_total)
    assert.is_true(#ja.progress.mastered_total > 0)

    assert.is_string(en.progress.section_count)
    assert.is_string(ja.progress.section_count)

    assert.is_string(en.progress.nav_hint)
    assert.is_string(ja.progress.nav_hint)
  end)

  it('preview has learning / mastered / forgotten / never_tried / to_next in both locales', function()
    local keys = { 'learning', 'mastered', 'forgotten', 'never_tried', 'to_next' }
    for _, k in ipairs(keys) do
      assert.is_string(en.progress.preview[k], 'en.lua progress.preview.' .. k .. ' missing')
      assert.is_true(#en.progress.preview[k] > 0)
      assert.is_string(ja.progress.preview[k], 'ja.lua progress.preview.' .. k .. ' missing')
      assert.is_true(#ja.progress.preview[k] > 0)
    end
  end)

  it('en.lua and ja.lua have the same preview keys', function()
    assert_strings_match(en.progress.preview, ja.progress.preview, 'progress.preview')
  end)
end)

describe('stats.nav_hint', function()
  it('is defined as a non-empty string in both locales', function()
    assert.is_string(en.stats.nav_hint)
    assert.is_true(#en.stats.nav_hint > 0)
    assert.is_string(ja.stats.nav_hint)
    assert.is_true(#ja.stats.nav_hint > 0)
  end)
end)

describe('stats.footer_summary', function()
  it('is defined as a non-empty string in both locales', function()
    assert.is_string(en.stats.footer_summary)
    assert.is_true(#en.stats.footer_summary > 0)
    assert.is_string(ja.stats.footer_summary)
    assert.is_true(#ja.stats.footer_summary > 0)
  end)
end)

describe('guide.focus_hint', function()
  it('is defined as a non-empty string in both locales', function()
    assert.is_string(en.guide.focus_hint)
    assert.is_true(#en.guide.focus_hint > 0)
    assert.is_string(ja.guide.focus_hint)
    assert.is_true(#ja.guide.focus_hint > 0)
  end)
end)
