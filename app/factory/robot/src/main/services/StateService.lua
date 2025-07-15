local StateService = Class:extend()

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

function StateService:new(stateReducer, persistanceAdapter, subscribe)
  checkArg(3, subscribe, "function")
  
  subscribe("*", function(event)
    local status, error = persistanceAdapter.append(event)
    if not status then error(error) end
  end)
    
  return self:extend({stateReducer = stateReducer, persistanceAdapter = persistanceAdapter})
end

function StateService:restore()
  local state, sError = self.persistanceAdapter:loadSnapshot()
  local events, jError = self.persistanceAdapter:loadJournal()

  if sError then return nil, "error when loading snapshot: " .. tostring(error) end
  if jError then return nil, "error when loading journal: " .. tostring(error) end

  local state = state or createState()
  local events = events or {}

  local rStatus, rError = self.stateReducer:reduce(state, events)
  if not rStatus then return nil, "error when reducing state: " .. tostring(rError) end

  return state
end

return StateService