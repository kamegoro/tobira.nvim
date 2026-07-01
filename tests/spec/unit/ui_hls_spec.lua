local hls = require('tobira.ui.hls')

-- Helper: run fn() with mocked hlexists + notify, restore unconditionally.
local function with_notify_present(fn)
  local orig_hlexists = vim.fn.hlexists
  vim.fn.hlexists = function(name)
    if name == 'TobiraGuideBorder' then
      return 0
    end
    if name == 'NotifyINFOBorder' then
      return 1
    end
    return orig_hlexists(name)
  end
  package.loaded['notify'] = {}
  local ok, err = pcall(fn)
  vim.fn.hlexists = orig_hlexists
  package.loaded['notify'] = nil
  assert.is_true(ok, err)
end

describe('when nvim-notify highlight groups are available', function()
  it('links TobiraGuideBorder to NotifyINFOBorder', function()
    with_notify_present(function()
      hls.setup()
    end)
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraGuideBorder', link = true })
    assert.equals('NotifyINFOBorder', hl.link)
  end)
end)
