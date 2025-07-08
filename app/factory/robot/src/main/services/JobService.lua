local JobService = Class:extend()

local JobPhase = this.models.JobPhase

function JobService:new(params)
  return self:extend({
    getAssignments = params.getAssignments,
    getJobSpec = params.getJobSpec,
    conveyors = params.conveyors
  })
end

function JobService:employNew()
  local assignments = self.getAssignments()
  local occupiedConveyors = {}
  for _,assignment in pairs(assignments) do 
    local jobSpec = self.getJobSpec(assignment.jobId)
    occupiedConveyors[jobSpec.conveyor] = true
  end

  for k,v in pairs(self.conveyors) do
    if not occupiedConveyors[k] then
      return k
    end
  end

  return nil, "no free conveyor"
end

function JobService:createJob(conveyorLabel)
  return {conveyor = conveyorLabel, phase = JobPhase.START}
end

function JobService:advance(jobPhase)
  if jobPhase == JobPhase.START then
    return JobPhase.UNLOAD
  elseif jobPhase == JobPhase.UNLOAD then
    return JobPhase.CARRY
  elseif jobPhase == JobPhase.CARRY then
    return JobPhase.LOAD
  elseif jobPhase == JobPhase.LOAD then
    return nil, nil
  else
    return nil, "unknown job phase: " .. tostring(jobPhase)
  end
end

return JobService