local computer = require("computer")

local FreeSpec = Class:extend()

function FreeSpec.new(spec)
    return FreeSpec:extend({spec = spec})
end

function FreeSpec:test()
    local function traverseTest(entry)
        if type(entry) == "function" then
            local startTime = computer.uptime()
            local status, err = pcall(function() return entry()() end) --entry here is a method returning a monad so call twices
            local finishTime = computer.uptime()
            local traceback = nil
            if err then
                traceback = debug.traceback()
            end
            return {isLeaf = true, status = status, error = err, traceback = traceback, time = finishTime - startTime}
        elseif type(entry) == "table" then
            local results = {}
            for k, v in pairs(entry) do
                results[k] = traverseTest(v)
            end
            return results
        end
    end

    return traverseTest(self.spec)
end

return FreeSpec

