local is_prime = function (num)
    local test = 2
    while test < num do
        if num % test == 0 then
            return false
        end
        test = test + 1
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

local res = sum_primes(20000)
print(res)