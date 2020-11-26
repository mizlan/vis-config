-- a lean vector implementation that supports normal, sane operations
-- does not provide much error checking, must be done as precondition
-- github.com/mizlan

require('table')
db = require('pl.pretty').dump

-- prototype
Vec = { contents = {}, size = 0 }

function Vec:new()
  o = { contents = {}, size = 0 }
  setmetatable(o, { __index = self } )
  return o
end

function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end

function Vec:copy(other)
  o = copy(other)
  setmetatable(o, { __index = self } )
end

function Vec:append(element)
  -- invariant: Vec[size] is the address of the new element to add
  self.size = self.size + 1
  self.contents[self.size] = element
end

function Vec:at(index)
  return self.contents[index]
end

function Vec:toString()
  local str = '['
  for i = 1, self.size do
    if i > 1 then str = str .. ', ' end
    str = str .. self.contents[i]
  end
  str = str .. ']'
  return str
end

function Vec:swap(i, j)
  local swp = self.contents[i]
  self.contents[i] = self.contents[j]
  self.contents[j] = swp
end

function Vec:sort(cmp)
  if cmp == nil then
    cmp = function(a, b) return a < b end
  end
  for i = 2, self.size do
    local j = i
    while j > 1 and cmp(self.contents[j], self.contents[j - 1]) do
      self:swap(j, j - 1)
      j = j - 1
    end
  end
end

function Vec:extend(other)
  local SZ = other.size
  for i = 1, SZ do
    self:append(other:at(i))
  end
end
