local JobPhase = {
  START = "START",
  UNLOAD = "UNLOAD",
  CARRY = "CARRY",
  LOAD = "LOAD",

  mt = {
    __index = function(t, k)
      error("Unknown JobPhase: " .. tostring(k))
    end
  }
}

setmetatable(JobPhase, JobPhase.mt)

return JobPhase