local Spec = sigma.test.TableSpec
local JobService = sigma.factory.robot.services.JobService
local JobPhase = sigma.factory.robot.models.JobPhase
local sides = require("sides")

local conveyor1 = {label = "Conveyor1", from = "machineStart", to = "machineEnd", threshold = 10, count = 1}
local conveyor2 = {label = "Conveyor2", from = "machineStart", to = "machineEnd", threshold = 10, count = 1}
local conveyor3 = {label = "Conveyor3", from = "machineStart", to = "machineEnd", threshold = 10, count = 1}
local conveyors = {
  [conveyor1.label] = conveyor1,
  [conveyor2.label] = conveyor2,
  [conveyor3.label] = conveyor3
}

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

local function getJobSpecsGetter(jobSpecs)
  return function(jobId) return jobSpecs[jobId] end
end

local function getAssignmentsGetter(assignments)
  return function() return assignments end
end

local JobServiceSpec = Spec:extend({spec = {
  ["JobService"] = {
    ["when is asked for a label for a new robot"] = {
      ["every conveyor is free"] = {
        ["should successfully return a label of a conveyor for the robot to work on"] = function()
          local assignments = {}
          local jobSpecs = {}
          local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(assignments),
            getJobSpec = getJobSpecsGetter(jobSpecs),
            conveyors = conveyors
          })
        local robotLabel, error = jobService:employNew()
        assert(robotLabel, "robot label is nil: " .. tostring(error))
        assert(
          robotLabel == "CONVEYOR-" .. conveyor1.label .. ":1" or 
          robotLabel == "CONVEYOR-" .. conveyor2.label .. ":1" or
          robotLabel == "CONVEYOR-" .. conveyor3.label .. ":1",
          "unexpected label: " .. tostring(label)
        )
      end,
      },
      ["one conveyor is free"] = {
        ["should successfully return a label of the conveyor for the robot to work on"] = function()
          local assignments = {
            ["CONVEYOR-Conveyor1-ROBOT"] = {
              jobId = 1,
            },
            ["CONVEYOR-Conveyor2-ROBOT"] = {
              jobId = 2,
            },
          }
          local jobSpecs = {
            [1] = {conveyor = conveyor1.label},
            [2] = {conveyor = conveyor2.label}
          }
          local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(assignments),
            getJobSpec = getJobSpecsGetter(jobSpecs),
            conveyors = conveyors
          })
        local robotLabel, error = jobService:employNew()
        assert(robotLabel, "robot label is nil: " .. tostring(error))
        assert(
          robotLabel == "CONVEYOR-" .. conveyor3.label .. ":1",
          "unexpected robot label: " .. tostring(robotLabel)
        )
      end,
      },
      ["no conveyor is free"] = {
        ["should return nil and error"] = function()
          local assignments = {
            ["CONVEYOR-Conveyor1-ROBOT"] = {
              jobId = 1,
            },
            ["CONVEYOR-Conveyor2-ROBOT"] = {
              jobId = 2,
            },
            ["CONVEYOR-Conveyor3-ROBOT"] = {
              jobId = 3,
            },
          }
          local jobSpecs = {
            [1] = {conveyor = conveyor1.label},
            [2] = {conveyor = conveyor2.label},
            [3] = {conveyor = conveyor3.label}
          }
          local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(assignments),
            getJobSpec = getJobSpecsGetter(jobSpecs),
            conveyors = conveyors
          })
          local robotLabel, error = jobService:employNew()
          assert(not robotLabel, "robot label is not nil")
          assert(error, "error is nil")
        end,
    }
  },
  ["when is asked to create a job on the conveyor for a robot"] = {
    ["should successfully return a label of the conveyor for the robot to work on"] = function()
      local robotLabel = "CONVEYOR-" .. conveyor1.label .. ":1"
      local assignments = {}
      local jobSpecs = {}
      local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(assignments),
            getJobSpec = getJobSpecsGetter(jobSpecs),
            conveyors = conveyors
          })
      local job, error = jobService:createJob(robotLabel)
      assert(job, "job is nil: " .. tostring(error))
      assert(job.conveyor == conveyor1.label, "unexpected job conveyor label: " .. tostring(job.conveyor))
      assert(job.phase == JobPhase.START, "unexpected job phase: " .. tostring(job.phase))
    end,
  },
  ["when is asked to advance job phases"] = {
    ["should successfully advance job phases"] = function()
      local phases = {JobPhase.START, JobPhase.UNLOAD, JobPhase.CARRY, JobPhase.LOAD}
      local expectedPhases = {JobPhase.UNLOAD, JobPhase.CARRY, JobPhase.LOAD, nil}
      local phaseConveyors = {}
      for i=1,4 do
        local conveyor = {
          label = "Conveyor_PHASE_TEST_ADVANCE_FROM" .. phases[i],
          from = "machineStart",
          to = "machineEnd"
        }
        table.insert(phaseConveyors, conveyor)
      end
      local robots = {}
      for i,v in ipairs(phaseConveyors) do
        local robotLabel = "CONVEYOR-" .. v.label .. ":1"
        table.insert(robots, robotLabel)
      end
      local jobSpecs = {}
      local assignments = {}
      for i,robotLabel in ipairs(robots) do
        local assignment = {jobId = i, phase = phases[i]}
        assignments[robotLabel] = assignment
        jobSpecs[i] = {conveyor = phaseConveyors[i]}
      end
      local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(assignments),
            getJobSpec = getJobSpecsGetter(jobSpecs),
            conveyors = conveyors
          })
      for i, robotLabel in ipairs(robots) do
        local jobPhase = jobService:advance(robotLabel)
        assert(
          jobPhase == expectedPhases[i],
          string.format(
            "expected job phase %s, but got %s",
            tostring(expectedPhases[i]),
            tostring(jobPhase)
          )
        )
      end
    end,
  }
}}}
)


return JobServiceSpec