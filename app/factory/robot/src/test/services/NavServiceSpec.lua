local Spec = sigma.test.TableSpec
local NavService = sigma.factory.robot.services.NavService
local sides = require("sides")

-- v1 1-> v2
-- v1 7-> v3
-- v1 100500-> v5
-- v2 2-> v3
-- v3 1-> v4
-- v3 10-> v5
-- v4 4-> v5

-- shortest path: v1 -> v2 -> v3 -> v4 -> v5 = (1 + 2 + 1 + 4) = 8

local graph = {
  ["v1"] = {
    ["v2"] = 1,
    ["v3"] = 7,
    ["v5"] = 100500
  },
  ["v2"] = {
    ["v3"] = 2,
    ["v1"] = 1,
  },
  ["v3"] = {
    ["v4"] = 1,
    ["v5"] = 10,
    ["v1"] = 7,
    ["v2"] = 2,
  },
  ["v4"] = {
    ["v5"] = 4,
    ["v3"] = 1,
  },
  ["v5"] = {
    ["v4"] = 4,
    ["v1"] = 100500,
    ["v3"] = 10 
  }
}

local from = "v1"
local to = "v5"

local expectedPath = {"v1", "v2", "v3", "v4", "v5"}
local expectedDistance = 8

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

local NavServiceSpec = Spec:extend({spec = {
  ["NavService"] = {
    ["when the graph is correct, but has duplicated paths"] = {
      ["should successfully the shortest path and distance"] = function()
        local navService = NavService:new(graph)
        local path, distance, error = navService:getPath(from, to)
        assert(path, "path is nil: " .. tostring(error))
        assert(compareLists(path, expectedPath))
        assert(distance == expectedDistance, "distance " .. tostring(distance) .. " isn't expected")
      end,
  }
}}}
)


return NavServiceSpec