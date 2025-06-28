local PumpService = Class:extend()

local PumpState = this.models.PumpState
local PumpResponse = this.models.PumpResponse

local CHARGING_RATE = 0.016 -- %
local HYSTERESIS_MARGIN = 0.10 -- %

function PumpService.new()
  local new = PumpService:extend()
  new.state = PumpState.OFF
  new.timeElapsed = 0
  return new
end

function PumpService:calculateEstimatedTime(ratios)
  local capacity = #ratios 
  local currentTotal = 0
  
  for _, ratio in ipairs(ratios) do
    currentTotal = currentTotal + ratio
  end
  
  return CHARGING_RATE * (capacity - (currentTotal + HYSTERESIS_MARGIN)) * 100^2
end

function PumpService:hasLowPower(ratios, threshold)
  for _, ratio in ipairs(ratios) do
    if ratio < threshold then
      return true
    end
  end
  return false
end

function PumpService:computeNextState(currentState, ratios, timeElapsed)
  local nextState = currentState
  local estimatedTime = self:calculateEstimatedTime(ratios)
  
  if currentState == PumpState.OFF then
    if self:hasLowPower(ratios, 0.15) then
      nextState = PumpState.ON
    end
  elseif currentState == PumpState.ON then
    if timeElapsed > 10 then
      nextState = PumpState.BREAK
    elseif estimatedTime < 0 then
      nextState = PumpState.OFF
    end
  elseif currentState == PumpState.BREAK then
    if timeElapsed > 100 then
      nextState = PumpState.ON
    end
  end
  
  return nextState
end

function PumpService:handleRatios(ratios)
  local nextState = self:computeNextState(self.state, ratios, self.timeElapsed)
  
  if self.state ~= nextState then
    self.timeElapsed = 0
  end

  local previousState = self.state
  self.state = nextState
  
  if self.state == previousState then
    return PumpResponse.STAY
  elseif self.state == PumpState.ON then
    return PumpResponse.ACTIVATE
  elseif self.state == PumpState.OFF then
    return PumpResponse.DEACTIVATE
  elseif self.state == PumpState.BREAK then
    return PumpResponse.DEACTIVATE
  else
    error("Incoherent pump state: " .. self.state)
  end
end

function PumpService:tick(deltaTime)
  self.timeElapsed = self.timeElapsed + deltaTime
end

return PumpService