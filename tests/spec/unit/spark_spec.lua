local spark = require('tobira.ui.spark')

describe('when sessions is empty', function()
  it('renders a blank string padded to width', function()
    assert.equals('     ', spark.render({}, 5))
  end)
end)

describe('when every session in the visible window is zero', function()
  it('renders the baseline bar for each entry, not blank', function()
    local rendered = spark.render({ 0, 0, 0 }, 3)
    assert.equals('▁▁▁', rendered)
  end)
end)

describe('when sessions has a single value', function()
  it('renders that value as the tallest bar (scaled to its own max)', function()
    local rendered = spark.render({ 7 }, 1)
    assert.equals('█', rendered)
  end)
end)

describe('when sessions has mixed values', function()
  it('scales each bar relative to the max in the visible window', function()
    -- max = 8 -> 8 itself is the tallest bar (█), 0 is the baseline (▁),
    -- 4 is roughly the midpoint.
    local rendered = spark.render({ 0, 4, 8 }, 3)
    assert.equals(3, vim.fn.strchars(rendered))
    assert.equals('▁', vim.fn.strcharpart(rendered, 0, 1))
    assert.equals('█', vim.fn.strcharpart(rendered, 2, 1))
  end)

  it('scales to the local max of the visible window, not a global max', function()
    -- Only the last 2 entries are visible (width=2): 2 and 4. The earlier 100
    -- must not flatten these into near-zero bars.
    local rendered = spark.render({ 100, 2, 4 }, 2)
    assert.equals(2, vim.fn.strchars(rendered))
    assert.not_equals(vim.fn.strcharpart(rendered, 0, 1), vim.fn.strcharpart(rendered, 1, 1))
  end)
end)

describe('when sessions has fewer entries than the requested width', function()
  it('renders only the available entries without padding gaps between them', function()
    local rendered = spark.render({ 5 }, 5)
    assert.equals(1, vim.fn.strchars(rendered))
  end)
end)

describe('boundary widths', function()
  it('handles width = 1', function()
    local rendered = spark.render({ 3, 6, 9 }, 1)
    assert.equals(1, vim.fn.strchars(rendered))
    assert.equals('█', rendered) -- only the last entry (9) is visible, scaled to itself
  end)

  it('handles width = 20 with fewer sessions than the window', function()
    local rendered = spark.render({ 1, 2, 3 }, 20)
    assert.equals(3, vim.fn.strchars(rendered))
  end)

  it('handles width = 20 with more sessions than the window', function()
    local sessions = {}
    for i = 1, 30 do
      sessions[i] = i
    end
    local rendered = spark.render(sessions, 20)
    assert.equals(20, vim.fn.strchars(rendered))
    -- last entry (30) is the max of the visible window -> tallest bar
    assert.equals('█', vim.fn.strcharpart(rendered, 19, 1))
  end)
end)
