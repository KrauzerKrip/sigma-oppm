local Class = {}

function Class:extend(object)
    local newObject = setmetatable(object or {}, self)
    self.__index = self

    return newObject
end

return Class