local function getrandfive()
    return math.random(5)
end

local function getrandseven()
    local chances = {
        {
            1,2,3,4,5
        },
        {
            6,7,1,2,3
        },
        {
            4,5,6,7,1
        },
        {
            2,3,4,5,6
        },
        {
            7
        }
    }
    local got = chances[getrandfive()][getrandfive()]
    while got == nil do
        got = chances[getrandfive()][getrandfive()]
    end
    return got
end

local n = 10000

local tab5 = {
    0,0,0,0,0
}

for i=0, 5*n do
    local got = getrandfive()
    tab5[got] = tab5[got] + 1
end

local tab7 = {
    0,0,0,0,0,0,0
}

for i=0, 7*n do
    local got = getrandseven()
    tab7[got] = tab7[got] + 1
end

print(table.unpack(tab5))
print(table.unpack(tab7))