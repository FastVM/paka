local function fib(x)
    if x < 2 then
        return x
    end
    return fib(x-2) + fib(x-1);
end

print(fib(30))