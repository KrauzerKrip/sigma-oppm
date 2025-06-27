local Resource = sigma.renium.core.Class:extend()

-- Make a resource
-- @param acquire: F[A]
-- @return f: (r: (A) => F[nil]) => Resource[F[A]]
function Resource.make(acquire)
    return function(release)
        return Resource:extend({ _acquire = acquire, _release = release })
    end
end

function Resource:use(f)
    checkArg(1, f, "function")

    function loop(r, frame)
        if r._acquire then
            for k,v in pairs(r._acquire) do print(tostring(k) .. " : " ..tostring(v)) end
            return r._acquire:flatMap(function(res)
                local result = f(res)
                -- Ensure resource is released after use
                return result:flatMap(function(value)
                    return r._release(res):map(function() return value end)
                end)
            end)
        elseif r._pure then
            return f(r._pure)
        elseif r._outer then
            return r._outer:use(function(outerValue)
                local innerResource = r._fIn(outerValue)
                return innerResource:use(f)
            end)
        else
            error("Invalid resource type")
        end
    end

    return loop(self)
end
  
function Resource.pure(value) return Resource:extend({ _pure = value }) end

function Resource:map(f) return self:flatMap(function(a) return Resource.pure(f(a)) end) end

-- @param f: (A) => Resource[F[B]]
function Resource:flatMap(f) return Resource:extend({ _outer = self, _fIn = f }) end


return Resource