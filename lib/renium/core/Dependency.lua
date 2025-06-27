local Dependency = {}
local store = {}

local mt = {
  __index = function(t, k)
    return t.resolve(k)
  end
}

setmetatable(Dependency, mt)

function Dependency.register(name, factory)
  assert(not store[name], "already registered: "..name)
  store[name] = function()
    local inst = factory()
    local proxy = {} -- read-only proxy
    setmetatable(proxy, { 
      __index = inst,
     __newindex = function() error("immutable "..name) end }
    )
    return proxy
  end
end

function Dependency.resolve(name)
  checkArg(1, name, "string")
  local provider = store[name]
  if not provider then error("no provider: " .. name) end
  local v = provider()
  store[name] = function() return v end
  return v
end

return Dependency
