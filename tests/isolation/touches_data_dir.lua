-- Not a *_spec.lua file on purpose: only test_isolation_spec.lua runs it,
-- through PlenaryBustedFile without minimal_init, to prove a spec launched
-- that way still cannot reach the real data dir.
require('tests.isolate_data')

local logger = require('tobira.core.logger')

describe('a spec launched without tests/minimal_init.lua', function()
  it('removes and rewrites usage.json the way logger specs do', function()
    os.remove(logger.data_file())
    logger.reset()
    logger.mark_shown('j')
    assert.is_not_nil(io.open(logger.data_file(), 'r'))
  end)
end)
