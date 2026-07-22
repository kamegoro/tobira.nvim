-- Structural sync guard between en.lua and every other locale file.
-- Prevents adding a new key to en.lua without updating the other locales,
-- and prevents a locale branch left open across a large refactor from
-- silently drifting out of sync (see #73's French-locale review).

local en = require('tobira.locales.en')
local ja = require('tobira.locales.ja')

-- Recursively verify that all leaf string values in en_tbl exist and are
-- non-empty in other_tbl. Arrays (numeric keys) are skipped.
local function assert_strings_match(en_tbl, other_tbl, path, locale_name)
  locale_name = locale_name or 'the other locale'
  for k, v in pairs(en_tbl) do
    if type(k) == 'string' then
      local full = path .. '.' .. tostring(k)
      if type(v) == 'string' then
        local other_val = other_tbl and other_tbl[k]
        assert.is_not_nil(other_val, full .. ': missing from ' .. locale_name)
        assert.is_string(other_val, full .. ': must be a string in ' .. locale_name)
        assert.is_true(#other_val > 0, full .. ': must not be empty in ' .. locale_name)
      elseif type(v) == 'table' then
        assert_strings_match(v, other_tbl and other_tbl[k] or {}, full, locale_name)
      end
    end
  end
end

-- ── assert_strings_match self-test ───────────────────────────────────────────
-- Proves the checker itself actually detects drift, independent of whatever
-- state the real locale files happen to be in right now.

describe('assert_strings_match (the sync-check helper)', function()
  it('fails when a locale is missing a key the reference has', function()
    local reference = { a = 'hello', nested = { b = 'world' } }
    local incomplete = { a = 'bonjour' } -- nested.b missing
    local ok = pcall(assert_strings_match, reference, incomplete, 'test', 'incomplete')
    assert.is_false(ok, 'expected assert_strings_match to fail on a missing nested key')
  end)

  it('fails when a locale has an empty string for a key the reference has', function()
    local reference = { a = 'hello' }
    local blank = { a = '' }
    local ok = pcall(assert_strings_match, reference, blank, 'test', 'blank')
    assert.is_false(ok, 'expected assert_strings_match to fail on an empty translation')
  end)

  it('passes when every key is present and non-empty', function()
    local reference = { a = 'hello', nested = { b = 'world' } }
    local complete = { a = 'bonjour', nested = { b = 'monde' } }
    local ok = pcall(assert_strings_match, reference, complete, 'test', 'complete')
    assert.is_true(ok, 'expected assert_strings_match to pass when all keys are present')
  end)
end)

-- ── dynamic multi-locale sync guard ──────────────────────────────────────────
-- Discovers every locale file next to en.lua (ja.lua today, fr.lua/es.lua/...
-- whenever they land) and checks each one's ENTIRE table against en.lua
-- recursively — including `suggestions` (148 commands) and `float.reasons`
-- (34 patterns), which the older hand-picked per-section checks below never
-- covered. A new locale is covered automatically; nothing to remember to add.

local function discover_locale_names()
  local names = {}
  for _, filename in ipairs(vim.fn.readdir('lua/tobira/locales')) do
    local name = filename:match('^(%a+)%.lua$')
    if name and name ~= 'en' then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

describe('every locale file next to en.lua', function()
  local locale_names = discover_locale_names()

  it('discovers at least ja.lua (sanity check that discovery itself works)', function()
    local found_ja = false
    for _, name in ipairs(locale_names) do
      if name == 'ja' then
        found_ja = true
      end
    end
    assert.is_true(found_ja, 'expected discover_locale_names() to find ja.lua')
  end)

  for _, name in ipairs(locale_names) do
    it('has every en.lua key, fully recursively, present and non-empty in ' .. name .. '.lua', function()
      local loc = require('tobira.locales.' .. name)
      assert_strings_match(en, loc, name, name .. '.lua')
    end)
  end
end)

describe('progress locale', function()
  it('has a level_label key (for the Level: banner)', function()
    assert.is_string(en.progress.level_label, 'en.lua progress.level_label missing')
    assert.is_true(#en.progress.level_label > 0, 'en.lua progress.level_label is empty')
    assert.is_string(ja.progress.level_label, 'ja.lua progress.level_label missing')
    assert.is_true(#ja.progress.level_label > 0, 'ja.lua progress.level_label is empty')
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
    'b_repeat',
    'c_dollar',
    'd_dollar',
    'D_then_insert',
    'dd_run',
    'dd_then_insert',
    'dd_then_p',
    'dedent_run',
    'dollar_then_append',
    'dot_repeat',
    'dw_then_insert',
    'f_repeat',
    'gq_then_jumpback',
    'h_repeat',
    'indent_run',
    'j_many',
    'j_repeat',
    'J_repeat',
    'k_many',
    'k_repeat',
    'k_then_o',
    'l_repeat',
    'n_repeat',
    'p_repeat',
    'P_repeat',
    'r_run',
    'tilde_repeat',
    'u_repeat',
    'visual_textobj',
    'w_repeat',
    'x_repeat',
    'x_then_insert',
    'yy_then_p',
    'zero_col_then_insert',
    'zero_then_insert',
    'zero_then_w',
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
end)

-- ── UI redesign foundation (#66) ─────────────────────────────────────────────
-- These keys aren't wired to any UI module yet (that happens in #67/#68/#74),
-- but must exist and stay in sync in both locales from the start.

describe('progress.mastered_total / section_count / preview / footer', function()
  it('are defined as non-empty strings in both locales', function()
    assert.is_string(en.progress.mastered_total)
    assert.is_true(#en.progress.mastered_total > 0)
    assert.is_string(ja.progress.mastered_total)
    assert.is_true(#ja.progress.mastered_total > 0)

    assert.is_string(en.progress.section_count)
    assert.is_string(ja.progress.section_count)
  end)

  it('footer has a non-empty label for every keybinding in both locales', function()
    local keys = { 'suppress', 'pin', 'guide', 'stats', 'close' }
    for _, k in ipairs(keys) do
      assert.is_string(en.progress.footer[k], 'en.lua progress.footer.' .. k .. ' missing')
      assert.is_true(#en.progress.footer[k] > 0)
      assert.is_string(ja.progress.footer[k], 'ja.lua progress.footer.' .. k .. ' missing')
      assert.is_true(#ja.progress.footer[k] > 0)
    end
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
end)

describe('stats.footer', function()
  it('has a non-empty label for every keybinding in both locales', function()
    local keys = { 'guide', 'progress', 'close' }
    for _, k in ipairs(keys) do
      assert.is_string(en.stats.footer[k], 'en.lua stats.footer.' .. k .. ' missing')
      assert.is_true(#en.stats.footer[k] > 0)
      assert.is_string(ja.stats.footer[k], 'ja.lua stats.footer.' .. k .. ' missing')
      assert.is_true(#ja.stats.footer[k] > 0)
    end
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

describe('guide.more_suffix (#96)', function()
  it('is a non-empty string containing a %d placeholder in both locales', function()
    assert.is_string(en.guide.more_suffix)
    assert.is_not_nil(en.guide.more_suffix:find('%d', 1, true))
    assert.is_string(ja.guide.more_suffix)
    assert.is_not_nil(ja.guide.more_suffix:find('%d', 1, true))
  end)
end)
