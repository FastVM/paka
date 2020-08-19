local function fib(x)
    if x < 2 then
        return x
    else
        return fib(x - 2) + fib(x - 1)
    end
end
print(fib(35))