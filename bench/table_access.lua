local things = {}
for i=0, 15 do
    things[i] = i
end
local sum = 0
local x = 0
while x < 10000000 do
    sum = sum + things[x % 16]
    x = x + 1
end
print(sum)