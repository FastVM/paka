local function hash(n)
    local x = {}
    x[0] = 0

    for it=1, n do
        x[it * it] = x[(it - 1) * (it - 1)] + 1
    end

    return x[n * n]
end

local total = 0
for i=1, 100 do
    total = total + hash(100000)
end
print(total)