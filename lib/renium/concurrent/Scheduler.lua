local thread, event = require("thread"), require("event")

local Scheduler = sigma.renium.core.Class:extend()

Scheduler.tasks = {}

function Scheduler:new()
  local o = {}
  setmetatable(o, self)
  self._index = self
  return o
end

function Scheduler:spawn(fn, ...)
  local t = thread.create(function(...)
    local ok, why = pcall(fn, ...)
    if not ok then io.stderr:write(why.."\n") end
  end, ...)
  table.insert(self.tasks, t)
  return t
end

function Scheduler.tick(timeout)
  -- Let the kernel swap threads; 0 means “immediately yield”.
  event.pull(timeout or 0)
end

return Scheduler