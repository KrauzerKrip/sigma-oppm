local Program = Class:extend()

local sides = require("sides")
local component = require("component")
local computer = require("computer")
local thread = require("thread")

local Logger = sigma.util.Logger


local COMPONENT_TIMEOUT = 5
local LOG_FILE          = "/var/log/robot.log"
local JOBS_FILE         = "/etc/jobs.lua"
local GRAPH_FILE        = "/etc/graph.lua"
local LOG_LEVEL         = Logger.Levels.Debug

local function waitForComponent(name, timeout)
  local timeElapsed = 0
  while not component.isAvailable(name) do
    os.sleep(1)
    timeElapsed = timeElapsed + 1
    if timeElapsed > timeout then
      return nil
    end
  end
  return component[name]
end

function Program.run(...)
  local log = Logger.new(
    Logger.providers.consoleAndFile(LOG_FILE),
    LOG_LEVEL
  )
  local modem = waitForComponent("modem", COMPONENT_TIMEOUT)
  if not modem then 
    log:critical("Modem component timeout")
    return 1
  end
end

return Program
