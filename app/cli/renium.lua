local shell = require("shell")
local filesystem = require("filesystem")
local computer = require("computer")
local term = require("term")

local gpu = term.gpu()

local textColors = {
    ERROR = 0xFF0000,
    OK = 0x00FF00,
    WARNING = 0xFFFF00,
    INFO = 0x808080,
    HEADER = 0x00FFFF,
    FOOTER = 0x00FFFF
}

local TEST_TREE_INDENT_FACTOR = 2
local TIME_COLUMN_INDENT = 16

local renium = require("renium")

local params, options = shell.parse(...)

local function formatMs(num)
    if num < 10 then
        return string.format("00%d", num)
    elseif num < 100 then
        return string.format("0%d", num)
    else 
        return string.format("%d", num)
    end
end

local function getTimeStr(time)
    local milliseconds = math.floor(time * 1000)
    return string.format("%d", milliseconds)
end

local function getIndent(level)
    return string.rep(" ", TEST_TREE_INDENT_FACTOR * level)
end

local function getTimeColumnIndent(leafCharCount, largestLeafCharCount)
    return largestLeafCharCount - leafCharCount + TIME_COLUMN_INDENT
end

if params[1] == "run" then
    local path = shell.resolve(params[2])
    local name = filesystem.name(path)
    
    io.stdout:write(string.format("Renium v0.0.3\n\nLoading \"%s\"...\n", name))

    local loadingStartTime = computer.uptime()

    local package = renium.load(path)

    local loadingTimeStr = getTimeStr(computer.uptime() - loadingStartTime)

    io.stdout:write(string.format("\nLoaded \"%s\" in %s ms.\nRunning...\n\n", name, loadingTimeStr))

    local runStartTime = computer.uptime()

    local status, err = renium.run(package --[[Here go params for the program itself]])
    
    local runTimeStr = getTimeStr(computer.uptime() - runStartTime)

    if status then
        io.stdout:write(string.format("\nFinished running \"%s\" in %s ms.", name, runTimeStr))
    else
        io.stderr:write(string.format("\nUncaught error: %s\n%s\n\nRun of \"%s\" terminated in %s ms.", err, debug.traceback(), name, runTimeStr))
    end
elseif params[1] == "test" then
    local path = shell.resolve(params[2])
    local name = filesystem.name(path)
    local verbose = options["v"]

    math.randomseed(computer.uptime())
    local seed = math.floor(math.random(100000, 999999))
    math.randomseed(seed)

    gpu.setForeground(textColors.INFO)
    
    io.stdout:write(string.format("Renium-Test v0.0.3 (seed %s)\n\nLoading \"%s\":\n", tostring(seed), name))

    local loadingStartTime = computer.uptime()

    renium.load(path) -- make sure the main target is (re)loaded as well
    local packageName = renium.load(path, "test")

    local loadingTimeStr = getTimeStr(computer.uptime() - loadingStartTime)

    io.stdout:write(string.format("Loaded \"%s\" in %s ms.\n", name, loadingTimeStr))

    gpu.setForeground(textColors.HEADER)
    io.stdout:write("\nRunning:\n")

    local runStartTime = computer.uptime()

    local results = renium.test(packageName)
    
    local testTimeStr = getTimeStr(computer.uptime() - runStartTime)

    local testCount = 0
    local passedCount = 0
    local failedCount = 0

    local largestLeafCharCount = 0

    local function traverseBranch(name, branch, level)
        local level = level or 0

        if branch.isLeaf then
            local leafCharCount = #name + #getIndent(level)
            if largestLeafCharCount < leafCharCount then
                largestLeafCharCount = leafCharCount
            end
            testCount = testCount + 1
            local status = branch.status
            if status then
                passedCount = passedCount + 1
            else
                failedCount = failedCount + 1
            end
            return status
        end

        local allPassed = true

        for k, v in pairs(branch) do
            if type(v) == "table" then
                v._status = traverseBranch(k, v, level + 1)
                allPassed = allPassed and v._status
            end
        end

        return allPassed
    end

    local DECORATION_CHAR_COUNT = 3 --\n .. ✓/✗ .. " " 

    local function printLeaf(name, leaf, level)
        local char = nil
        if leaf.status then
            char = "✓"
            gpu.setForeground(textColors.OK)
        else
            char = "✗"
            gpu.setForeground(textColors.ERROR)
        end
        local leafText = string.format("\n%s%s %s", getIndent(level), char, name)
        io.stdout:write(
            string.format(
                "%s%s(%s ms)",
                leafText,
                string.rep(" ", getTimeColumnIndent(#leafText, largestLeafCharCount + DECORATION_CHAR_COUNT)),
                getTimeStr(leaf.time)
            )
        )
        if not leaf.status then
            if leaf.error then
                io.stdout:write(string.format("\n%s%s", getIndent(level + 1), leaf.error))
            end
            if leaf.traceback and verbose then
                io.stdout:write(string.format("\n%s%s", getIndent(level + 1), leaf.traceback))
            end
        end
    end

    local function printBranch(name, branch, level)
        local level = level or 0

        if branch.isLeaf then
            printLeaf(name, branch, level)
        else
            if branch._status then
                gpu.setForeground(textColors.OK)
                io.stdout:write(string.format("\n%s✓ %s", getIndent(level), name))
            else
                gpu.setForeground(textColors.ERROR)
                io.stdout:write(string.format("\n%s✗ %s", getIndent(level), name))
            end

            for k, v in pairs(branch) do
                if type(v) == "table" then
                    printBranch(k, v, level + 1)
                end
            end
        end
    end

    local packageStatus = traverseBranch(name, results)
    results._status = packageStatus
    printBranch(name, results)

    gpu.setForeground(textColors.FOOTER)

    io.stdout:write(string.format("\n\n== %d tests, %d passed, %d failed in %s ms ==", testCount, passedCount, failedCount, testTimeStr))
end