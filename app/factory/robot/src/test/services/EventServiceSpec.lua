local Spec = sigma.test.TableSpec
local EventService = sigma.factory.robot.services.EventService
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

local function createRobotUpdate(robotLabel, what)
  return {
              firmware="1.0.0",
              label = robotLabel,
              what = what,
              nearestWaypoint = "v0",
              inventory = {},
              energy = {current = 12000, max = 20000}
            }
end

--[[
@param params: {
  expectedRobotLabel,
  newRobotLabel,
  conveyorLabel,
  nextJobPhase,
  isRobotAssigned
}
]]
local function createJobService(params)
  local JobService = {}
  function JobService:employNew()
    return params.newRobotLabel 
  end
  function JobService:createJob(rl) 
    assertEq(rl, params.expectedRobotLabel)
    return {conveyor = params.conveyorLabel, phase = JobPhase.START}
  end
  function JobService:advance(rl)
    assertEq(rl, params.expectedRobotLabel)
    return {id = params.jobId, phase = params.nextJobPhase}
  end
  function JobService:isAssigned(rl)
    assertEq(rl, params.expectedRobotLabel)
    return params.isRobotAssigned
  end
  return JobService
end

local EventServiceSpec = Spec:extend({spec = {
  ["EventService"] = {
    ["when an unlabeled robot"] = {
      ["asks for the next action"] = {
        ["detectRobotEvent"] = {
          ["should successfully return a LABEL_ASSIGNED robot event"] = function()
            local robotUpdate = createRobotUpdate(nil, "getNextAction")
            local expectedNewLabel = "robot"
            local jobService = createJobService(
              {
                expectedRobotLabel = nil,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                jobId = nil,
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local robotEvent, error = eventService:detectRobotEvent(robotUpdate)
            assertEq(robotEvent.name, RobotEvent.LABEL_ASSIGNED)
            assertEq(robotEvent.oldLabel, nil)
            assertEq(robotEvent.newLabel, expectedNewLabel)
            assertEq(error, nil)
          end,
        },
        ["detectStatusEvent"] = {
          ["should return nil without error"] = function()
            local robotUpdate = createRobotUpdate(nil, "getNextAction")
            local expectedNewLabel = "robot"
            local jobService = createJobService(
              {
                expectedRobotLabel = nil,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                jobId = nil,
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local statusEvent, error = eventService:detectStatusEvent(robotUpdate)
            assert(not statusEvent)
            assert(not error)
          end,
        },
        ["detectMachineEvent"] = {
          ["should return nil without error"] = function()
            local robotUpdate = createRobotUpdate(nil, "getNextAction")
            local expectedNewLabel = "robot"
            local jobService = createJobService(
              {
                expectedRobotLabel = nil,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                jobId = nil,
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local machineEvent, error = eventService:detectMachineEvent(robotUpdate)
            assert(not machineEvent)
            assert(not error)
          end,
        },
      },
      ["reports it's status"] = {
        ["detectRobotEvent"] = {
          ["should return nil without error"] = function()
            local robotUpdate = createRobotUpdate(nil, "reportStatus")
            local expectedNewLabel = "robot"
            local jobService = createJobService(
              {
                expectedRobotLabel = nil,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                jobId = nil,
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local robotEvent, error = eventService:detectRobotEvent(robotUpdate)
            assert(not robotEvent)
            assert(not error)
          end,
        },
        ["detectStatusEvent"] = {
          ["should return nil without error"] = function()
            local robotUpdate = createRobotUpdate(nil, "reportStatus")
            local expectedNewLabel = "robot"
            local jobService = createJobService(
              {
                expectedRobotLabel = nil,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                jobId = nil,
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local statusEvent, error = eventService:detectStatusEvent(robotUpdate)
            assert(not statusEvent)
            assert(not error)
          end,
        },
        -- ["detectMachineEvent"] = {
        --   ["should return nil without error"] = function()
        --     local robotUpdate = createRobotUpdate(nil, "reportStatus")
        --     local expectedNewLabel = "robot"
        --     local jobService = createJobService(
        --       {
        --         expectedRobotLabel = nil,
        --         newRobotLabel = expectedNewLabel,
        --         conveyorLabel = "conveyor",
        --         jobId = nil,
        --         nextJobPhase = JobPhase.START,
        --         isRobotAssigned = false
        --       }
        --     )
        --     local eventService = EventService:new(jobService)
        --     local machineEvent, error = eventService:detectMachineEvent(robotUpdate)
        --     assert(not machineEvent)
        --     assert(not error)
        --   end
        -- }
      },
    },
    ["when a labeled robot"] = {
      ["asks for the next action"] = {
        ["detectRobotEvent"] = {
          ["when the robot is not assigned any job"] = {
            ["should successfully return a JOB_ASSIGNED event"] = function()
              local robotLabel = "robot"
              local robotUpdate = createRobotUpdate(robotLabel, "getNextAction")
              local expectedNewLabel = nil
              local expectedConveyorLabel = "conveyor"
              local jobService = createJobService(
                {
                  expectedRobotLabel = robotLabel,
                  newRobotLabel = expectedNewLabel,
                  conveyorLabel = expectedConveyorLabel,
                  jobId = nil,
                  nextJobPhase = JobPhase.START,
                  isRobotAssigned = false
                }
              )
              local eventService = EventService:new(jobService)
              local robotEvent, error = eventService:detectRobotEvent(robotUpdate)
              assert(robotEvent)
              assert(not error)
              assertEq(robotEvent.name, RobotEvent.JOB_ASSIGNED)
              assertEq(robotEvent.conveyor, expectedConveyorLabel)
            end,
          },
          ["when the robot is assigned a job that only started"] = {
            ["should successfully return a JOB_ADVANCED event"] = function()
              local robotLabel = "robot"
              local robotUpdate = createRobotUpdate(robotLabel, "getNextAction")
              local expectedNewLabel = nil
              local expectedConveyorLabel = "conveyor"
              local expectedJobId = 1
              local expectedJobPhase = JobPhase.UNLOAD
              local jobService = createJobService(
                {
                  expectedRobotLabel = robotLabel,
                  newRobotLabel = expectedNewLabel,
                  conveyorLabel = expectedConveyorLabel,
                  jobId = expectedJobId,
                  nextJobPhase = expectedJobPhase,
                  isRobotAssigned = true
                }
              )
              local eventService = EventService:new(jobService)
              local robotEvent, error = eventService:detectRobotEvent(robotUpdate)
              assert(robotEvent)
              assert(not error)
              assertEq(robotEvent.name, RobotEvent.JOB_ADVANCED)
              assertEq(robotEvent.jobId, expectedJobId)
              assertEq(robotEvent.phase, expectedJobPhase)
            end,
          },
          ["when the robot is assigned a job that is on it's final phase"] = {
            ["should successfully return a JOB_ASSIGNED event"] = function()
              local robotLabel = "robot"
              local robotUpdate = createRobotUpdate(robotLabel, "getNextAction")
              local expectedNewLabel = nil
              local expectedConveyorLabel = "conveyor"
              local expectedJobId = 1
              local expectedJobPhase = nil
              local jobService = createJobService(
                {
                  expectedRobotLabel = robotLabel,
                  newRobotLabel = expectedNewLabel,
                  conveyorLabel = expectedConveyorLabel,
                  jobId = expectedJobId,
                  nextJobPhase = expectedJobPhase,
                  isRobotAssigned = true
                }
              )
              local eventService = EventService:new(jobService)
              local robotEvent, error = eventService:detectRobotEvent(robotUpdate)
              assert(robotEvent)
              assert(not error)
              assertEq(robotEvent.name, RobotEvent.JOB_ASSIGNED)
              assertEq(robotEvent.conveyor, expectedConveyorLabel)
            end,
          }
        },
        ["detectStatusEvent"] = {
          ["should return a STATUS_UPDATE event with robot's inventory and energy info"] = function()
            local robotLabel = "robot"
            local robotUpdate = createRobotUpdate(robotLabel, "getNextAction")
            local inventory = {
              ["hash1"] = 2,
              ["hash2"] = 4,
            }
            local energy = {
              current = 12000,
              max = 20000
            }
            robotUpdate.inventory = inventory
            robotUpdate.energy = energy
            local expectedNewLabel = nil
            local jobService = createJobService(
              {
                expectedRobotLabel = robotLabel,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local statusEvent, error = eventService:detectStatusEvent(robotUpdate)
            assertEq(statusEvent.name, StatusEvent.STATUS_UPDATED)
            assert(statusEvent.inventory, "inventory is nil")
            assert(statusEvent.energy, "energy is nil")
            assertEq(statusEvent.inventory["hash1"], 2)
            assertEq(statusEvent.inventory["hash2"], 4)
            assertEq(statusEvent.energy.current, 12000)
            assertEq(statusEvent.energy.max, 20000)
            assert(not error)
          end,
        },
        -- ["detectMachineEvent"] = {
        --   ["should return nil without error"] = function()

        --   end
        -- }
      },
      ["reports it's status"] = {
        ["detectRobotEvent"] = {
          ["should return nil without error"] = function()
            local robotLabel = "robot"
            local robotUpdate = createRobotUpdate(robotLabel, "reportStatus")
            local inventory = {
              ["hash1"] = 2,
              ["hash2"] = 4,
            }
            local energy = {
              current = 12000,
              max = 20000
            }
            robotUpdate.inventory = inventory
            robotUpdate.energy = energy
            local expectedNewLabel = nil
            local jobService = createJobService(
              {
                expectedRobotLabel = robotLabel,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local robotEvent, error = eventService:detectRobotEvent(robotUpdate)
            assert(not robotEvent, "robot event is not nil")
            assert(not error, "error is not nil")
          end,
        },
        ["detectStatusEvent"] = {
          ["should return a STATUS_UPDATE event with robot's inventory and energy info"] = function()
            local robotLabel = "robot"
            local robotUpdate = createRobotUpdate(robotLabel, "reportStatus")
            local inventory = {
              ["hash1"] = 2,
              ["hash2"] = 4,
            }
            local energy = {
              current = 12000,
              max = 20000
            }
            robotUpdate.inventory = inventory
            robotUpdate.energy = energy
            local expectedNewLabel = nil
            local jobService = createJobService(
              {
                expectedRobotLabel = robotLabel,
                newRobotLabel = expectedNewLabel,
                conveyorLabel = "conveyor",
                nextJobPhase = JobPhase.START,
                isRobotAssigned = false
              }
            )
            local eventService = EventService:new(jobService)
            local statusEvent, error = eventService:detectStatusEvent(robotUpdate)
            assertEq(statusEvent.name, StatusEvent.STATUS_UPDATED)
            assert(statusEvent.inventory, "inventory is nil")
            assert(statusEvent.energy, "energy is nil")
            assertEq(statusEvent.inventory["hash1"], 2)
            assertEq(statusEvent.inventory["hash2"], 4)
            assertEq(statusEvent.energy.current, 12000)
            assertEq(statusEvent.energy.max, 20000)
            assert(not error)
          end,
        },
        -- ["detectMachineEvent"] = {
        --   ["should return nil without error"] = function()
        --     local robotLabel = "robot"
        --     local robotUpdate = createRobotUpdate(robotLabel, "reportStatus")
        --     local inventory = {
        --       ["hash1"] = 2,
        --       ["hash2"] = 4,
        --     }
        --     local energy = {
        --       current = 12000,
        --       max = 20000
        --     }
        --     robotUpdate.inventory = inventory
        --     robotUpdate.energy = energy
        --     local expectedNewLabel = nil
        --     local jobService = createJobService(
        --       {
        --         expectedRobotLabel = robotLabel,
        --         newRobotLabel = expectedNewLabel,
        --         conveyorLabel = "conveyor",
        --         nextJobPhase = JobPhase.START,
        --         isRobotAssigned = false
        --       }
        --     )
        --     local eventService = EventService:new(jobService)
        --     local machineEvent, error = eventService:detectMachineEvent(robotUpdate)
        --     assert(not machineEvent)
        --     assert(not error)
        --   end
        -- }
      },
    },
  },
}}
)


return EventServiceSpec