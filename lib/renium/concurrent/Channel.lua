local thread   = require("thread")
local computer = require("computer")

local Channel  = {}

Channel.__index = Channel

local function now()            return computer.uptime() end
local function deadline(t)      return t and (now() + t) end
local function timedOut(tuntil) return tuntill and now() >= tuntill end


function Channel.new(capacity)
  checkArg(1, capacity, "number", "nil")
  capacity = capacity or math.huge          
  assert(capacity >= 1, "capacity must be ≥ 1")

  local self = setmetatable({
    _buf  = {},
    _head = 1,
    _tail = 1,
    _size = 0,
    _cap  = capacity,
    _closed = false,
  }, Channel)

  return self
end

local function push(self, v)
  self._buf[self._tail] = v
  self._tail = (self._tail % self._cap) + 1
  self._size = self._size + 1
end

local function pop(self)
  local v = self._buf[self._head]
  self._buf[self._head] = nil
  self._head = (self._head % self._cap) + 1
  self._size = self._size - 1
  return v
end

---------------------------------------------------------------------------
-- public API
---------------------------------------------------------------------------

--- Put a value; blocks until space available or timeout (seconds).
--  @return true on success, false,"reason" on failure
function Channel:put(value, timeout)
  if self._closed then return false, "closed" end
  local untilT = deadline(timeout)

  while self._size >= self._cap do
    if self._closed      then return false, "closed"  end
    if timedOut(untilT)  then return false, "timeout" end
    coroutine.yield()
  end

  push(self, value)
  return true
end

--- Get next value; blocks until available or timeout (seconds).
--  @return value | nil,"reason"
function Channel:get(timeout)
  local untilT = deadline(timeout)

  while self._size == 0 do
    if self._closed      then return nil, "closed"   end
    if timedOut(untilT)  then return nil, "timeout"  end
    coroutine.yield()
  end

  return pop(self)
end

--- Close the channel (no further writes); readers drain what’s left.
function Channel:close()
  self._closed = true
end

function Channel:isClosed() return self._closed            end
function Channel:size()     return self._size              end
function Channel:isEmpty()  return self._size == 0         end
function Channel:isFull()   return self._size >= self._cap end
function Channel:capacity() return self._cap               end

return Channel
