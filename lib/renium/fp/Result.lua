local Result = sigma.renium.core.Class:extend()

function Result.ok(v)    return { isOk=true , value=v ,
  map = function(self,f) return Result.ok(f(self.v)) end,
  flatMap=function(self,f) return f(self.v) end,
} end

function Result.err(e)   return { isOk=false, error=e ,
  map = function(self) return self end,
  flatMap=function(self) return self end,
} end

return Result
