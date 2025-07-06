local NavService = Class:extend()

local PriorityQueue = this.util.PriorityQueue


-- @param graph: graph as adjacency lists with distances ({"v1" = {"v2" = 2.0}, "v2" = {"v1" = 2.0}}).
--        Graph should be a simple graph (no multiple (parallel) edges between the same two vertices, and no self-loops) with positive weights
function NavService:new(graph)
  return self:extend({graph = graph})
end

-- Djikstra
-- @param graph: graph as adjacency lists with distances ({"v1" = {"v2" = 2.0}, "v2" = {"v1" = 2.0}}).
--        Graph should be a simple graph (no multiple (parallel) edges between the same two vertices, and no self-loops) with positive weights
-- @param start: the name of the initial node
-- @param target: the name of the destination node
-- @returns 
--    path: the table of connected versices forming the shortest past to the target ({"v1" = "v2", "v2" = "v3"}),
--    distance: the distance from start to target (the shortest path)
local function findShortestPath(graph, start, target)
  local queue = PriorityQueue();
  local seen = {}
  local distances = {}
  local previous = {}
  for k,v in pairs(graph) do distances[k] = math.huge end
  distances[start] = 0
  queue:enqueue(start, 0)

  repeat
    local minDistanceNode, minDistance = queue:dequeue()

    if not minDistanceNode then
      return nil, nil, "can't find a node with minimal distance"
    end

    for k,v in pairs(graph[minDistanceNode]) do
      if not seen[k] then
        local vMinDistance = minDistance + v
        if not distances[k] then
          return nil, nil, [["
          the graph is misconfigured, and has an adjacent node " .. tostring(k) .. " that isn't in graph. 
          Please keep in mind that the graph should be represented in the form of adjacency lists.
          "]]
        end
        if vMinDistance < distances[k] then
          --print("Changing distance " .. tostring(distances[k]) .. " to " .. tostring(vMinDistance) .. " for " ..k)
          distances[k] = vMinDistance
          previous[k] = minDistanceNode
          local status, error
          if queue:contains(k) then
            status, error = pcall(queue.update, queue, k, vMinDistance)
          else
            status, error = pcall(queue.enqueue, queue, k, vMinDistance)
          end
          if not status then
            return nil, nil, "the graph is misconfigured, error when processing node " ..
              tostring(minDistanceNode) .. " on adjacent node " .. tostring(k) .. ": " .. error
          end
        end
      else
        --print("Has already seen " .. k)
      end
    end

    seen[minDistanceNode] = true
  until queue:empty()

  -- unwind
  local path = {}
  local distance = distances[target]
  if distance ~= math.huge and distance ~= -math.huge then
    for k,v in pairs(previous) do
      path[v] = k
    end
  end

  return path, distances
end

function NavService:getPath(from, to)
  local tablePath, distances, error = findShortestPath(self.graph, from, to)
  if not tablePath then
    return nil, nil, error
  end
  local listPath = {}
  local function traverse(node)
    if node then
      --print("Distance to " .. node .. " == " .. distances[node])
      table.insert(listPath, node)
      traverse(tablePath[node])
    end
  end
  traverse(from)
  return listPath, distances[to]
end

return NavService