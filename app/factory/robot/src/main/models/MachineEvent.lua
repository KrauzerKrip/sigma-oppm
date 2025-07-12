local MachineEvent = {
    TRANSFERRED_TO = "TRANSFERRED_TO",
    TRANSFERRED_FROM = "TRANSFERRED_FROM",

    name = nil
}

function MachineEvent:new(name, parameters)
    local t = {
        name = name
    }
    local mt = {
        -- __eq = function(a, b)
        --     if getmetatable(a) == getmetatable(b) then
        --         return a.name == b.name
        --     else
        --         error("Trying to compare an event with something else")
        --     end
        -- end
    }

    for k,v in pairs(parameters) do
        t[k] = v
    end

    setmetatable(t, mt)

    return t
end

return MachineEvent