local IO = sigma.renium.core.Class:extend()


function IO.of(thunk)            -- thunk : () → a 
  return setmetatable({ run = thunk }, { __call = function(t) return t:run() end, __index = IO })
end

function IO.pure(value)
  return IO.of(function() return value end)
end

function IO:map(f)     return IO.of(function() return f(self:run()) end) end

function IO:flatMap(f) return IO.of(function() return f(self:run()):run() end) end


return IO
