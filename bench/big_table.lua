local function big(n)
    local t = {}
    for i=1, n do
        t[i] = i
    end
    return t
end

print(#big(1000000))