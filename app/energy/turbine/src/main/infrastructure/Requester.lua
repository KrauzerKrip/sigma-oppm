local Requester = Class:extend()

local computer = require("computer")
local event = require("event")
local serialization = require("serialization")

local PORT = 10000

local function fetchBatteryRatios(timeout, modem)
    modem.open(PORT)
    modem.broadcast(PORT, "getBatteryRatios")
    local startTime = computer.uptime()
    local code = nil
    repeat
      local _, _, from, port, _, code, method, payload = event.pull(5, "modem_message")
      if port == PORT and method == "getBatteryRatios" then
        local ok, data = pcall(serialization.unserialize, payload)
        if ok and type(data) == "table" then
          return data
        end
      end
      if computer.uptime() - startTime > timeout then
        return nil
      end
    until code == 200
    return nil
end

function Requester.new(timeout, modem)
  return Requester:extend({timeout = timeout, modem = modem})
end

function Requester:fetchRatios()
    return RF.of(function()
        local batteryRatios = fetchBatteryRatios(self.timeout, self.modem)
        if batteryRatios then
            return {isOk = true, value = batteryRatios}
        else
            return {isOk = false, error = "Timeout when fetching battery ratios"}
        end
    end)
end

return Requester