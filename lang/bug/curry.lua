local function curry_add(a)
    return function(b) 
        if a == 0 or b == 0 then
            return math.max(a, b)
        else
            return curry_add(a-1, b+1)
        end
    end
end

