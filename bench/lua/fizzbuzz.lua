local function one_fizzbuzz(n)
    local res = ""
    if n % 3 == 0 then
        res = res .. "Fizz"
    end
    if n % 5 == 0 then
        res = res .. "Buzz"
    end
    if n % 7 == 0 then
        res = res .. "Woof"
    end
    if res == "" then
        return tostring(n)
    else
        return res
    end
end

local function fizzbuzz_count(c)
    local count = 0
    for i=0, c-1 do
        count = count + #one_fizzbuzz(i)
    end
    return count
end

print(fizzbuzz_count(10000000))