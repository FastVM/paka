
local function fib(n)
    if n < 2 then
        return n
    else
        return fib(n-2) + fib(n-1)
    end
end

if #arg == 0 then
    print("error: need an integer argument")
else
    print(fib(tonumber(arg[1])))
end