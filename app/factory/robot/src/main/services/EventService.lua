local EventService = Class:extend()

local RobotEvent = this.models.RobotEvent
local StatusEvent = this.models.StatusEvent
local MachineEvent = this.models.MachineEvent

function EventService:new(jobService)
  return self:extend({
    jobService = jobService
  })
end

function EventService:detectRobotEvent(robotUpdate)
  if robotUpdate.what == "getNextAction" then
    if robotUpdate.label then
      if self.jobService:isAssigned(robotUpdate.label) then
        local job = self.jobService:advance(robotUpdate.label)
        if not job then return nil, error end
        if job.phase then
          return RobotEvent:new(
            RobotEvent.JOB_ADVANCED,
            {label = robotUpdate.label, phase = job.phase, jobId = job.id}
          )
        else
          local newJob, error = self.jobService:createJob(robotUpdate.label)
          if not newJob then return nil, error end
          return RobotEvent:new(
            RobotEvent.JOB_ASSIGNED,
            {label = robotUpdate.label, conveyor = newJob.conveyor, phase = newJob.phase}
          )
        end
      else
        local job, error = self.jobService:createJob(robotUpdate.label)
        if not job then return nil, error end
        return RobotEvent:new(
          RobotEvent.JOB_ASSIGNED,
          {label = robotUpdate.label, conveyor = job.conveyor, phase = job.phase}
        )
      end
    else
      local newLabel = self.jobService:employNew()
      if newLabel then
        return RobotEvent:new(
          RobotEvent.LABEL_ASSIGNED,
          {oldLabel = nil, newLabel = newLabel}
        )
      end
    end
  elseif robotUpdate.what == "reportStatus" then
    return nil
  end
end

function EventService:detectStatusEvent(robotUpdate)
  if robotUpdate.label then
    if not (type(robotUpdate.inventory) == "table" and type(robotUpdate.energy) == "table") then
      return nil, "incorrect robot status update format"
    end
    if not (robotUpdate.energy.current and robotUpdate.energy.max) then
      return nil, "incorrect robot status energy format"
    end

    return StatusEvent:new(
      StatusEvent.STATUS_UPDATED,
      {inventory = robotUpdate.inventory, energy = robotUpdate.energy}
    )
  else
    return nil
  end
end

function EventService:detectMachineEvent(robotUpdate)
  -- @TODO
end

return EventService