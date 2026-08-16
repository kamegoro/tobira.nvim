-- Pure unit tests for tests/differential/seed_bands.lua — the guard that fails loudly if
-- TOBIRA_DIFFERENTIAL_SEEDS is set large enough to make a differential spec file's own
-- internal seed-offset bands collide (issue #346).
--
-- The collision-check logic is extracted into this small pure function specifically so it
-- is unit-testable with a fake seed count, rather than only reachable by actually running a
-- 100000+-seed differential suite — tests/CLAUDE.md documents a hard-learned rule that
-- anything under tests/differential/ must stay fast (COVERAGE=1 alone slows that directory
-- by ~2 orders of magnitude), so a test proving this guard fires must not itself run a real
-- large-scale seed loop.

package.path = vim.fn.getcwd() .. '/tests/differential/?.lua;' .. package.path
local seed_bands = require('seed_bands')

describe('seed_bands.smallest_gap', function()
  it('returns nil for a single offset — nothing to collide with', function()
    assert.is_nil(seed_bands.smallest_gap({ 0 }))
  end)

  it('returns the gap between two offsets', function()
    assert.equals(100000, seed_bands.smallest_gap({ 0, 100000 }))
  end)

  it('returns the smallest gap among more than two offsets, regardless of input order', function()
    assert.equals(50000, seed_bands.smallest_gap({ 300000, 0, 350000, 100000 }))
  end)
end)

describe('seed_bands.assert_no_band_collision', function()
  it('does not raise when SEED_COUNT is well under the smallest band gap (committed default, 150)', function()
    assert.has_no.errors(function()
      seed_bands.assert_no_band_collision(150, { 0, 100000, 200000, 300000 })
    end)
  end)

  it('does not raise at the current nightly-stress-job scale (20000)', function()
    assert.has_no.errors(function()
      seed_bands.assert_no_band_collision(20000, { 0, 100000, 200000, 300000 })
    end)
  end)

  it('does not raise one seed below the collision threshold (boundary check)', function()
    assert.has_no.errors(function()
      seed_bands.assert_no_band_collision(99999, { 0, 100000, 200000, 300000 })
    end)
  end)

  it('raises exactly at the point the smallest band gap becomes unsafe (boundary check)', function()
    assert.has_error(function()
      seed_bands.assert_no_band_collision(100000, { 0, 100000, 200000, 300000 })
    end)
  end)

  it('raises when SEED_COUNT is far past the collision threshold', function()
    assert.has_error(function()
      seed_bands.assert_no_band_collision(300000, { 0, 100000, 200000, 300000 })
    end)
  end)

  it('never raises for a single-band file, no matter how large SEED_COUNT is', function()
    assert.has_no.errors(function()
      seed_bands.assert_no_band_collision(999999999, { 0 })
    end)
  end)

  it("derives its own threshold from a two-band file's actual gap, not a hardcoded 100000", function()
    assert.has_no.errors(function()
      seed_bands.assert_no_band_collision(49999, { 0, 50000 })
    end)
    assert.has_error(function()
      seed_bands.assert_no_band_collision(50000, { 0, 50000 })
    end)
  end)

  it('raises with a message naming both the offending SEED_COUNT and the colliding offsets', function()
    local ok, err = pcall(seed_bands.assert_no_band_collision, 100000, { 0, 100000 })
    assert.is_false(ok)
    local message = tostring(err)
    assert.truthy(message:find('100000', 1, true))
  end)
end)
