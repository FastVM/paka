local sum = 0
local cur = 2
while cur < 10000 do
    local test = 2
    local is_prime = true
    while test < cur do
        if cur % test == 0 then
            is_prime = false   
        end
        test = test + 1
    end
    if is_prime then
        sum = sum + cur
    end
    cur = cur + 1
end
print(sum)