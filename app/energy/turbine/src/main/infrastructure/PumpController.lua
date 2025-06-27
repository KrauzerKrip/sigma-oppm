local PumpController = Class:extend()

local VALUE_ACTIVE = 255
local VALUE_INACTIVE = 0

function PumpController.new(throttle_side, throttle_color, redstone)
    return PumpController:extend({
        throttle_side = throttle_side,
        throttle_color = throttle_color,
        redstone = redstone
    })
end

function PumpController:activate()
    return RF.ok(function() 
        self.redstone.setBundledOutput(self.throttle_side, self.throttle_color, VALUE_ACTIVE)
    end)
end

function PumpController:deactivate()
    return RF.ok(function() 
        self.redstone.setBundledOutput(self.throttle_side, self.throttle_color, VALUE_INACTIVE)
    end)
end

function PumpController:isActivated()
    local value = self.redstone.getBundledOutput(self.throttle_side, self.throttle_color)
    if value == VALUE_ACTIVE then
        return RF.okT(true)
    elseif value == VALUE_INACTIVE then
        return RF.okT(false)
    else
        return RF.errT(string.format("Invalid bundled output (side: %d, color: %d) value: %s", self.throttle_side, self.throttle_color, tostring(value)))
    end
end

return PumpController