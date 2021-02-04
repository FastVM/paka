local Q = function(f)
    return function(a)
        return f(f)(a)
    end
end

local F = function(f)
    return function (a)
        if a < 2 then
            return a
        else
            return Q(f)(a - 1) + Q(f)(a - 2)
        end
    end
end

print(Q(F)(30))