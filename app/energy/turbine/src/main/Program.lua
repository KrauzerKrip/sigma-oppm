local Program = Class:extend()

local sides = require("sides")
local colors = require("colors")
local component = require("component")
local computer = require("computer")
local thread = require("thread")

local Logger = sigma.util.Logger

local PumpService = this.services.PumpService
local PumpController = this.infrastructure.PumpController
local Requester = this.infrastructure.Requester
local PumpResponse = this.models.PumpResponse

local THROTTLE_SIDE     = sides.top
local THROTTLE_COLOR    = colors.orange
local FETCH_TIMEOUT     = 5
local COMPONENT_TIMEOUT = 5
local LOG_FILE          = "/var/log/turbine.log"
local LOG_LEVEL         = Logger.Levels.Info
local POLL_INTERVAL     = 5

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

  local redstone = waitForComponent("redstone", COMPONENT_TIMEOUT)
  local modem = waitForComponent("modem", COMPONENT_TIMEOUT)

  if not redstone then
    log:critical("Redstone component timeout")
    return 1
  end
  if not modem then 
    log:critical("Modem component timeout")
    return 1
  end

  local pumpService = PumpService.new()
  local pumpController = PumpController.new(THROTTLE_SIDE, THROTTLE_COLOR, redstone)
  local requester = Requester.new(FETCH_TIMEOUT, modem)

  local init = pumpController:isActivated():flatMap(function(v)
    if v then
      log:warning("The pump is activated on init. Deactivating...")
      return pumpController:deactivate():flatMap(
        function()
          return RF.ok(function() return log:info("Pump deactivated") end)
        end
      )
    end
    return RF.okT()
  end)

  local initResult = init()
  if not initResult.isOk then
    log:critical("Can't init pump: " .. initResult.error)
  end

  local logLevelName = nil

  for k,v in pairs(Logger.Levels) do
    if v == LOG_LEVEL then
      logLevelName = k
    end
  end

  log:info(string.format(
    "The turbine program has started.\n> Logs written to: %s\n> Log level: %s\n> Power polling interval: %d s",
    LOG_FILE, logLevelName, POLL_INTERVAL
  ))

  local lastUpdateTime = computer.uptime()
  while true do
    local timeNow = computer.uptime()
    local deltaTime = timeNow - lastUpdateTime
    pumpService:tick(deltaTime)
    local rf = requester:fetchRatios():flatMap(function(ratios)
      local response = pumpService:handleRatios(ratios)
      if response == PumpResponse.STAY then
        return RF.ok(function() log:debug("Staying in the same state") end)
      elseif response == PumpResponse.ACTIVATE then
        return pumpController:activate():flatMap(function() return RF.ok(
          function() log:info(">> Activated pump") end) end
        )
      elseif response == PumpResponse.DEACTIVATE then
        return pumpController:deactivate():flatMap(function() return RF.ok(
          function() log:info(">> Deactivated pump") end) end
        )
      end
    end)
    local result = rf()
    if not result.isOk then
      log:error(result.error)
    end
    lastUpdateTime = timeNow
    os.sleep(POLL_INTERVAL) 
  end
end

return Program
