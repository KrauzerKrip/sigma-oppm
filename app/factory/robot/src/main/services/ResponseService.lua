local ResponseService = Class:extend()

local RobotEvent = this.models.RobotEvent
local JobPhase = this.models.JobPhase

function ResponseService:new(params)
  return self:extend({
    navService = params.navService,
    getJobSpec = params.getJobSpec,
    conveyors = params.conveyors,
    machines = params.machines})
end

function ResponseService:_getJobConveyor(jobId)
  local jobSpec = self.getJobSpec(jobId)
  if not jobSpec then
    return nil, string.format("JobSpec of the job with id %d is not found", robotEvent.jobId)
  end
  return self.conveyors[jobSpec.conveyor]
end

function ResponseService:_getJobAdvancedAction(jobId, phase)
  if phase == JobPhase.UNLOAD then
    local conveyor, error = self:_getJobConveyor(jobId)
    if not conveyor then return nil, error end
    local machine = self.machines[conveyor.from]
    local facing, slot = machine.output.facing, machine.output.slot
    local threshold, count = conveyor.threshold, conveyor.count
    return {
      what = "take",
      from = {facing = facing, slot = slot},
      threshold = threshold,
      count = count
    }
  elseif phase == JobPhase.CARRY then
    local conveyor, error = self:_getJobConveyor(jobId)
    if not conveyor then return nil, error end
    local machineUnload = self.machines[conveyor.from]
    local machineLoad = self.machines[conveyor.to]
    local from, to = machineUnload.output.node, machineLoad.input.node
    local path = self.navService:getPath(from, to)
    if not path then
      return nil, string.format("Path can't be found from %s to %s", from, to)
    end
    return {
      what = "go",
      path = path
    }
  elseif phase == JobPhase.LOAD then
    local conveyor, error = self:_getJobConveyor(jobId)
    if not conveyor then return nil, error end
    local machine = self.machines[conveyor.to]
    local facing, slot = machine.input.facing, machine.input.slot
    local threshold, count = conveyor.threshold, conveyor.count
    return {
      what = "put",
      to = {facing = facing, slot = slot},
      count = count
    }
  else
    return nil, "Unknown job phase: " .. tostring(phase)
  end
end

function ResponseService:getResponse(robotEvent, nearestWaypoint)
  local action = nil
  if robotEvent.name == RobotEvent.LABEL_ASSIGNED then
    action = {what = 'assign', label = robotEvent.newLabel}
  elseif robotEvent.name == RobotEvent.JOB_ASSIGNED then
    local conveyor = self.conveyors[robotEvent.conveyor]
    if not conveyor then return nil, "No conveyor " .. tostring(robotEvent.conveyor) end
    local machineUnload = self.machines[conveyor.from]
    local from, to = nearestWaypoint, machineUnload.output.node
    local path = self.navService:getPath(from, to)
    if not path then
      return nil, string.format("Path can't be found from %s to %s", from, to)
    end
    action = {what = "go", path = path}
  elseif robotEvent.name == RobotEvent.JOB_ADVANCED then
    action = self:_getJobAdvancedAction(robotEvent.jobId, robotEvent.phase)
  else
    return nil, "Unknown robot event: " .. tostring(robotEvent.name)
  end

  return {action = action}
end

return ResponseService