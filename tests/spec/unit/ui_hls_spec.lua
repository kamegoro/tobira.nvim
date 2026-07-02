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

describe('category highlight groups', function()
  local expected = {
    TobiraSuggestMotion = 'Special',
    TobiraSuggestEdit = 'Function',
    TobiraSuggestSearch = 'String',
    TobiraSuggestWindow = 'Type',
    TobiraSuggestFold = 'Constant',
    TobiraSuggestMark = 'Identifier',
    TobiraSuggestMacro = 'PreProc',
  }

  it('defines a distinct group linked to a standard syntax group for every category', function()
    hls.setup()
    for group, target in pairs(expected) do
      local hl = vim.api.nvim_get_hl(0, { name = group, link = true })
      assert.equals(target, hl.link, group .. ' should link to ' .. target)
    end
  end)
end)

describe('TobiraSuggestKey and TobiraCelebrate highlight groups', function()
  it('defines TobiraSuggestKey', function()
    hls.setup()
    assert.equals(1, vim.fn.hlexists('TobiraSuggestKey'))
  end)

  it('defines TobiraCelebrate linked to DiagnosticOk', function()
    hls.setup()
    local hl = vim.api.nvim_get_hl(0, { name = 'TobiraCelebrate', link = true })
    assert.equals('DiagnosticOk', hl.link)
  end)
end)
