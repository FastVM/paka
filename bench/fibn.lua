local function fib(n)
    local i = 0
    local a, b = 0.0, 1
    while i < n do
        local tmp = b
        b = a + b
        a = tmp
        i = i + 1
    end
    return a
end

print(fib(200))