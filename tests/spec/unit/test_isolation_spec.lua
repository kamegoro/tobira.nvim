require('tests.isolate_data')

-- Guards against specs reading or deleting the developer's real usage.json.
-- See docs/adr/0092-test-stdpath-data-redirect-ordering.md.
local isolate_data = require('tests.isolate_data')

local function spec_files()
  local files = {}
  for _, dir in ipairs({ 'tests/spec', 'tests/differential', 'tests/regression' }) do
    vim.list_extend(files, vim.fn.globpath(dir, '**/*_spec.lua', false, true))
  end
  table.insert(files, 'tests/isolation/touches_data_dir.lua')
  table.sort(files)
  return files
end

local function first_code_line(path)
  for line in io.lines(path) do
    if line:find('%S') and not line:match('^%s*%-%-') then
      return line
    end
  end
end

describe('when a spec runs', function()
  it('sees a data dir outside the real one', function()
    local data = vim.fn.stdpath('data')
    assert.is_false(isolate_data.is_inside(data, isolate_data.real_data_dir()))
  end)

  it('gives the logger that isolated data dir', function()
    local logger = require('tobira.core.logger')
    assert.equals(vim.fn.stdpath('data') .. '/tobira', logger.data_dir())
  end)
end)

describe('when the logger was loaded before isolation', function()
  it('refuses to continue if it points at the real data dir', function()
    local real = '/home/someone/.local/share/nvim'
    assert.has_error(function()
      isolate_data.assert_isolated({
        data_dir = function()
          return real .. '/tobira'
        end,
      }, real)
    end)
  end)

  it('accepts a logger that points elsewhere', function()
    assert.has_no_error(function()
      isolate_data.assert_isolated({
        data_dir = function()
          return '/tmp/nvim.test/1/tobira'
        end,
      }, '/home/someone/.local/share/nvim')
    end)
  end)

  it('does not mistake a sibling directory for the real one', function()
    assert.is_false(isolate_data.is_inside('/home/someone/.local/share/nvim-test', '/home/someone/.local/share/nvim'))
    assert.is_true(isolate_data.is_inside('/home/someone/.local/share/nvim', '/home/someone/.local/share/nvim'))
  end)
end)

describe('every spec file', function()
  for _, path in ipairs(spec_files()) do
    it('isolates the data dir before anything else: ' .. path, function()
      assert.equals("require('tests.isolate_data')", first_code_line(path))
    end)
  end
end)

describe('when a spec is launched with PlenaryBustedFile and no minimal_init', function()
  it('leaves the real usage.json untouched', function()
    local root = vim.fn.tempname()
    local fake_data = root .. '/data'
    vim.fn.mkdir(fake_data .. '/nvim/tobira', 'p')
    vim.fn.mkdir(root .. '/config', 'p')
    local real_file = fake_data .. '/nvim/tobira/usage.json'
    local f = io.open(real_file, 'w')
    f:write('{"ciw":{"count":3000}}')
    f:close()

    local plenary = vim.fn.fnamemodify(vim.api.nvim_get_runtime_file('lua/plenary/busted.lua', false)[1], ':h:h:h')
    local result = vim
      .system({
        vim.v.progpath,
        '--headless',
        '--noplugin',
        '-u',
        'NONE',
        '--cmd',
        'set rtp^=' .. plenary .. ',.',
        '-c',
        'runtime plugin/plenary.vim',
        '-c',
        'PlenaryBustedFile tests/isolation/touches_data_dir.lua',
      }, {
        cwd = vim.fn.getcwd(),
        env = {
          XDG_DATA_HOME = fake_data,
          XDG_CONFIG_HOME = root .. '/config',
          XDG_STATE_HOME = root .. '/state',
          XDG_CACHE_HOME = root .. '/cache',
        },
        text = true,
      })
      :wait(60000)

    local output = (result.stdout or '') .. (result.stderr or '')
    assert.is_truthy(output:find('Success:%s*%S*%s*1'), output)
    local after = io.open(real_file, 'r')
    assert.is_not_nil(after, 'the real usage.json was deleted')
    assert.equals('{"ciw":{"count":3000}}', after:read('*a'))
    after:close()
  end)
end)
