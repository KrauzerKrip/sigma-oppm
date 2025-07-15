local Spec = sigma.test.TableSpec
local StateService = sigma.factory.robot.services.StateService
local RobotEvent = sigma.factory.robot.models.RobotEvent
local sides = require("sides")

local function compareLists(a, b)
  if #a ~= #b then
    return false
  end
  for i,va in ipairs(a) do
    if va ~= b[i] then
      return false
    end
  end
  return true
end

local function assertEq(result, expected)
  assert(result == expected, "expected " .. tostring(expected) .. 
  " but got " .. tostring(result))    
end


local function createState()
  return {
    robots = {},
    jobs = {
      specs = {},
      assignments = {},
    },
    machines = {}
  }
end

local function createStateReducer(expectedState, expectedEvents)
  local stateReducer = {}
  
  function stateReducer:reduce(state, events)
    assertEq(state, expectedState)
    assert(compareLists(events, expectedEvents))
    state._test = true
    return true
  end

  return stateReducer
end

local function createPersistanceAdapter(state, events)
  local persistanceAdapter = {}
  
  function persistanceAdapter:loadSnapshot()
    return state
  end

  function persistanceAdapter:loadJournal()
    return events
  end

  function persistanceAdapter:append(event)
    -- nop
  end

  return persistanceAdapter
end

local function createSubscribe()
  return function(topic, fn)
    -- nop
  end
end

local StateServiceSpec = Spec:extend({spec = {
  ["StateService"] = {
    ["when asked to restore the state"] = {
      ["should successfully return the restored state"] = function()
        local subscribe = createSubscribe()
        local expectedState = createState()
        local expectedEvents = {
          RobotEvent:new(
            RobotEvent.LABEL_ASSIGNED,
            {oldLabel = prevLabel, newLabel = expectedLabel}
          )
        }
        local stateReducer = createStateReducer(expectedState, expectedEvents)
        local persistanceAdapter = createPersistanceAdapter(expectedState, expectedEvents)
        local stateService = StateService:new(stateReducer, persistanceAdapter, subscribe)
        local state, error = stateService:restore()
        assert(state, error)
        assertEq(state, expectedState)
        assert(state._test, "state isn't reduced")
      end,
  }
}}}
)


return StateServiceSpec