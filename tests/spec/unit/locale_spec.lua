-- Structural sync guard between en.lua and every other locale file.
-- Prevents adding a new key to en.lua without updating the other locales,
-- and prevents a locale branch left open across a large refactor from
-- silently drifting out of sync (as happened during a past French-locale review).

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

-- Recursively verify that every leaf string-key entry in other_tbl also
-- exists in en_tbl. This is the reverse direction of assert_strings_match:
-- it catches orphaned keys — e.g. a leftover translation key from a removed
-- feature, or a typo'd key name that silently never gets read because the
-- real code reads a different key name. Arrays (numeric keys) are skipped,
-- matching assert_strings_match's convention.
local function assert_no_orphan_keys(en_tbl, other_tbl, path, locale_name)
  locale_name = locale_name or 'the other locale'
  for k, v in pairs(other_tbl) do
    if type(k) == 'string' then
      local full = path .. '.' .. tostring(k)
      local en_val = en_tbl and en_tbl[k]
      if type(v) == 'string' then
        assert.is_not_nil(en_val, full .. ': orphaned key in ' .. locale_name .. ' (not present in en.lua)')
      elseif type(v) == 'table' then
        assert_no_orphan_keys(en_val or {}, v, full, locale_name)
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

-- ── assert_no_orphan_keys self-test ──────────────────────────────────────────
-- Proves the reverse-direction checker actually detects an orphaned key
-- (one that exists in a locale but not in en.lua), independent of whatever
-- state the real locale files happen to be in right now.

describe('assert_no_orphan_keys (the orphan-check helper)', function()
  it('fails when a locale has a top-level key the reference does not have', function()
    local reference = { a = 'hello' }
    local orphaned = { a = 'bonjour', b = 'stray' }
    local ok = pcall(assert_no_orphan_keys, reference, orphaned, 'test', 'orphaned')
    assert.is_false(ok, 'expected assert_no_orphan_keys to fail on an orphaned top-level key')
  end)

  it('fails when a locale has a nested key the reference does not have', function()
    local reference = { nested = { a = 'hello' } }
    local orphaned = { nested = { a = 'bonjour', b = 'stray' } }
    local ok = pcall(assert_no_orphan_keys, reference, orphaned, 'test', 'orphaned')
    assert.is_false(ok, 'expected assert_no_orphan_keys to fail on an orphaned nested key')
  end)

  it('passes when every key in the locale also exists in the reference', function()
    local reference = { a = 'hello', nested = { b = 'world' } }
    local complete = { a = 'bonjour', nested = { b = 'monde' } }
    local ok = pcall(assert_no_orphan_keys, reference, complete, 'test', 'complete')
    assert.is_true(ok, 'expected assert_no_orphan_keys to pass when no orphan keys exist')
  end)
end)

-- ── dynamic multi-locale sync guard ──────────────────────────────────────────
-- Discovers every locale file next to en.lua and checks each one's entire
-- table recursively (not just the hand-picked sections below).
-- see docs/adr/0094-locale-spec-dynamic-locale-discovery.md for why

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

    it('has no orphaned keys not present in en.lua, fully recursively, in ' .. name .. '.lua', function()
      local loc = require('tobira.locales.' .. name)
      assert_no_orphan_keys(en, loc, name, name .. '.lua')
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
  --
  -- Generalized across every dynamically-discovered locale — this used
  -- to hardcode only en/ja, which meant a locale with a missing/wrong
  -- separator in a newly added suggestion could ship undetected.
  local locale_names = discover_locale_names()

  it('every en.lua suggestion title contains the " — " separator', function()
    for cmd, entry in pairs(en.suggestions) do
      assert.is_not_nil(entry.title:find(' — ', 1, true), cmd .. ': title missing " — " separator')
    end
  end)

  for _, name in ipairs(locale_names) do
    it('every ' .. name .. '.lua suggestion title contains the " — " separator', function()
      local loc = require('tobira.locales.' .. name)
      for cmd, entry in pairs(loc.suggestions) do
        assert.is_not_nil(entry.title:find(' — ', 1, true), cmd .. ': title missing " — " separator in ' .. name .. '.lua')
      end
    end)
  end
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
  -- Mirrors the pattern names patterns.lua and patterns_insert.lua can fire
  -- (patterns_spec.lua and patterns_insert_spec.lua test each individually).
  -- Kept as an explicit list so a new pattern with no reason text is caught
  -- here instead of silently falling back at display time.
  local all_patterns = {
    'b_repeat',
    'c_dollar',
    'ca_run',
    'changelist_return',
    'ci_dquote_repeat',
    'ci_squote_repeat',
    'cmdline_history_recall',
    'ctrl_w_close_repeat',
    'ctrl_w_resize_repeat',
    'cursor_center_repeat',
    'cx_run',
    'd_dollar',
    'D_then_insert',
    'dd_run',
    'dd_then_insert',
    'dd_then_p',
    'dedent_run',
    'diff_jump_then_insert_next',
    'diff_jump_then_insert_prev',
    'diw_then_insert',
    'dollar_then_append',
    'dot_repeat',
    'dw_then_insert',
    'f_repeat',
    'fold_close_repeat',
    'fold_open_repeat',
    'gq_then_jumpback',
    'h_repeat',
    'indent_run',
    'insert_bounce',
    'insert_bs_repeat',
    'insert_co_oneshot',
    'insert_completion_repeat',
    'insert_left_repeat',
    'insert_right_repeat',
    'j_many',
    'j_repeat',
    'J_repeat',
    'jump_back',
    'k_many',
    'k_repeat',
    'k_then_o',
    'l_repeat',
    'macro_opportunity',
    'manual_return',
    'n_repeat',
    'named_mark_opportunity',
    'p_repeat',
    'P_repeat',
    'p_then_rightward',
    'P_then_rightward',
    'r_run',
    'tilde_line_repeat',
    'tilde_repeat',
    'tilde_word_repeat',
    'u_repeat',
    'v_repeat',
    'visual_block_opportunity',
    'visual_textobj',
    'w_repeat',
    'x_repeat',
    'x_then_insert',
    'yy_then_p',
    'zero_col_then_insert',
    'zero_then_insert',
    'zero_then_w',
  }

  it('has a non-empty reason string in en.lua for every pattern patterns.lua/patterns_insert.lua can fire', function()
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

-- ── UI redesign foundation ──────────────────────────────────────────────────
-- These keys aren't wired to any UI module yet, but must exist and stay in
-- sync in both locales from the start.

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
  -- Generalized across every dynamically-discovered locale — this used
  -- to hardcode only en/ja.
  local locale_names = discover_locale_names()

  it('is a non-empty string containing a %d placeholder in en.lua', function()
    assert.is_string(en.guide.more_suffix)
    assert.is_not_nil(en.guide.more_suffix:find('%d', 1, true))
  end)

  for _, name in ipairs(locale_names) do
    it('is a non-empty string containing a %d placeholder in ' .. name .. '.lua', function()
      local loc = require('tobira.locales.' .. name)
      assert.is_string(loc.guide.more_suffix)
      assert.is_not_nil(loc.guide.more_suffix:find('%d', 1, true))
    end)
  end
end)

describe('guide.remapped_suffix (#63)', function()
  -- Generalized across every dynamically-discovered locale — this used
  -- to hardcode only en/ja.
  local locale_names = discover_locale_names()

  it('is a non-empty string containing a %s placeholder in en.lua', function()
    assert.is_string(en.guide.remapped_suffix)
    assert.is_not_nil(en.guide.remapped_suffix:find('%s', 1, true))
  end)

  for _, name in ipairs(locale_names) do
    it('is a non-empty string containing a %s placeholder in ' .. name .. '.lua', function()
      local loc = require('tobira.locales.' .. name)
      assert.is_string(loc.guide.remapped_suffix)
      assert.is_not_nil(loc.guide.remapped_suffix:find('%s', 1, true))
    end)
  end
end)

describe('notifications.remap_detected (#63)', function()
  -- Generalized across every dynamically-discovered locale — this used
  -- to hardcode only en/ja.
  local locale_names = discover_locale_names()

  it('is a non-empty string containing two %s placeholders in en.lua', function()
    assert.is_string(en.notifications.remap_detected)
    assert.equals(2, select(2, en.notifications.remap_detected:gsub('%%s', '')))
  end)

  for _, name in ipairs(locale_names) do
    it('is a non-empty string containing two %s placeholders in ' .. name .. '.lua', function()
      local loc = require('tobira.locales.' .. name)
      assert.is_string(loc.notifications.remap_detected)
      assert.equals(2, select(2, loc.notifications.remap_detected:gsub('%%s', '')))
    end)
  end
end)

-- ── format-string placeholder SEQUENCE guard, across every locale ───────────
-- Lua's string.format binds arguments positionally, so matching placeholder
-- *counts* isn't enough — order must match too (ja.lua's
-- progress.preview.to_next once shipped with the right count but wrong
-- order). Keys to check are discovered by walking en.lua for any leaf string
-- containing %s or %d, mirroring discover_locale_names()'s rationale (see
-- locales/CLAUDE.md).
describe('format-string placeholder sequence matches en.lua, across every locale', function()
  local locale_names = discover_locale_names()

  -- '%d more to reach %s' -> {'d', 's'}
  local function specifier_sequence(str)
    local seq = {}
    for spec in str:gmatch('%%([sd])') do
      table.insert(seq, spec)
    end
    return seq
  end

  local function collect_format_keys(tbl, path, out)
    for k, v in pairs(tbl) do
      if type(k) == 'string' then
        local full = path == '' and k or (path .. '.' .. k)
        if type(v) == 'string' then
          if v:find('%%[sd]') then
            out[full] = specifier_sequence(v)
          end
        elseif type(v) == 'table' then
          collect_format_keys(v, full, out)
        end
      end
    end
  end

  local function get_by_path(tbl, path)
    local cur = tbl
    for part in path:gmatch('[^.]+') do
      if type(cur) ~= 'table' then
        return nil
      end
      cur = cur[part]
    end
    return cur
  end

  local en_format_keys = {}
  collect_format_keys(en, '', en_format_keys)

  it('discovers at least progress.preview.to_next (sanity check that discovery itself works)', function()
    assert.is_not_nil(en_format_keys['progress.preview.to_next'], 'expected to discover progress.preview.to_next in en.lua')
  end)

  for path, expected_seq in pairs(en_format_keys) do
    for _, name in ipairs(locale_names) do
      it(path .. ' has the same %s/%d placeholder sequence in ' .. name .. '.lua as en.lua', function()
        local loc = require('tobira.locales.' .. name)
        local val = get_by_path(loc, path)
        assert.is_string(val, path .. ': missing or not a string in ' .. name .. '.lua')
        local actual_seq = specifier_sequence(val)
        assert.same(
          expected_seq,
          actual_seq,
          path
            .. ': placeholder sequence mismatch in '
            .. name
            .. '.lua (expected %'
            .. table.concat(expected_seq, ', %')
            .. ' got %'
            .. table.concat(actual_seq, ', %')
            .. ')'
        )
      end)
    end
  end
end)
