-- logger.lua - Simple logging library for OpenComputers in Lua

local computer = require("computer")
local math = require("math")

local Logger = Class:extend()

Logger.Levels = {
    Debug    = 1,
    Info     = 2,
    Warning  = 3,
    Error    = 4,
    Critical = 5,
}

local function formatHMS(num)
    if num < 10 then
        return string.format("0%d", num)
    else 
        return string.format(num)
    end
end

local function formatMs(num)
    if num < 10 then
        return string.format("0%d", num)
    elseif num < 100 then
        return string.format("00%d", num)
    else 
        return string.format("%d", num)
    end
end

-- Constructor: Logger.new(provider[, minLevel])
-- provider: a function(entry) that handles the log string
-- minLevel: lowest level to log (defaults to Debug)
function Logger.new(provider, minLevel)
    local self = Logger:extend()
    self.provider = provider or Logger.providers.console()
    self.minLevel = minLevel or Logger.Levels.Debug
    return self
end

function Logger:log(levelName, ...)
    local level = Logger.Levels[levelName]
    if not level then error("Invalid log level: " .. tostring(levelName)) end
    if level < self.minLevel then return end

    local time = computer.uptime()
    local hours = math.floor(time / 3600)
    local remaining = time % 3600
    local minutes = math.floor(remaining / 60)
    remaining = remaining % 60
    local seconds = math.floor(remaining)
    local milliseconds = math.floor(1000 * (remaining - seconds))

    local hoursStr = formatHMS(hours)
    local minutesStr = formatHMS(minutes)
    local secondsStr = formatHMS(seconds)
    local millisecondsStr = formatMs(milliseconds)

    local ts = string.format("%s:%s:%s.%s", hoursStr, minutesStr, secondsStr, millisecondsStr)
    local msg = table.concat({...}, " ")
    local entry = string.format("%s [%s] %s", ts, levelName:upper(), msg)

    local ok, err = pcall(self.provider, entry)
    if not ok then
        io.stderr:write("Logger provider error: " .. tostring(err) .. "\n")
    end
end

function Logger:debug(...)    self:log("Debug", ...)    end
function Logger:info(...)     self:log("Info", ...)     end
function Logger:warning(...)  self:log("Warning", ...)  end
function Logger:error(...)    self:log("Error", ...)    end
function Logger:critical(...) self:log("Critical", ...) end

Logger.providers = {}

function Logger.providers.console()
    return function(entry)
        print(entry)
    end
end
function Logger.providers.file(path)
    return function(entry)
        local file, err = io.open(path, "a")
        if not file then error("Failed to open log file: " .. tostring(err)) end
        file:write(entry, "\n")
        file:close()
    end
end

function Logger.providers.consoleAndFile(path)
    local c = Logger.providers.console()
    local f = Logger.providers.file(path)
    return function(entry)
        c(entry)
        f(entry)
    end
end

return Logger