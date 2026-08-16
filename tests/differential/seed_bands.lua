-- Guards tests/differential/*_differential_spec.lua's internal seed-offset bands (issue
-- #346) against silent collision.
--
-- Several *_differential_spec.lua files run more than one seed loop within the same file
-- (to keep each loop's internal generator state independent of the others), and give each
-- loop its own additive offset off BASE_SEED — e.g.
-- patterns_seq_differential_spec.lua uses BASE_SEED+i, BASE_SEED+100000+i,
-- BASE_SEED+200000+i, BASE_SEED+300000+i. Each loop iterates SEED_COUNT times, so a band
-- starting at `offset` actually covers the range [offset+1, offset+SEED_COUNT]. If
-- SEED_COUNT ever exceeds the gap between two offsets, one band's range grows into the
-- next band's territory and both loops start re-running (part of) the same seeds — a
-- silent reduction in effective coverage, not a crash, so nothing would otherwise surface
-- it.
--
-- Pure and dependency-free (no vim.*) so it can be unit-tested directly with a fake seed
-- count instead of only being reachable by an actual large-scale run — see
-- tests/spec/unit/seed_bands_spec.lua.
local M = {}

-- Returns the smallest gap between any two of the given offsets, or nil if there is only
-- one offset (a single-band file can never collide with itself).
function M.smallest_gap(offsets)
  local sorted = {}
  for i, offset in ipairs(offsets) do
    sorted[i] = offset
  end
  table.sort(sorted)

  local min_gap = nil
  for i = 2, #sorted do
    local gap = sorted[i] - sorted[i - 1]
    if min_gap == nil or gap < min_gap then
      min_gap = gap
    end
  end
  return min_gap
end

-- Fails loudly (error(), not a silent no-op or clamp) if seed_count is large enough that
-- this file's own seed-offset bands would overlap. Call once, right after computing
-- SEED_COUNT, from every *_differential_spec.lua file that uses more than one band —
-- pass every offset that file's own seed loops actually use (including 0).
function M.assert_no_band_collision(seed_count, offsets)
  local gap = M.smallest_gap(offsets)
  if gap == nil or seed_count <= gap then
    return
  end

  local offset_parts = {}
  for i, offset in ipairs(offsets) do
    offset_parts[i] = tostring(offset)
  end

  error(
    string.format(
      "TOBIRA_DIFFERENTIAL_SEEDS=%d is unsafe for this file's seed-offset bands {%s} "
        .. "(smallest gap between bands is %d) - at this scale, one band's seed range would "
        .. "overlap the next band's, silently re-running the same seeds instead of covering "
        .. 'new ones. Lower TOBIRA_DIFFERENTIAL_SEEDS or widen the offsets (issue #346).',
      seed_count,
      table.concat(offset_parts, ', '),
      gap
    ),
    2
  )
end

return M
