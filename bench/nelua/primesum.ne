local sum = 0
for cur=2, 20000-1 do
    local is_prime = true
    for test=2, cur-1 do
        if cur % test == 0 then
            is_prime = false
        end
    end
    if is_prime then
        sum = sum + cur
    end
end
print(sum)