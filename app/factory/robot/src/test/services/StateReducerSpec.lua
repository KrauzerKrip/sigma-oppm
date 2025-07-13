local Spec = sigma.test.TableSpec
local StateReducer = sigma.factory.robot.services.StateReducer
local JobPhase = sigma.factory.robot.models.JobPhase
local RobotEvent = sigma.factory.robot.models.RobotEvent
local StatusEvent = sigma.factory.robot.models.StatusEvent
local MachineEvent = sigma.factory.robot.models.MachineEvent

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

local function addRobot(state, label, currentEnergy, inventory)
  local inventory = inventory or {}
  local currentEnergy = currentEnergy or 12000
  state.robots[label] = {
    energy = {
      current = currentEnergy,
      max = 20000
    },
    inventory = inventory
  }
end

local function assign(state, robotLabel, conveyor, phase)
  local phase = phase or JobPhase.START
  table.insert(state.jobs.specs, {conveyor = conveyor})
  state.jobs.assignments[robotLabel] = {
    jobId = #state.jobs.specs,
    phase = phase
  }
end

local function unassign(state, robotLabel)
  table.remove(state.jobs.specs, state.jobs.assignments[robotLabel].jobId)
  state.jobs.assignments[robotLabel] = nil
end

local StateReducerSpec = Spec:extend({spec = {
  ["StateReducer"] = {
    ["when asked to reduce a LABEL_ASSIGNED RobotEvent"] = {
      ["for an unlabeled robot"] = {
        ["should successfully return the new state with a new labeled robot"] = function()
          local expectedLabel = "ExpectedRobotLabel"
          local event = RobotEvent:new(
            RobotEvent.LABEL_ASSIGNED,
            {oldLabel = nil, newLabel = expectedLabel}
          )
          local state = createState()
          local status, error = StateReducer:reduce(state, {event})
          assert(status, error)
          assert(state.robots[expectedLabel])
        end,
    },
    ["for an already labeled robot"] = {
        ["should successfully return the new state with a robot with reassigned label, and the robot's previous job removed"] = function()
          local prevLabel = "PrevRobotLabel"
          local expectedLabel = "ExpectedRobotLabel"
          local expectedEnergy = 8000
          local expectedItemName = "hash1"
          local expectedItemCount = 72
          local expectedInventory = {[expectedItemName] = expectedItemCount}
          local event = RobotEvent:new(
            RobotEvent.LABEL_ASSIGNED,
            {oldLabel = prevLabel, newLabel = expectedLabel}
          )
          local state = createState()
          addRobot(state, prevLabel, expectedEnergy, expectedInventory)
          assign(state, prevLabel, "Conveyor")
          local status, error = StateReducer:reduce(state, {event})
          assert(status, error)
          assert(not state.robots[prevLabel])
          assert(state.robots[expectedLabel])
          assertEq(state.robots[expectedLabel].energy.current, expectedEnergy)
          assertEq(state.robots[expectedLabel].inventory[expectedItemName], expectedItemCount)
          assert(not state.jobs.specs[1])
          assert(not state.jobs.assignments[prevLabel])
          assert(not state.jobs.assignments[expectedLabel])
        end,
    }
  },
  ["when asked to reduce a JOB_ASSIGNED RobotEvent"] = {
    ["for a free robot"] = {
      ["should successfully return the new state with the assigned robot"] = function()
        local label = "Robot"
        local conveyor = "Conveyor"
        local event = RobotEvent:new(
          RobotEvent.JOB_ASSIGNED,
          {label = label, conveyor = conveyor, phase = JobPhase.START}
        )
        local state = createState()
        addRobot(state, label)
        local status, error = StateReducer:reduce(state, {event})
        assert(status, error)
        assert(state.robots[label])
        assert(state.jobs.specs[1])
        assertEq(state.jobs.specs[1].conveyor, conveyor)
        assert(state.jobs.assignments[label])
        assertEq(state.jobs.assignments[label].jobId, 1)
        assertEq(state.jobs.assignments[label].phase, JobPhase.START)
      end
    },
    ["for an already assigned robot"] = {
      ["should successfully return the new state with the robot assigned a new job and the previous job removed"] = function()
        local label = "Robot"
        local conveyor = "Conveyor"
        local event = RobotEvent:new(
          RobotEvent.JOB_ASSIGNED,
          {label = label, conveyor = conveyor, phase = JobPhase.START}
        )
        local state = createState()
        addRobot(state, label)
        assign(state, label, conveyor, JobPhase.LOAD)
        local status, error = StateReducer:reduce(state, {event})
        assert(status, error)
        assert(state.robots[label])
        assertEq(#state.jobs.specs, 1)
        assert(state.jobs.specs[1])
        assertEq(state.jobs.specs[1].conveyor, conveyor)
        assert(state.jobs.assignments[label])
        assertEq(state.jobs.assignments[label].jobId, 1)
        assertEq(state.jobs.assignments[label].phase, JobPhase.START)
      end
    }
  },
  ["when asked to reduce a JOB_ADVANCED RobotEvent"] = {
    ["should successfully return the new state with the job with advanced phase"] = function()
      local label = "Robot"
      local conveyor = "Conveyor"
      local expectedPhase = JobPhase.UNLOAD
      local event = RobotEvent:new(
        RobotEvent.JOB_ADVANCED,
        {label = label, jobId = 1, phase = expectedPhase}
      )
      local state = createState()
      addRobot(state, label)
      assign(state, label, conveyor, JobPhase.START)
      local status, error = StateReducer:reduce(state, {event})
      assert(status, error)
      assert(state.robots[label])
      assertEq(#state.jobs.specs, 1)
      assert(state.jobs.specs[1])
      assertEq(state.jobs.specs[1].conveyor, conveyor)
      assert(state.jobs.assignments[label])
      assertEq(state.jobs.assignments[label].jobId, 1)
      assertEq(state.jobs.assignments[label].phase, expectedPhase)
    end
  },
  ["when is asked to reduce a STATUS_UPDATED StatusEvent"] = {
    ["should successfully return the new state with the adjusted status of the robot"] = function()
      local label = "Robot"
      local expectedEnergy = 8000
      local expectedItemName = "hash1"
      local expectedItemCount = 72
      local removedItemName = "hashToRemove"
      local removedItemCount = 32
      local prevInventory = {[removedItemName] = removedItemCount}
      local expectedInventory = {[expectedItemName] = expectedItemCount}
      local event = RobotEvent:new(
        StatusEvent.STATUS_UPDATED,
        {label = label, inventory = expectedInventory, energy = {current = expectedEnergy, max = 20000}}
      )
      local state = createState()
      addRobot(state, label, 12000, prevInventory)
      local status, error = StateReducer:reduce(state, {event})
      assert(status, error)
      assert(state.robots[label])
      assertEq(state.robots[label].energy.current, expectedEnergy)
      assertEq(state.robots[label].inventory[expectedItemName], expectedItemCount)
      assert(not state.robots[label].inventory[removedItemName])
    end
  }
}}}
)


return StateReducerSpec