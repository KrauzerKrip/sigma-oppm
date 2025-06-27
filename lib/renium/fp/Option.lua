local mt = sigma.renium.core.Class:extend()

function mt:map(f)
  if self.isSome then return Some(f(self.value)) else return self end
end

function mt:flatMap(f)
  if self.isSome then return f(self.value) else return self end
end

function mt:getOrElse(other)
  if self.isSome then return self.value else return other end
end

function mt:match(pat)
  return (self.isSome and pat.Some or pat.None)(self.value)
end

mt.__tostring = function(o) return o.isSome and ("Some("..tostring(o.value)..")") or "None" end

function Some(v)  return setmetatable({ value = v, isSome = true  }, mt) end
None = setmetatable({ isSome = false }, mt)

return { Some = Some, None = None }
