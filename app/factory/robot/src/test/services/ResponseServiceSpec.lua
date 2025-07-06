local Spec = sigma.test.TableSpec
local ResponseService = sigma.factory.robot.services.ResponseService
local RobotEvent = sigma.factory.robot.models.RobotEvent
local JobPhase = sigma.factory.robot.models.JobPhase
local math = require("math")
local computer = require("computer")
local sides = require("sides")


local oldLabel = "LABEL-Old"
local newLabel = "LABEL-New"
local label = "LABEL"
local startWaypoint = "vstart"
local endWaypoint = "vend"
local unloadWaypoint = "vunload"
local carryWaypoint = "vpath"
local startPath = {startWaypoint, unloadWaypoint}
local carryPath = {carryWaypoint, endWaypoint}
local returnPath = {endWaypoint, carryWaypoint, unloadWaypoint} -- the start of the new job, so the robot should get to the nearest (end) waypoint first
local side = sides.posx
local machineStart = {label = "machineStart", output = {node = unloadWaypoint, facing = side, slot = 2}}
local machineEnd = {label = "machineEnd", input = {node = endWaypoint, facing = side, slot = 7}}
local machines = {[machineStart.label] = machineStart, [machineEnd.label] = machineEnd}
local conveyor = {label = "Conveyor", from = machineStart.label, to = machineEnd.label, threshold = 10, count = 1}
local conveyors = {[conveyor.label] = conveyor}

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

local function getNavService(path, facing)
  local NavService = Class:extend()
  function NavService:getPath(from, to)
   return path
  end
  function NavService:getFacing(node)
   return facing
  end
  return NavService
end

local function getJobSpecGetter(jobSpec)
  return function(jobId) return jobSpec end
end

local ResponseServiceSpec = Spec:extend({spec = {
  ["ResponseService"] = {
    ["when the robot event is LABEL_ASSIGNED"] = {
      ["should successfully return assign response to a new robot"] = function()
        local robotEvent = RobotEvent:new(
          RobotEvent.LABEL_ASSIGNED,
          {oldLabel = nil, newLabel = newLabel}
        )
        local responseService = ResponseService:new({
          navService = getNavService(nil, nil),
          getJobSpec = getJobSpecGetter(nil),
          conveyors = nil,
          machines = nil
        })
        local response, error = responseService:getResponse(robotEvent, nil)
        assert(response, "response is nil")
        assert(response.action, "response.action is nil")
        assert(response.action.what == "assign", "response.action is not 'assign'")
        assert(response.action.label == newLabel, "response.action.label is not 'LABEL-New'")
      end,
      ["should successfully return assign response to an already labeled robot"] = function()
        local robotEvent = RobotEvent:new(
          RobotEvent.LABEL_ASSIGNED,
          {oldLabel = oldLabel, newLabel = newLabel}
        )
        local responseService = ResponseService:new({
          navService = getNavService(nil, nil),
          getJobSpec = getJobSpecGetter(nil),
          conveyors = nil,
          machines = nil
        })
        local response, error = responseService:getResponse(robotEvent, nil)
        assert(response, "response is nil")
        assert(response.action, "response.action is nil")
        assert(response.action.what == "assign", "response.action is not 'assign'")
        assert(response.action.label == newLabel, "response.action.label is not " .. newLabel)
      end,
    },
    ["when the robot event is JOB_ASSIGNED"] = {
      ["should successfully return go response with path to the machine to unload"] = function()
        local robotEvent = RobotEvent:new(
          RobotEvent.JOB_ASSIGNED,
          {label = label, jobId = 1}
        )
        local responseService = ResponseService:new({
          navService = getNavService(startPath, side),
          getJobSpec = getJobSpecGetter({conveyor = conveyor.label}),
          conveyors = conveyors,
          machines = machines
        })
        local response, error = responseService:getResponse(robotEvent, startWaypoint)
        assert(response, "response is nil")
        assert(response.action, "response.action is nil")
        assert(response.action.what == "go")
        assert(compareLists(response.action.path, startPath))
      end,
    },
    ["when the robot event is JOB_ADVANCED"] = {
      ["advanced to phase UNLOAD"] = {
        ["should successfully return take response with correct facing, slot, threshold and count"] = function()
          local robotEvent = RobotEvent:new(
            RobotEvent.JOB_ADVANCED,
            {label = label, jobId = 1, phase = JobPhase.UNLOAD}
          )
          local responseService = ResponseService:new({
            navService = getNavService(startPath, side),
            getJobSpec = getJobSpecGetter({conveyor = conveyor.label}),
            conveyors = conveyors,
            machines = machines
          })
          local response, error = responseService:getResponse(robotEvent, unloadWaypoint)
          assert(response, "response is nil")
          assert(response.action, "response.action is nil")
          assert(response.action.what == "take")
          assert(response.action.from.facing == side)
          assert(response.action.from.slot == machineStart.output.slot)
          assert(response.action.threshold == conveyor.threshold)
          assert(response.action.count == conveyor.count)
        end,
      },
      ["advanced to phase CARRY"] = {
        ["should successfully return go response with path to the machine to load"] = function()
          local robotEvent = RobotEvent:new(
            RobotEvent.JOB_ADVANCED,
            {label = label, jobId = 1, phase = JobPhase.CARRY}
          )
          local responseService = ResponseService:new({
            navService = getNavService(carryPath, side),
            getJobSpec = getJobSpecGetter({conveyor = conveyor.label}),
            conveyors = conveyors,
            machines = machines
          })
          local response, error = responseService:getResponse(robotEvent, unloadWaypoint)
          assert(response, "response is nil")
          assert(response.action, "response.action is nil")
          assert(compareLists(response.action.path, carryPath))
        end,
      },
      ["advanced to phase LOAD"] = {
        ["should successfully return put response with correct facing, slot, and count"] = function()
          local robotEvent = RobotEvent:new(
            RobotEvent.JOB_ADVANCED,
            {label = label, jobId = 1, phase = JobPhase.LOAD}
          )
          local responseService = ResponseService:new({
            navService = getNavService(carryPath, side),
            getJobSpec = getJobSpecGetter({conveyor = conveyor.label}),
            conveyors = conveyors,
            machines = machines
          })
          local response, error = responseService:getResponse(robotEvent, endWaypoint)
          assert(response, "response is nil")
          assert(response.action, "response.action is nil")
          assert(response.action.what == "put")
          assert(response.action.to.facing == side)
          assert(response.action.to.slot == machineEnd.input.slot)
          assert(response.action.count == conveyor.count)
        end,
      },
    },
  }
}})


return ResponseServiceSpec