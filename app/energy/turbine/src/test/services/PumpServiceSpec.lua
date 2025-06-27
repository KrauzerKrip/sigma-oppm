local Spec = sigma.test.fp.FreeSpec
local PumpService = sigma.energy.turbine.services.PumpService
local PumpResponse = sigma.energy.turbine.models.PumpResponse
local PumpState = sigma.energy.turbine.models.PumpState
local PumpEvent = sigma.energy.turbine.models.PumpEvent
local math = require("math")
local computer = require("computer")

local PumpStateMachine = Class:extend()

local UPPER_THRESHOLD = 0.75
local LOWER_THRESHOLD = 0.15

local function generateRandomLower()
    return LOWER_THRESHOLD - math.random() * LOWER_THRESHOLD
end

local function generateRandomMiddle()
    return math.random(16, 97) * 0.01
end

local function generateRandomUpper()
    return 0.98 + math.random() * 0.03
end

local PumpServiceSpec = Spec:extend({spec = {
    ["PumpService"] = {
        ["when the state is OFF"] = {
            ["should return STAY response, time elapsed = 1"] = function()
                local pumpService = PumpService:extend({state = PumpState.OFF, timeElapsed = 1})
                local response = pumpService:handleRatios({
                    generateRandomMiddle(),
                    generateRandomMiddle(), 
                    generateRandomUpper(),
                    generateRandomUpper()
                })
                return IO.of(function()
                    assert(response == PumpResponse.STAY, "response == " .. response)
                end)
            end,
            ["should return STAY response, time elapsed = 101"] = function()
                local pumpService = PumpService:extend({state = PumpState.OFF, timeElapsed = 101})
                local response = pumpService:handleRatios({
                    generateRandomMiddle(),
                    generateRandomMiddle(), 
                    generateRandomMiddle(),
                    generateRandomUpper()
                })
                local state = pumpService.state
                local previousState = pumpService.previousState
                return IO.of(function()
                    assert(response == PumpResponse.STAY, "response == " .. response)
                end)
            end,
            ["should return ACTIVATE response (low power detected), time elapsed = 1"] = function()
                local pumpService = PumpService:extend({state = PumpState.OFF, timeElapsed = 1})
                local response = pumpService:handleRatios({
                    generateRandomMiddle(),
                    generateRandomMiddle(), 
                    generateRandomLower(),
                    generateRandomUpper()
                })
                return IO.of(function()
                    assert(response == PumpResponse.ACTIVATE, "response == " .. response)
                end)
            end,
        },
        ["when the state is ON"] = {
            ["should return STAY response, time elapsed = 1"] = function()
                local pumpService = PumpService:extend({state = PumpState.ON, timeElapsed = 1})
                local response = pumpService:handleRatios({
                    generateRandomMiddle(),
                    generateRandomMiddle(),
                    generateRandomMiddle(),
                    generateRandomLower()
                })
                return IO.of(function()
                    assert(response == PumpResponse.STAY, "response == " .. response)
                end)
            end,
            ["should return STAY response, time elapsed = 5"] = function()
                local pumpService = PumpService:extend({state = PumpState.ON, timeElapsed = 5})
                local response = pumpService:handleRatios({
                    generateRandomMiddle(),
                    generateRandomMiddle(),
                    generateRandomMiddle(),
                    generateRandomMiddle()
                })
                return IO.of(function()
                    assert(response == PumpResponse.STAY, "response == " .. response)
                end)
            end,
            ["should return DEACTIVATE response (making a break), time elapsed = 11"] = function()
                local pumpService = PumpService:extend({state = PumpState.ON, timeElapsed = 11})
                local response = pumpService:handleRatios({
                    generateRandomLower(),
                    generateRandomLower(),
                    generateRandomLower(),
                    generateRandomLower()
                })
                local eta = pumpService:calculateEstimatedTime({
                    generateRandomLower(),
                    generateRandomLower(),
                    generateRandomLower(),
                    generateRandomLower()
                })
                return IO.of(function()
                    assert(response == PumpResponse.DEACTIVATE, "response == " .. response)
                end)
            end,
            ["should return DEACTIVATE response (turning off), time elapsed = 11"] = function()
                local pumpService = PumpService:extend({state = PumpState.ON, timeElapsed = 11})
                local response = pumpService:handleRatios({
                    generateRandomUpper(),
                    generateRandomUpper(),
                    generateRandomUpper(),
                    generateRandomUpper()
                })
                return IO.of(function()
                    assert(response == PumpResponse.DEACTIVATE, "response == " .. response)
                end)
            end,
        },
        ["when the state is BREAK"] = {
            ["should return STAY response, time elapsed = 11"] = function()
                local pumpService = PumpService:extend({state = PumpState.BREAK, timeElapsed = 11})
                local response = pumpService:handleRatios({
                    generateRandomUpper(),
                    generateRandomUpper(),
                    generateRandomUpper(),
                    generateRandomUpper()
                })
                return IO.of(function()
                    assert(response == PumpResponse.STAY, "response == " .. response)
                end)
            end,
            ["should return ACTIVATE response, time elapsed = 101"] = function()
                local pumpService = PumpService:extend({state = PumpState.BREAK, timeElapsed = 101})
                local response = pumpService:handleRatios({
                    generateRandomUpper(),
                    generateRandomUpper(),
                    generateRandomUpper(),
                    generateRandomUpper()
                })
                return IO.of(function()
                    assert(response == PumpResponse.ACTIVATE, "response == " .. response)
                end)
            end
        },
    }
}})


return PumpServiceSpec