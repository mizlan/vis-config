local lunajson = require('lunajson')
require('table')
require('lua-vec')

local function collect(cmd)
  local fhandle = assert(io.popen(cmd))
  local output = assert(fhandle:read('*all'))
  local rc = {fhandle:close()}

  local output = output:gsub('compilation terminated%.', '')
  local json_table = lunajson.decode(output)
  return json_table
end

local function cmp_pos(candidate, incumbent)
  -- is candidate < incumbent ? i.e., does it come earlier
  if candidate['line'] == incumbent['line'] then
    return candidate['col'] < incumbent['col']
  else
    return candidate['line'] < incumbent['line']
  end
end

local function lint_gcc(win)
  local cmd = string.format('g++-10 -Wall -Wextra -fanalyzer -fsanitize=address -fdiagnostics-format=json %s 2>&1', win.file.name)
  local res = collect(cmd)
  local all_instances = {}
  for i, instance in ipairs(res) do
    local kind = instance['kind']
    local msg = instance['message']
    -- strategy: minimum byte position to maximum byte position
    local range = {}
    for _, loc in ipairs(instance['locations']) do
      if loc['caret'] ~= nil then
        local LOC = loc['caret']
        local POS = { ['line'] = LOC['line'], ['col'] = LOC['column'] }
        if range['min'] == nil then
          range['min'] = POS
          range['max'] = POS
        end
        if cmp_pos(POS, range['min']) then range['min'] = POS end
        if not cmp_pos(POS, range['max']) then range['max'] = POS end
      end
      if loc['start'] ~= nil then
        local LOC = loc['start']
        local POS = { ['line'] = LOC['line'], ['col'] = LOC['column'] }
        if cmp_pos(POS, range['min']) then range['min'] = POS end
        if not cmp_pos(POS, range['max']) then range['max'] = POS end
      end
      if loc['finish'] ~= nil then
        local LOC = loc['finish']
        local POS = { ['line'] = LOC['line'], ['col'] = LOC['column'] }
        if cmp_pos(POS, range['min']) then range['min'] = POS end
        if not cmp_pos(POS, range['max']) then range['max'] = POS end
      end
    end
    table.insert(all_instances, { ['range'] = range, ['kind'] = kind, ['msg'] = msg })
  end
  RET = Vec:new()
  for _, instance in ipairs(all_instances) do RET:append(instance) end
  RET:sort(function(a, b)
    return cmp_pos(a['range']['min'], b['range']['min'])
  end)
  return RET
end

M = { ['cpp'] = lint_gcc }

return M
