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
    ["when is asked for a conveyor for a new robot"] = {
      ["every conveyor is free"] = {
        ["should successfully return a label of a conveyor for the robot to work on"] = function()
          local assignments = {}
          local jobSpecs = {}
          local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(assignments),
            getJobSpec = getJobSpecsGetter(jobSpecs),
            conveyors = conveyors
          })
        local label, error = jobService:employNew()
        assert(label, "conveyor label is nil: " .. tostring(error))
        assert(
          label == conveyor1.label or 
          label == conveyor2.label or
          label == conveyor3.label,
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
        local label, error = jobService:employNew()
        assert(label, "conveyor label is nil: " .. tostring(error))
        assert(
          label == conveyor3.label,
          "unexpected label: " .. tostring(label)
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
          local label, error = jobService:employNew()
          assert(not label, "conveyor label is not nil")
          assert(error, "error is nil")
        end,
    }
  },
  ["when is asked to create a job on the conveyor"] = {
    ["should successfully return a label of the conveyor for the robot to work on"] = function()
      local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(nil),
            getJobSpec = getJobSpecsGetter(nil),
            conveyors = conveyors
          })
      local job = JobService:createJob(conveyor1.label)
      assert(job, "job is nil")
      assert(job.conveyor == conveyor1.label, "unexpected job conveyor label: " .. tostring(job.conveyor))
      assert(job.phase == JobPhase.START, "unexpected job phase: " .. tostring(job.phase))
    end,
  },
  ["when is asked to advance job phases"] = {
    ["should successfully advance job phases"] = function()
      local jobService = JobService:new({
            getAssignments = getAssignmentsGetter(nil),
            getJobSpec = getJobSpecsGetter(nil),
            conveyors = conveyors
          })
      local jobPhase1 = JobService:advance(JobPhase.START)
      local jobPhase2 = JobService:advance(JobPhase.UNLOAD)
      local jobPhase3 = JobService:advance(JobPhase.CARRY)
      local jobPhase4 = JobService:advance(JobPhase.LOAD)
      assert(jobPhase1 == JobPhase.UNLOAD, "job phase is " .. tostring(jobPhase1))
      assert(jobPhase2 == JobPhase.CARRY, "job phase is " .. tostring(jobPhase2))
      assert(jobPhase3 == JobPhase.LOAD, "job phase is " .. tostring(jobPhase3))
      assert(jobPhase4 == nil, "job phase is not nil")
    end,
  }
}}}
)


return JobServiceSpec