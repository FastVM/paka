local is_prime = function (num)
    for test=2, num-1 do
        if num % test == 0 then
            return false
        end
    end
    return true
end

local sum_primes = function (upto)
    local ret = 0
    local at = 2
    while at < upto do
        if is_prime(at) then
            ret = ret + at
        end
        at = at + 1
    end
    return ret
end

local res = sum_primes(50000)
print(res)