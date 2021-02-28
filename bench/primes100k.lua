local ret = 0
for at=2, 100000 do
    local is_prime = true
    for test=2, at-1 do
        if at % test < 1 then
            is_prime = false
        end
    end
    if is_prime then
        ret = ret + 1
    end
end
print(ret)