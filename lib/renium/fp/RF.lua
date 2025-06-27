local RF = sigma.renium.core.Class:extend()

function RF.okT(o)
  return RF.pure({isOk = true, value = o})
end

function RF.errT(e)
  return RF.pure({isOk = false, error = e})
end


-- @param fo: F[O]
function RF.ok(fo)
  return RF.of(function() 
      local result = fo()
      return {isOk = true, value = result}
  end)
end

-- @param: fe: F[E]
function RF.err(fe)
  return RF.of(function() 
      local result = fe()
      return {isOk = false, error = result}
  end)
end


function RF.of(thunk)            -- thunk : () → a 
  return setmetatable({ run = thunk }, { __call = function(t) return t:run() end, __index = RF })
end

function RF.pure(value)
  return RF.of(function() return value end)
end

function RF:map(f)     
    return RF.of(function() 
        local result = self:run()
        if result.isOk then
            return {isOk = true, value = f(result.value)}
        else
            return result
        end
    end) 
end

function RF:flatMap(f) 
    return RF.of(function() 
        local result = self:run()
        if result.isOk then
            return f(result.value):run()
        else
            return result
        end
    end) 
end

function RF:toFr(F)
  return F.of(function()
    return self:run()
  end)
end

return RF
