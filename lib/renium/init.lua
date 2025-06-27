local renium = {}

local filesystem = require("filesystem")
local text = require("text")
local thread = require("thread")
local process = require("process")
local computer = require("computer")
local math = require("math")

local registry = {}          --  ["sigma.util.Logger"] = loader-fn
local rootMetatable                 -- forward declare

local std = { "core", "fp", "concurrent" }

local function split(inputstr, sep)
    if sep == nil then
      sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
end

local function stripAfterLastDot(str)
    -- %.[^%.]*$  = a literal “.” followed by any non-“.” chars until end of string
    -- replace that with empty
    return (str:gsub("%.[^%.]*$", ""))
end

local function stripBeforeLastDot(str)
    return (str:gsub(".*%.", ""))
end  

local function resolvePackageName(packageName, root)
    root = root or _G
    local current = root
    for _, key in ipairs(split(packageName, ".")) do
      if type(current) ~= "table" then
        return nil, ("‘%s’ is not a table"):format(key)
      end
      current = current[key]
      if current == nil then
        return nil, ("no field ‘%s’"):format(key)
      end
    end
    return current
end


local function mkResolver(nodeName)
    return function(t, key)
      -- 1.  prepend the key to the path we’re in
      local fullName = rawget(t, "__fq") .. "." .. key   -- eg "sigma.util.Logger"
      local entry    = registry[fullName]
  
      -- 2a. If we know this exact class: load
      if entry then
        local module = entry()          -- run the loader, cache result
        rawset(t, key, module)
        return module
      end

      -- 2b.  Otherwise treat it as a sub-package
      local sub = { __fq = fullName }
      setmetatable(sub, rootMetatable)
      rawset(t, key, sub)
      return sub
    end
end

local function loadFile(filePath, fullName, env)
    registry[fullName] = function()
      local env = env or setmetatable({}, { __index = _G })
      local chunk, err = loadfile(filePath, "t", env)
      if not chunk then error(err) end 
      return chunk()
    end
end

local function loadDirectory(path, fullName, env)
    for el, msg in filesystem.list(path) do
        if el == nil then
            error("Error when loading the directory \"" .. path .. "\":\n" .. msg)
        end
        local elPath = filesystem.concat(path, el)
        local elName = filesystem.name(elPath)

        local dirMt = {
            __index = function(t, k)
                if env[k] then
                    return env[k]
                else
                    return resolvePackageName(table.concat({ fullName, k }, "."), env)
                end
            end
        }

        local dirT = {}
        setmetatable(dirT, dirMt)

        local dirEnv = {
            sub = dirT
        }

        setmetatable(
            dirEnv, {
                __index = env
            }
        )

        if el:match("^.*%/$") == nil then
            local name = split(elName, ".")[1]
            local fullElName = table.concat({fullName, name}, ".")
            loadFile(elPath, fullElName, dirEnv)
        else
            local fullElName = table.concat({fullName, elName}, ".")
            loadDirectory(elPath, fullElName, env)
        end
    end
end

local function loadCore(coreRootPath)
    for elName in filesystem.list(coreRootPath) do
        local elPath = filesystem.concat(coreRootPath, elName)
        local fullName = "sigma.renium.core." .. elName:gsub("%.lua$", "")
        loadFile(elPath, fullName)
    end
end

local function loadFp(fpRootPath)
    for elName in filesystem.list(fpRootPath) do
        local elPath = filesystem.concat(fpRootPath, elName)
        local fullName = "sigma.renium.fp." .. elName:gsub("%.lua$", "")
        loadFile(elPath, fullName)
    end
end

local function loadConcurrent(concurrentRootPath)
    for elName in filesystem.list(concurrentRootPath) do
        local elPath = filesystem.concat(concurrentRootPath, elName)
        local fullName = "sigma.renium.concurrent." .. elName:gsub("%.lua$", "")
        loadFile(elPath, fullName)
    end
end

local function unloadPackage(fullPackageName)
    local fullSuperPackageName = stripAfterLastDot(fullPackageName)
    local superPackage = resolvePackageName(fullSuperPackageName)
    local packageName = stripBeforeLastDot(fullPackageName)
    rawset(superPackage, packageName, nil)
end

local function unloadLoadPackage(path, target)
    local metaPath = filesystem.concat(path, "package.lua")
    local meta = {}
    if filesystem.exists(metaPath) then
        local ok, metaOrErr = pcall(dofile, metaPath)
        if ok then
            meta = metaOrErr
        else
            error("Error in meta for package \"%s\":\n%s", path, metaOrErr)
        end
    else
        io.stdout:write(string.format("\nNo meta file found for package \"%s\"\n", path))
    end

    local prefix = meta.prefix or "sigma"
    local version = meta.version or "latest"
    local targetDir = filesystem.concat(path, "src", target or "main")
    local name = meta.name or filesystem.name(path)
    local targetName = ""
    if target then
        targetName = "." .. target
    end
    local fullPackageName = prefix .. "."  .. name .. targetName --.. ":" .. version

    unloadPackage(fullPackageName)

    local packageMt = {
        __index = function(t, k)
            return resolvePackageName(table.concat({ fullPackageName, k }, "."), _G)
        end
    }
    local packageT = {}
    setmetatable(packageT, packageMt)
    local packageEnv = {
        this = packageT
    }

    setmetatable(packageEnv, {
        __index = function(t, k)
            if _G[k] then
                return _G[k]
            else
                for _, stdEl in ipairs(std) do
                    local entry = registry[table.concat( { "sigma.renium", stdEl, k }, ".")]
                    if entry then
                        local module = entry()
                        rawset(t, k, module)
                        return module
                    end
                end
                return nil
            end
        end
    })
    loadDirectory(targetDir, fullPackageName, packageEnv)

    return fullPackageName
end

local function loadLibraries(libRootPath)
    for pkg in filesystem.list(libRootPath) do
        local path = filesystem.concat(libRootPath, pkg)
        unloadLoadPackage(path)
    end
end

function renium.load(absolutePackagePath, target)
    checkArg(1, absolutePackagePath, "string")

    return unloadLoadPackage(absolutePackagePath, target)
end

function renium.run(fullPackageName, ...)
    checkArg(1, fullPackageName, "string")

    local package = resolvePackageName(fullPackageName)

    -- for k, v in pairs(registry) do
    --     print(tostring(k) .. " : " .. tostring(v))
    -- end

    if package == nil then
        error(string.format("Package \"%s\" is not loaded.", fullPackageName))
    end

    if type(package.Program) ~= "table" then
        error("\"Program\" class not found in the package root.")
    end 

    if type(package.Program.run) ~= "function" then
        error("\"run\" method not found in the \"Program\" class.")
    end

    local status, err = pcall(package.Program.run, arg)

    return status, err
end

function renium.test(fullPackageName)
    checkArg(1, fullPackageName, "string")

    local package = resolvePackageName(fullPackageName)

    if package == nil then
        error(string.format("Package \"%s\" is not loaded.", fullPackageName))
    end

    -- for k, v in pairs(registry) do
    --     print(tostring(k) .. " : " .. tostring(v))
    -- end

    -- a dirty and slow workaround
    local result = {}
    for k, v in pairs(registry) do
        if k:find(fullPackageName) then
            local entry = registry[k]
            local module = entry()
            local status, moduleResults = pcall(module.test, module) -- moduleResults is a tree
            local name = k:gsub(fullPackageName .. ".", "")
            if status then
                result[name] = moduleResults
            else
                result[name] = {status = false, error = moduleResults, traceback = debug.traceback()} -- here moduleResults will be an error message, becuase status == false
            end
        end
    end

    return result
end

rootMetatable = { __index = mkResolver() }
local sigma = { __fq = "sigma" }
setmetatable(sigma, rootMetatable)
_G["sigma"] = sigma             

loadCore("/usr/lib/renium/core/")
loadFp("/usr/lib/renium/fp/")
loadConcurrent("/usr/lib/renium/concurrent/")

loadLibraries("/usr/lib/sigma/")

return renium