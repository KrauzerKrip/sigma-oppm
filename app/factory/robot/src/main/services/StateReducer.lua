local StateReducer = Class:extend()

local RobotEvent = this.models.RobotEvent
local StatusEvent = this.models.StatusEvent
local MachineEvent = this.models.MachineEvent
local JobPhase = this.models.JobPhase

function StateReducer:reduce(state, events)
  for _, event in ipairs(events) do
    if event.name == RobotEvent.LABEL_ASSIGNED then
      local robot = {}
      if event.oldLabel then 
        local assignment = state.jobs.assignments[event.oldLabel]
        if assignment then
          table.remove(state.jobs.specs, assignment.jobId)
          state.jobs.assignments[event.oldLabel] = nil
        end
        robot = state.robots[event.oldLabel]
        state.robots[event.oldLabel] = nil
      end
      state.robots[event.newLabel] = robot
    elseif event.name == RobotEvent.JOB_ASSIGNED then
      local oldAssignment = state.jobs.assignments[event.label]
      if oldAssignment then
        table.remove(state.jobs.specs, oldAssignment.jobId)
        state.jobs.assignments[event.label] = nil
      end
      local newSpec = {conveyor = event.conveyor}
      table.insert(state.jobs.specs, newSpec)
      local newAssignment = {
        jobId = #state.jobs.specs,
        phase = event.phase
      }
      state.jobs.assignments[event.label] = newAssignment
    elseif event.name == RobotEvent.JOB_ADVANCED then
      local assignment = state.jobs.assignments[event.label]
      if not assignment then return false, "can't advance job because there is not an assignment found for " .. tostring(event.label) end
      assignment.phase = event.phase
    elseif event.name == StatusEvent.STATUS_UPDATED then
      local robot = state.robots[event.label]
      if not robot then return false, "can't update status because robot " .. tostring(event.label) .. " not found" end
      robot.energy = event.energy
      robot.inventory = event.inventory
    else
      return false, "unknown event name: " .. tostring(event.name)
    end
  end

  return true
end

return StateReducer