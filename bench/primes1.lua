local upto = 20000
local ret = 0
local at = 2
while at < upto do
    local is_prime = true
    test = 2
    while test < at do
        if at % test < 1 then
            is_prime = false
        end
        test = test + 1
    end
    if is_prime then
        ret = ret + 1
    end
    at = at + 1
end

print(ret)