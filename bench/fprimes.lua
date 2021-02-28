local function sum_primes(upto)
    local function is_prime(num)
        local test = 2
        while test * test <= num do
            if num % test == 0 then
                return false
            end
            test = test + 1
        end
        return true
    end
    local ret = 0
    local at = 2
    while at < upto do
        if is_prime(at) then
            ret = ret + 1
        end
        at = at + 1
    end
    return ret
end

local res = sum_primes(1000000)
print(res)