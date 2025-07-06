local StateService = Class:extend()

function StateService:new(stateReducer, persistanceAdapter, subscribe)
  checkArg(3, subscribe, "function")
  
  subscribe("*", function(event)
    local status, error = persistanceAdapter.append(event)
    error(error)
  end)
    
  return self:extend({stateReducer = stateReducer, persistanceAdapter = persistanceAdapter})
end

function StateService:load()
end